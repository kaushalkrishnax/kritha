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

/// Shared implementation for OpenAI-compatible chat-completions endpoints.
///
/// Used by the dedicated OpenAI provider and by every custom user-added
/// OpenAI-compatible endpoint. No dedicated Dart class is created per custom
/// endpoint; they are distinguished only by their providers table record.
class OaiSpecProvider implements InferenceProvider, MediaCapableProvider {
  OaiSpecProvider({
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
          'OpenAI-compatible model discovery returned HTTP ${response.statusCode}.',
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
            message: 'OpenAI-compatible endpoint is reachable.',
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
        message: 'The OpenAI-compatible endpoint could not be reached.',
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
    final lower = id.toLowerCase();
    final tasks = <TaskDeclaration>{};
    final capabilities = <InferenceCapability>{};

    void addTask(String pipelineTag) {
      final declaration = declarationFromPipelineTag(
        pipelineTag,
        source: TaskMetadataSource.provider,
      );
      if (declaration == null) return;
      if (!tasks.any((t) => t.task == declaration.task)) {
        tasks.add(declaration);
      }
      capabilities.addAll(capabilitiesForTask(declaration.task));
    }

    if (lower.contains('embedding')) {
      addTask('feature-extraction');
    } else if (lower.startsWith('tts-') || lower.contains('-tts')) {
      addTask('text-to-speech');
    } else if (lower.startsWith('whisper-') || lower.contains('transcribe')) {
      addTask('automatic-speech-recognition');
    } else if (lower.startsWith('dall-e') || lower.contains('gpt-image')) {
      addTask('text-to-image');
    } else {
      addTask('text-generation');
      final arch = row['architecture'];
      final inputModalities = arch is Map && arch['input_modalities'] is List
          ? (arch['input_modalities'] as List).whereType<String>().toSet()
          : const <String>{};
      final caps = row['capabilities'];
      final hasVision = inputModalities.contains('image') ||
          (caps is Map &&
              (caps['vision'] == true || caps['image_input'] == true)) ||
          lower.contains('vision') ||
          lower.startsWith('gpt-4o') ||
          lower.startsWith('gpt-4-turbo') ||
          lower.startsWith('gpt-4.1') ||
          lower.startsWith('gpt-5') ||
          RegExp(r'^o[134](-|$)').hasMatch(lower);
      if (hasVision) {
        addTask('image-text-to-text');
      }
      if (inputModalities.contains('audio') || lower.contains('-audio')) {
        addTask('audio-classification');
      }
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
    return {
      'model': model.externalModelId,
      'messages': openAiChatMessages(request),
      'temperature': request.options.temperature,
      'top_p': request.options.topP,
      if (request.options.seed > 0) 'seed': request.options.seed,
      if (request.options.maxOutputTokens != null)
        'max_tokens': request.options.maxOutputTokens,
      if (stream) 'stream': true,
    };
  }

  @override
  Future<GeneratedImage> generateImage(String prompt, ProviderModel model) async {
    _ensureNotDisposed();
    await initialize();
    final client = clientFactory();
    try {
      return await openAiGenerateImage(
        client,
        baseUrl: config.baseUrl ?? '',
        apiKey: config.apiKey,
        modelId: model.externalModelId,
        prompt: prompt,
        providerAlias: alias,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapError(error), stackTrace);
    } finally {
      client.close();
    }
  }

  @override
  Future<String> transcribeAudio(
    Uint8List bytes,
    String mimeType,
    ProviderModel model,
  ) async {
    _ensureNotDisposed();
    await initialize();
    final client = clientFactory();
    try {
      final uri = remoteUri(
        stripTrailingSlashes(config.baseUrl ?? ''),
        '/audio/transcriptions',
      );
      final req = http.MultipartRequest('POST', uri);
      final key = config.apiKey?.trim();
      if (key != null && key.isNotEmpty) {
        req.headers['authorization'] = 'Bearer $key';
      }
      req.fields['model'] = model.externalModelId;
      final ext = mimeType.split('/').last.split(';').first;
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'audio.$ext',
        ),
      );
      final streamed = await client.send(req).timeout(requestTimeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw remoteStatusFailure(alias, response.statusCode);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['text'] is String) {
        return (decoded['text'] as String).trim();
      }
      throw InferenceFailedException(
        'The provider did not return a transcription.',
        providerId: alias,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapError(error), stackTrace);
    } finally {
      client.close();
    }
  }

  @override
  Future<SynthesizedSpeech> synthesizeSpeech(
    String text,
    ProviderModel model,
  ) async {
    _ensureNotDisposed();
    await initialize();
    final client = clientFactory();
    try {
      final response = await client
          .post(
            remoteUri(
              stripTrailingSlashes(config.baseUrl ?? ''),
              '/audio/speech',
            ),
            headers: remoteAuthHeaders(config.apiKey),
            body: jsonEncode({
              'model': model.externalModelId,
              'input': text,
              'voice': 'alloy',
              'response_format': 'mp3',
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw remoteStatusFailure(alias, response.statusCode);
      }
      return SynthesizedSpeech(
        bytes: Uint8List.fromList(response.bodyBytes),
        mimeType: response.headers['content-type'] ?? 'audio/mpeg',
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapError(error), stackTrace);
    } finally {
      client.close();
    }
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
