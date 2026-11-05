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

/// Adapter for Mistral hosted models through an OpenAI-compatible API.
class MistralProvider implements InferenceProvider {
  static const providerAlias = 'mistral';

  MistralProvider({
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

  @override
  Future<List<DiscoveredModel>> discoverModels() async {
    await initialize();
    final client = clientFactory();
    final credential = config.apiKey?.trim();
    try {
      final base = stripTrailingSlashes(config.baseUrl ?? '');
      final response = await client
          .get(remoteUri(base, '/models'), headers: remoteAuthHeaders(credential))
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Mistral model discovery returned HTTP ${response.statusCode}.',
        );
      }
      final decoded = jsonDecode(response.body);
      final rows = _listRows(decoded);
      return [
        for (final row in rows) ..._normalize(row),
      ];
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
            message: 'Mistral endpoint is reachable.',
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
        message: 'The Mistral endpoint could not be reached.',
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

  Iterable<DiscoveredModel> _normalize(Map row) {
    final id = _string(row['id']) ?? _string(row['name']);
    if (id == null || id.trim().isEmpty) return const [];
    final capabilities = <InferenceCapability>{};
    final tasks = <TaskDeclaration>{};
    final caps = row['capabilities'];
    if (caps is Map) {
      if (caps['completion_chat'] == true) {
        tasks.add(declarationFromPipelineTag('text-generation',
                source: TaskMetadataSource.provider)!);
        capabilities.add(InferenceCapability.textGeneration);
      }
      if (caps['vision'] == true) {
        tasks.add(declarationFromPipelineTag('image-text-to-text',
                source: TaskMetadataSource.provider)!);
        capabilities.add(InferenceCapability.imageInput);
        capabilities.add(InferenceCapability.textGeneration);
      }
    }
    if (tasks.isEmpty) {
      tasks.add(declarationFromPipelineTag('text-generation',
              source: TaskMetadataSource.provider)!);
      capabilities.add(InferenceCapability.textGeneration);
    }
    return [
      DiscoveredModel(
        externalModelId: id,
        displayName: _string(row['name']) ?? id,
        capabilities: capabilities,
        tasks: List.unmodifiable(tasks),
      ),
    ];
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
