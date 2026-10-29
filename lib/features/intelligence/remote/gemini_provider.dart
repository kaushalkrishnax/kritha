import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../providers/provider_definition.dart';
import '../../providers/provider_http_auth.dart';
import '../inference_provider.dart';
import '../intelligence_exception.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';
import '../models/model_capabilities.dart';
import '../models/model_descriptor.dart';
import '../request_validation.dart';
import 'remote_http.dart';

/// Adapter for the Google Gemini Generative Language API.
class GeminiProvider implements InferenceProvider {
  GeminiProvider({
    required this.sourceId,
    required this.descriptor,
    required this.baseUrl,
    required this.readCredential,
    required this.requiresCredential,
    required this.clientFactory,
    this.requestTimeout = const Duration(seconds: 60),
    this.defaultMaxTokens = 4096,
  }) : _lifecycle = ValueNotifier(const EngineLifecycle.ready());

  final String sourceId;
  final String baseUrl;
  final Future<String?> Function() readCredential;
  final bool requiresCredential;
  final http.Client Function() clientFactory;
  final Duration requestTimeout;
  final int defaultMaxTokens;

  @override
  final ModelDescriptor descriptor;

  final ValueNotifier<EngineLifecycle> _lifecycle;
  bool _disposed = false;

  @override
  String get id => sourceId;

  @override
  ValueListenable<EngineLifecycle> get lifecycle => _lifecycle;

  @override
  bool get isInitialized => false;

  @override
  Future<void> initialize() async {
    _ensureNotDisposed();
    if (_lifecycle.value.isReady) return;
    final credential = await _credential();
    if (requiresCredential && credential == null) {
      _publishFailure('No API key is saved for $sourceId.');
      throw ProviderUnavailableException(
        'No API key is saved for $sourceId.',
        providerId: id,
      );
    }
    if (!_validBaseUrl(baseUrl)) {
      _publishFailure('The provider endpoint is not a valid HTTP URL.');
      throw ProviderUnavailableException(
        'The provider endpoint is not a valid HTTP URL.',
        providerId: id,
      );
    }
    _lifecycle.value = const EngineLifecycle.ready();
  }

  @override
  Future<AiResponse> generate(AiRequest request) async {
    _ensureSupported(request);
    _ensureNotDisposed();
    await initialize();
    final credential = await _credential();
    _ensureCredential(credential);
    final client = clientFactory();
    final stopwatch = Stopwatch()..start();
    try {
      final response = await client
          .post(
            _uri(':generateContent', credential),
            headers: _headers(),
            body: jsonEncode(_body(request)),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw remoteStatusFailure(id, response.statusCode);
      }
      final decoded = _decodeObject(response.body);
      stopwatch.stop();
      return AiResponse(
        text: _textFromResponse(decoded),
        modelId: descriptor.id,
        latency: stopwatch.elapsed,
        metadata: _usageMetadata(decoded),
      );
    } on Object catch (error, stackTrace) {
      stopwatch.stop();
      Error.throwWithStackTrace(_mapError(error), stackTrace);
    } finally {
      client.close();
    }
  }

