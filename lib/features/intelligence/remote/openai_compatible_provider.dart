import 'dart:async';
import 'dart:io';

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../inference_provider.dart';
import '../intelligence_exception.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';
import '../models/model_capabilities.dart';
import '../models/model_descriptor.dart';
import '../request_validation.dart';
import 'remote_http.dart';

/// Adapter for OpenAI and endpoints implementing its chat-completions shape.
///
/// A new [OpenAIClient] is built for every request from the selected provider
/// configuration. No process-global OpenAI state is read or written.
class OpenAiCompatibleProvider implements InferenceProvider {
  OpenAiCompatibleProvider({
    required this.sourceId,
    required this.descriptor,
    required this.baseUrl,
    required this.readCredential,
    required this.requiresCredential,
    required this.clientFactory,
    this.requestTimeout = const Duration(seconds: 60),
  }) : _lifecycle = ValueNotifier(const EngineLifecycle.ready());

  final String sourceId;
  final String baseUrl;
  final Future<String?> Function() readCredential;
  final bool requiresCredential;
  final http.Client Function() clientFactory;
  final Duration requestTimeout;

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
    if (requiresCredential && credential == null) {
      throw ProviderUnavailableException(
        'No API key is saved for $sourceId.',
        providerId: id,
      );
    }

    final client = clientFactory();
    final stopwatch = Stopwatch()..start();
    try {
      final completion = await _openAi(credential).chat.create(
        model: _requestModel,
        messages: _messagesFor(request),
        temperature: request.options.temperature,
        topP: request.options.topP,
        seed: request.options.seed > 0 ? request.options.seed : null,
        maxTokens: sourceId == 'openai'
            ? request.options.maxOutputTokens
            : null,
        extraParams: {
          if (sourceId != 'openai' && request.options.maxOutputTokens != null)
            'max_tokens': request.options.maxOutputTokens,
        },
        client: client,
      );
      stopwatch.stop();
      return AiResponse(
        text: _textFromCompletion(completion),
        modelId: descriptor.id,
        latency: stopwatch.elapsed,
        metadata: _usageMetadata(completion.usage),
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
    if (requiresCredential && credential == null) {
      throw ProviderUnavailableException(
        'No API key is saved for $sourceId.',
        providerId: id,
      );
    }

    final client = clientFactory();
    final stopwatch = Stopwatch()..start();
    final buffer = StringBuffer();
    try {
      final chunks = _openAi(credential).chat.createStream(
        model: _requestModel,
        messages: _messagesFor(request),
        temperature: request.options.temperature,
        topP: request.options.topP,
        seed: request.options.seed > 0 ? request.options.seed : null,
        maxTokens: sourceId == 'openai'
            ? request.options.maxOutputTokens
            : null,
        extraParams: {
          if (sourceId != 'openai' && request.options.maxOutputTokens != null)
            'max_tokens': request.options.maxOutputTokens,
        },
        client: client,
      );
      await for (final chunk in chunks) {
        if (chunk.choices.isEmpty) continue;
        final text = _textFromDelta(chunk.choices.first.delta);
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

  OpenAIClient _openAi(String? credential) {
    final normalized = _normalizeOpenAiBase(baseUrl);
    return OpenAIClient(
      apiKey: credential,
      baseUrl: normalized.baseUrl,
      version: normalized.version,
      requestsTimeOut: requestTimeout,
    );
  }

  /// Some OpenAI-compatible catalogues prefix IDs with `models/`; the chat
  /// endpoint accepts the bare identifier.
  String get _requestModel => descriptor.id.startsWith('models/')
      ? descriptor.id.substring('models/'.length)
      : descriptor.id;

  Future<String?> _credential() async {
    final value = (await readCredential())?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  List<OpenAIChatCompletionChoiceMessageModel> _messagesFor(AiRequest request) {
    return [
      for (final message in request.messages)
        OpenAIChatCompletionChoiceMessageModel.textContent(
          role: switch (message.role) {
            AiRole.system => OpenAIChatMessageRole.system,
            AiRole.user => OpenAIChatMessageRole.user,
            AiRole.assistant => OpenAIChatMessageRole.assistant,
          },
          text: message.text,
        ),
    ];
  }

  String _textFromCompletion(OpenAIChatCompletionModel completion) {
    if (completion.choices.isEmpty) {
      throw InferenceFailedException(
        'The provider returned no completion choices.',
        providerId: id,
      );
    }
    return _contentText(completion.choices.first.message.content);
  }

  String _textFromDelta(OpenAIStreamChatCompletionChoiceDeltaModel delta) =>
      _contentText(delta.content);

  String _contentText(
    List<OpenAIChatCompletionChoiceMessageContentItemModel?>? content,
  ) {
    if (content == null) return '';
    return [
      for (final item in content)
        if (item?.text != null) item!.text!,
    ].join();
  }

  Map<String, String> _usageMetadata(OpenAIChatCompletionUsageModel usage) => {
    'promptTokens': '${usage.promptTokens}',
    'completionTokens': '${usage.completionTokens}',
    'totalTokens': '${usage.totalTokens}',
  };

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
    if (error is MissingApiKeyException) {
      return ProviderUnavailableException(
        'No API key is saved for $sourceId.',
        providerId: id,
        cause: error,
      );
    }
    if (error is RequestFailedException) {
      return switch (error.statusCode) {
        401 || 403 => ProviderUnavailableException(
          'The provider rejected the credential.',
          providerId: id,
          cause: error,
        ),
        404 => ProviderUnavailableException(
          'The provider does not expose that model or endpoint.',
          providerId: id,
          cause: error,
        ),
        408 || 429 => InferenceFailedException(
          'The provider is busy or rate-limiting this request.',
          providerId: id,
          cause: error,
        ),
        >= 500 => InferenceFailedException(
          'The provider returned a server error.',
          providerId: id,
          cause: error,
        ),
        _ => InferenceFailedException(
          'The provider rejected the request (HTTP ${error.statusCode}).',
          providerId: id,
          cause: error,
        ),
      };
    }
    if (error is OpenAIUnexpectedException) {
      return InferenceFailedException(
        'The provider returned an unexpected response.',
        providerId: id,
        cause: error,
      );
    }
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

({String baseUrl, String version}) _normalizeOpenAiBase(String raw) {
  var value = stripTrailingSlashes(raw);
  if (value.endsWith('/chat/completions')) {
    value = stripTrailingSlashes(
      value.substring(0, value.length - '/chat/completions'.length),
    );
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) {
    return (baseUrl: value, version: 'v1');
  }
  final segments = [...uri.pathSegments.where((part) => part.isNotEmpty)];
  var version = 'v1';
  var versionIndex = -1;
  for (var index = 0; index < segments.length; index++) {
    if (RegExp(r'^v\d').hasMatch(segments[index])) versionIndex = index;
  }
  if (versionIndex >= 0) {
    version = segments.sublist(versionIndex).join('/');
    segments.removeRange(versionIndex, segments.length);
  }
  final path = segments.isEmpty ? '' : '/${segments.join('/')}';
  return (
    baseUrl: Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: path,
    ).toString(),
    version: version,
  );
}

bool _validBaseUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}
