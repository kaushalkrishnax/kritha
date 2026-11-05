import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../intelligence_exception.dart';
import '../../models/ai_request.dart';
import '../../models/ai_response.dart';
import '../../models/model_capabilities.dart';
import '../../models/task_registry.dart';
import '../../request_validation.dart';
import '../../inference_provider.dart';
import 'remote_http.dart';

/// Adapter for xAI through its OpenAI-compatible API.
class XaiProvider implements InferenceProvider {
  static const providerAlias = 'xai';

  XaiProvider({
    required this.config,
    required this.clientFactory,
    this.requestTimeout = const Duration(seconds: 60),
  });

  @override
  final ProviderConfig config;
  final http.Client Function() clientFactory;
  final Duration requestTimeout;

  @override
  String get alias => config.alias;

  

  final ValueNotifier<EngineLifecycle> _lifecycle =
      ValueNotifier(const EngineLifecycle.ready());
  bool _disposed = false;

  @override
  ValueListenable<EngineLifecycle> get lifecycle => _lifecycle;

  @override
  bool get isInitialized => _lifecycle.value.isReady;

  Uri _chatUri() => remoteUri(config.baseUrl ?? '', '/chat/completions');

  @override
  Future<void> initialize() async {
    _ensureNotDisposed();
    if (_lifecycle.value.isReady) return;
    final uri = Uri.tryParse(config.baseUrl ?? '');
    if (uri == null || uri.host.isEmpty) {
      _publishFailure('The provider endpoint is not a valid HTTP URL.');
      throw ProviderUnavailableException(
        'The provider endpoint is not a valid HTTP URL.',
        providerId: alias,
      );
    }
    _lifecycle.value = const EngineLifecycle.ready();
  }