  @override
  Stream<AiResponse> stream(AiRequest request) async* {
    _ensureSupported(request);
    _ensureNotDisposed();
    await initialize();
    final credential = await _credential();
    _ensureCredential(credential);
    final client = clientFactory();
    final stopwatch = Stopwatch()..start();
    final buffer = StringBuffer();
    try {
      final httpRequest =
          http.Request(
              'POST',
              _uri(':streamGenerateContent', credential, query: {'alt': 'sse'}),
            )
            ..headers.addAll(_headers(stream: true))
            ..body = jsonEncode(_body(request));
      final response = await client.send(httpRequest).timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw remoteStatusFailure(id, response.statusCode);
      }
      await for (final event in decodeSseJson(response.stream)) {
        final error = event['error'];
        if (error is Map && error['message'] is String) {
          throw InferenceFailedException(
            error['message'] as String,
            providerId: id,
          );
        }
        final text = _textFromResponse(event);
        if (text.isEmpty) continue;
        buffer.write(text);
        yield AiResponse(
          text: buffer.toString(),
          modelId: descriptor.id,
          latency: stopwatch.elapsed,
        );
      }
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapError(error), stackTrace);
    } finally {
      stopwatch.stop();
      client.close();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.disposed);
  }

  Uri _uri(String method, String? credential, {Map<String, String>? query}) {
    final base = stripTrailingSlashes(baseUrl);
    final model = descriptor.id.startsWith('models/')
        ? descriptor.id
        : 'models/${descriptor.id}';
    final definition = providerDefinitionFor(sourceId);
    final authQuery = definition == null
        ? (credential == null ? null : {'key': credential})
        : providerAuthQuery(definition, credential);
    return remoteUri(base, '/$model$method', query: {...?authQuery, ...?query});
  }

  Map<String, String> _headers({bool stream = false}) => {
    'accept': stream ? 'text/event-stream' : 'application/json',
    'content-type': 'application/json',
  };

  Map<String, dynamic> _body(AiRequest request) {
    final system = [
      for (final message in request.messages)
        if (message.role == AiRole.system) message.text.trim(),
    ].where((text) => text.isNotEmpty).join('\n\n');
    final contents = [
      for (final message in request.messages)
        if (message.role != AiRole.system)
          {
            'role': message.role == AiRole.assistant ? 'model' : 'user',
            'parts': [
              {'text': message.text},
            ],
          },
    ];
    return {
      'contents': contents,
      if (system.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
      'generationConfig': {
        'temperature': request.options.temperature,
        'topP': request.options.topP,
        'topK': request.options.topK,
        'maxOutputTokens': request.options.maxOutputTokens ?? defaultMaxTokens,
        if (request.options.seed > 0) 'seed': request.options.seed,
      },
    };
  }

  String _textFromResponse(Map<String, dynamic> response) {
    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';
    final content = (candidates.first as Map?)?['content'];
    if (content is! Map) return '';
    final parts = content['parts'];
    if (parts is! List) return '';
    return [
      for (final part in parts)
        if (part is Map && part['text'] is String) part['text'] as String,
    ].join();
  }

  Map<String, String> _usageMetadata(Map<String, dynamic> response) {
    final usage = response['usageMetadata'];
    if (usage is! Map) return const {};
    return {
      if (usage['promptTokenCount'] != null)
        'promptTokens': '${usage['promptTokenCount']}',
      if (usage['candidatesTokenCount'] != null)
        'completionTokens': '${usage['candidatesTokenCount']}',
      if (usage['totalTokenCount'] != null)
        'totalTokens': '${usage['totalTokenCount']}',
    };
  }

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw InferenceFailedException(
        'The provider returned an unexpected response.',
        providerId: id,
      );
    }
    return {for (final entry in decoded.entries) '${entry.key}': entry.value};
  }

  void _ensureSupported(AiRequest request) {
    const AiRequestValidator().validate(request);
    final requestedModel = request.modelId;
    if (requestedModel != null && requestedModel != descriptor.id) {
      throw ProviderUnavailableException(
        'This provider serves ${descriptor.id}, not "$requestedModel".',
        providerId: id,
      );
    }
    if (request.responseSchema != null) {
      throw UnsupportedCapabilityException(
        providerId: id,
        missing: const {InferenceCapability.structuredOutput},
      );
    }
    final missing = request.requiredCapabilities
        .where((capability) => !descriptor.capabilities.supports(capability))
        .toSet();
    if (missing.isNotEmpty) {
      throw UnsupportedCapabilityException(providerId: id, missing: missing);
    }
  }

  IntelligenceException _mapError(Object error) {
    if (error is IntelligenceException) return error;
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return remoteTransportFailure(id, error);
    }
    return InferenceFailedException(
      'The provider failed to complete the request.',
      providerId: id,
      cause: error,
    );
  }

  Future<String?> _credential() async {
    final value = (await readCredential())?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  void _ensureCredential(String? credential) {
    if (!requiresCredential || credential != null) return;
    throw ProviderUnavailableException(
      'No API key is saved for $sourceId.',
      providerId: id,
    );
  }

  void _publishFailure(String message) {
    if (_disposed) return;
    _lifecycle.value = EngineLifecycle(
      EngineLifecycleStage.initializationFailed,
      message: message,
    );
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw ProviderUnavailableException(
        'The provider has been disposed.',
        providerId: id,
      );
    }
  }
}

bool _validBaseUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}