  @override
  Future<AiResponse> generate(AiRequest request, ProviderModel model) async {
    _ensureSupported(request, model);
    _ensureNotDisposed();
    await initialize();
    final credential = config.apiKey?.trim();
    final client = clientFactory();
    final stopwatch = Stopwatch()..start();
    try {
      final decoded = await postJson(
        client,
        _chatUri(),
        headers: remoteAuthHeaders(credential),
        body: _body(request, model),
      );
      stopwatch.stop();
      return AiResponse(
        text: _textFromCompletion(decoded),
        modelId: model.id,
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
  Stream<AiResponse> stream(AiRequest request, ProviderModel model) async* {
    _ensureSupported(request, model);
    _ensureNotDisposed();
    await initialize();
    final credential = config.apiKey?.trim();
    final client = clientFactory();
    final stopwatch = Stopwatch()..start();
    final buffer = StringBuffer();
    try {
      await for (final event in streamJson(
        client,
        _chatUri(),
        headers: remoteAuthHeaders(credential, stream: true),
        body: _body(request, model, stream: true),
      )) {
        final choices = event['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final delta = choices.first['delta'];
        if (delta is! Map) continue;
        final text = delta['content'];
        if (text is! String || text.isEmpty) continue;
        buffer.write(text);
        yield AiResponse(
          text: buffer.toString(),
          modelId: model.id,
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

  static const _discoveryEndpoints = <DiscoveryEndpoint>[
    DiscoveryEndpoint('https://api.x.ai/v1/language-models', catalogue: 'language'),
    DiscoveryEndpoint('https://api.x.ai/v1/image-generation-models', catalogue: 'image'),
    DiscoveryEndpoint('https://api.x.ai/v1/video-generation-models', catalogue: 'video'),
  ];

  @override
  Future<List<DiscoveredModel>> discoverModels() async {
    await initialize();
    final client = clientFactory();
    final credential = config.apiKey?.trim();
    final headers = remoteAuthHeaders(credential);
    final discovered = <DiscoveredModel>[];
    try {
      for (final endpoint in _discoveryEndpoints) {
        final response = await client
            .get(Uri.parse(endpoint.url), headers: headers)
            .timeout(requestTimeout);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError(
            'xAI model discovery returned HTTP ${response.statusCode}.',
          );
        }
        final decoded = jsonDecode(response.body);
        final rows = _listRows(decoded);
        final task = switch (endpoint.catalogue) {
          'image' => 'text-to-image',
          'video' => 'text-to-video',
          _ => 'text-generation',
        };
        for (final row in rows) {
          final id = _string(row['id']) ?? _string(row['name']);
          if (id == null || id.trim().isEmpty) continue;
          final declaration = declarationFromPipelineTag(task,
              source: TaskMetadataSource.provider);
          discovered.add(DiscoveredModel(
            externalModelId: id,
            displayName: _string(row['display_name']) ??
                _string(row['displayName']) ??
                id,
            capabilities: declaration == null
                ? const {}
                : capabilitiesForTask(declaration.task),
            tasks: declaration == null ? const [] : [declaration],
            metadata: {'_discovery_catalogue': endpoint.catalogue},
          ));
        }
      }
      return discovered;
    } finally {
      client.close();
    }
  }

  @override
  Future<ProviderTestResult> test() async {
    try {
      await initialize();
      final client = clientFactory();
      final credential = config.apiKey?.trim();
      try {
        final base = stripTrailingSlashes(config.baseUrl ?? '');
        final response = await client
            .get(remoteUri(base, '/models'), headers: remoteAuthHeaders(credential))
            .timeout(requestTimeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return const ProviderTestResult(
            ok: true,
            message: 'xAI endpoint is reachable.',
          );
        }
        return ProviderTestResult(
          ok: false,
          message: 'The endpoint returned HTTP ${response.statusCode}.',
        );
      } finally {
        client.close();
      }
    } on Object {
      return const ProviderTestResult(
        ok: false,
        message: 'The xAI endpoint could not be reached.',
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.disposed);
  }

  List<Map> _listRows(Object? decoded) {
    if (decoded is! Map) return const [];
    final data = decoded['data'];
    if (data is List) return data.whereType<Map>().toList();
    return const [];
  }

  String? _string(Object? value) => value is String ? value : null;

  Map<String, dynamic> _body(AiRequest request, ProviderModel model,
      {bool stream = false}) {
    final system = [
      for (final message in request.messages)
        if (message.role == AiRole.system) message.text.trim(),
    ].where((text) => text.isNotEmpty).join('\n\n');
    final messages = [
      for (final message in request.messages)
        if (message.role != AiRole.system)
          {
            'role': message.role == AiRole.assistant ? 'assistant' : 'user',
            'content': message.text,
          },
    ];
    return {
      'model': model.externalModelId,
      'messages': messages,
      'temperature': request.options.temperature,
      'top_p': request.options.topP,
      if (request.options.seed > 0) 'seed': request.options.seed,
      if (request.options.maxOutputTokens != null)
        'max_tokens': request.options.maxOutputTokens,
      if (system.isNotEmpty) 'system': system,
      if (stream) 'stream': true,
    };
  }

  String _textFromCompletion(Map<String, dynamic> completion) {
    final choices = completion['choices'];
    if (choices is! List || choices.isEmpty) {
      throw InferenceFailedException(
        'The provider returned no completion choices.',
        providerId: alias,
      );
    }
    final message = choices.first['message'];
    final content = message is Map ? message['content'] : null;
    return content is String ? content : '';
  }

  Map<String, String> _usageMetadata(Map<String, dynamic> completion) {
    final usage = completion['usage'];
    if (usage is! Map) return const {};
    return {
      if (usage['prompt_tokens'] != null)
        'promptTokens': '${usage['prompt_tokens']}',
      if (usage['completion_tokens'] != null)
        'completionTokens': '${usage['completion_tokens']}',
      if (usage['total_tokens'] != null) 'totalTokens': '${usage['total_tokens']}',
    };
  }

  void _ensureSupported(AiRequest request, ProviderModel model) {
    const AiRequestValidator().validate(request);
    final requestedModel = request.modelId;
    if (requestedModel != null && requestedModel != model.id) {
      throw ProviderUnavailableException(
        'This provider serves ${model.id}, not "$requestedModel".',
        providerId: alias,
      );
    }
    if (request.responseSchema != null) {
      throw UnsupportedCapabilityException(
        providerId: alias,
        missing: const {InferenceCapability.structuredOutput},
      );
    }
    final missing = request.requiredCapabilities
        .where((capability) => !model.capabilities.contains(capability))
        .toSet();
    if (missing.isNotEmpty) {
      throw UnsupportedCapabilityException(providerId: alias, missing: missing);
    }
  }

  IntelligenceException _mapError(Object error) {
    if (error is IntelligenceException) return error;
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return remoteTransportFailure(alias, error);
    }
    return InferenceFailedException(
      'The provider failed to complete the request.',
      providerId: alias,
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
        providerId: alias,
      );
    }
  }
}
