import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../intelligence_exception.dart';
import '../../models/ai_input.dart';
import '../../models/ai_request.dart';
import '../../models/ai_response.dart';
import '../../models/model_capabilities.dart';
import '../../models/task_registry.dart';
import '../../request_validation.dart';
import '../../inference_provider.dart';
import 'remote_http.dart';

/// Adapter for Google Gemini through its Generative Language API.
class GoogleGeminiProvider implements InferenceProvider, MediaCapableProvider {
  static const providerAlias = 'google-gemini';
  static const _defaultBaseUrl = 'https://generativelanguage.googleapis.com';

  GoogleGeminiProvider({
    required this.config,
    required this.clientFactory,
    this.requestTimeout = const Duration(seconds: 60),
    this.imageRequestTimeout = const Duration(minutes: 3),
  });

  @override
  final ProviderConfig config;
  final http.Client Function() clientFactory;
  final Duration requestTimeout;
  final Duration imageRequestTimeout;

  @override
  String get alias => config.alias;

  final ValueNotifier<EngineLifecycle> _lifecycle = ValueNotifier(
    const EngineLifecycle.ready(),
  );
  bool _disposed = false;

  @override
  ValueListenable<EngineLifecycle> get lifecycle => _lifecycle;

  @override
  bool get isInitialized => _lifecycle.value.isReady;

  String _origin() => stripTrailingSlashes(config.baseUrl ?? _defaultBaseUrl);

  Uri _generateUri(String model, {bool stream = false, required String key}) {
    final origin = _origin();
    final baseUri = Uri.parse(origin);
    final basePath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    final hasVersion = basePath.endsWith('/v1beta') || basePath.endsWith('/v1');
    final suffix = stream
        ? '/models/$model:streamGenerateContent'
        : '/models/$model:generateContent';
    final path = hasVersion ? '$basePath$suffix' : '$basePath/v1beta$suffix';
    return baseUri.replace(
      path: path,
      queryParameters: {
        ...baseUri.queryParameters,
        'key': key,
        if (stream) 'alt': 'sse',
      },
    );
  }

  @override
  Future<void> initialize() async {
    _ensureNotDisposed();
    if (_lifecycle.value.isReady) return;
    final uri = Uri.tryParse(_origin());
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
    final key = config.apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw ProviderUnavailableException(
        'No API key configured for Google Gemini.',
        providerId: alias,
      );
    }
    final client = clientFactory();
    final stopwatch = Stopwatch()..start();
    try {
      final decoded = await postJson(
        client,
        _generateUri(model.externalModelId, key: key),
        headers: {'content-type': 'application/json'},
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
    final key = config.apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw ProviderUnavailableException(
        'No API key configured for Google Gemini.',
        providerId: alias,
      );
    }
    final client = clientFactory();
    final stopwatch = Stopwatch()..start();
    final buffer = StringBuffer();
    try {
      await for (final event in streamJson(
        client,
        _generateUri(model.externalModelId, stream: true, key: key),
        headers: {
          'content-type': 'application/json',
          'accept': 'text/event-stream',
        },
        body: _body(request, model),
      )) {
        final candidates = event['candidates'];
        if (candidates is! List || candidates.isEmpty) continue;
        final content = candidates.first['content'];
        if (content is! Map) continue;
        final parts = content['parts'];
        if (parts is! List || parts.isEmpty) continue;
        final chunk = _extractTextParts(parts);
        if (chunk.isEmpty) continue;
        buffer.write(chunk);
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
    final key = config.apiKey?.trim() ?? '';
    final discovered = <DiscoveredModel>[];
    String? pageToken;
    try {
      for (var page = 0; page < 10; page++) {
        final response = await client
            .get(
              _discoveryUri(key, pageToken: pageToken),
              headers: {'accept': 'application/json'},
            )
            .timeout(requestTimeout);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError(
            'Google Gemini model discovery returned HTTP ${response.statusCode}.',
          );
        }
        final decoded = jsonDecode(response.body);
        final rows = _listRows(decoded);
        for (final row in rows) {
          discovered.addAll(_normalize(row));
        }
        final next = decoded is Map ? _string(decoded['nextPageToken']) : null;
        if (next == null || next.isEmpty) break;
        pageToken = next;
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
      final key = config.apiKey?.trim() ?? '';
      try {
        final response = await client
            .get(_discoveryUri(key), headers: {'accept': 'application/json'})
            .timeout(requestTimeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return const ProviderTestResult(
            ok: true,
            message: 'Google Gemini endpoint is reachable.',
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
        message: 'The Google Gemini endpoint could not be reached.',
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.disposed);
  }

  Uri _discoveryUri(String key, {String? pageToken}) {
    final origin = _origin();
    final isGemini =
        Uri.tryParse(origin)?.host.contains('generativelanguage') == true;
    final query = <String, String>{
      'key': key,
      if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
    };
    if (isGemini) {
      return Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models',
        query,
      );
    }
    return remoteUri(origin, '/models', query: query);
  }

  List<Map> _listRows(Object? decoded) {
    if (decoded is Map) {
      final rows = decoded['models'] ?? decoded['data'];
      if (rows is List) return rows.whereType<Map>().toList();
    }
    if (decoded is List) return decoded.whereType<Map>().toList();
    return const [];
  }

  Iterable<DiscoveredModel> _normalize(Map row) {
    var id = _string(row['id']) ?? _string(row['name']);
    if (id == null || id.trim().isEmpty) return const [];
    // Gemini's native models API prefixes ids with `models/`; the OpenAI
    // compatible endpoint expects the bare id.
    if (id.startsWith('models/')) id = id.substring('models/'.length);
    final lower = id.toLowerCase();
    final capabilities = <InferenceCapability>{};
    final tasks = <TaskDeclaration>{};

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

    final methods = row['supportedGenerationMethods'];
    final methodSet = methods is List
        ? methods.whereType<String>().toSet()
        : const <String>{};

    if (methodSet.contains('generateContent')) {
      if (lower.contains('-tts')) {
        addTask('text-to-speech');
      } else {
        addTask('text-generation');
        final isMultimodalGemini =
            (lower.startsWith('gemini-') &&
                !lower.startsWith('gemini-pro') &&
                !lower.startsWith('gemini-1.0-pro') &&
                !lower.contains('embedding')) ||
            lower.startsWith('gemma-3');
        if (isMultimodalGemini) {
          addTask('image-text-to-text');
          if (lower.startsWith('gemini-')) {
            addTask('audio-classification');
            addTask('video-text-to-text');
          }
        } else if (lower.contains('vision')) {
          addTask('image-text-to-text');
        }
        if (lower.contains('image-generation') ||
            lower.contains('nano-banana') ||
            (lower.contains('-image') && !lower.contains('image-to'))) {
          addTask('text-to-image');
        }
      }
    }
    if (methodSet.contains('embedContent') ||
        methodSet.contains('embedText') ||
        lower.contains('embedding')) {
      addTask('feature-extraction');
    }
    if (methodSet.contains('predict') || lower.contains('imagen')) {
      addTask('text-to-image');
    }
    if (lower.contains('veo')) {
      addTask('text-to-video');
    }
    if (tasks.isEmpty && methodSet.isEmpty) {
      addTask('text-generation');
    }
    return [
      DiscoveredModel(
        externalModelId: id,
        displayName:
            _string(row['display_name']) ?? _string(row['displayName']) ?? id,
        capabilities: capabilities,
        tasks: List.unmodifiable(tasks),
        metadata: {'_discovery_catalogue': 'models'},
      ),
    ];
  }

  String? _string(Object? value) => value is String ? value : null;

  Map<String, dynamic> _body(AiRequest request, ProviderModel model) {
    final systemParts = [
      for (final message in request.messages)
        if (message.role == AiRole.system) message.text.trim(),
    ].where((text) => text.isNotEmpty);

    final nonSystem = [
      for (final message in request.messages)
        if (message.role != AiRole.system) message,
    ];
    final contents = <Map<String, dynamic>>[];
    for (var i = 0; i < nonSystem.length; i++) {
      final message = nonSystem[i];
      final parts = <Map<String, dynamic>>[
        {'text': message.text},
      ];
      if (i == nonSystem.length - 1 && request.inputs.isNotEmpty) {
        for (final input in request.inputs) {
          switch (input) {
            case AiImageInput(:final bytes, :final mimeType):
              parts.add({
                'inlineData': {
                  'mimeType': mimeType,
                  'data': base64Encode(bytes),
                },
              });
            case AiAudioInput(:final bytes, :final mimeType):
              parts.add({
                'inlineData': {
                  'mimeType': mimeType,
                  'data': base64Encode(bytes),
                },
              });
            case AiVideoInput(:final bytes, :final mimeType)
                when bytes != null && mimeType != null:
              parts.add({
                'inlineData': {
                  'mimeType': mimeType,
                  'data': base64Encode(bytes),
                },
              });
            case AiFileInput(:final bytes, :final mimeType):
              parts.add({
                'inlineData': {
                  'mimeType': mimeType,
                  'data': base64Encode(bytes),
                },
              });
            default:
              break;
          }
        }
      }
      contents.add({
        'role': message.role == AiRole.assistant ? 'model' : 'user',
        'parts': parts,
      });
    }

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': request.options.temperature,
        'topP': request.options.topP,
        if (request.options.seed > 0) 'seed': request.options.seed,
        if (request.options.maxOutputTokens != null)
          'maxOutputTokens': request.options.maxOutputTokens,
      },
    };
    if (systemParts.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemParts.join('\n\n')},
        ],
      };
    }
    return body;
  }

  String _extractTextParts(List parts) {
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is! Map) continue;
      if (part['thought'] == true) continue;
      final text = part['text'];
      if (text is String && text.isNotEmpty) buffer.write(text);
    }
    return buffer.toString();
  }

  String _textFromCompletion(Map<String, dynamic> completion) {
    final candidates = completion['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw InferenceFailedException(
        'The provider returned no completion candidates.',
        providerId: alias,
      );
    }
    final content = candidates.first['content'];
    if (content is! Map) return '';
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return '';
    return _extractTextParts(parts);
  }

  @override
  Future<GeneratedImage> generateImage(
    String prompt,
    ProviderModel model,
  ) async {
    _ensureNotDisposed();
    await initialize();
    final key = _requireApiKey();
    final client = clientFactory();
    try {
      final isImagen = model.externalModelId.toLowerCase().contains('imagen');
      if (isImagen) {
        final decoded = await postJson(
          client,
          _actionUri(model.externalModelId, 'predict', key: key),
          headers: {'content-type': 'application/json'},
          body: {
            'instances': [
              {'prompt': prompt},
            ],
            'parameters': {'sampleCount': 1},
          },
          timeout: imageRequestTimeout,
        );
        final predictions = decoded['predictions'];
        if (predictions is List && predictions.isNotEmpty) {
          final first = predictions.first;
          if (first is Map) {
            final b64 = first['bytesBase64Encoded'];
            final mime = _string(first['mimeType']) ?? 'image/png';
            if (b64 is String && b64.isNotEmpty) {
              return GeneratedImage(bytes: base64Decode(b64), mimeType: mime);
            }
          }
        }
      } else {
        final decoded = await postJson(
          client,
          _generateUri(model.externalModelId, key: key),
          headers: {'content-type': 'application/json'},
          body: {
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {
              'responseModalities': ['TEXT', 'IMAGE'],
            },
          },
          timeout: imageRequestTimeout,
        );
        final inline = _firstInlineData(decoded);
        if (inline != null) {
          return GeneratedImage(
            bytes: base64Decode(inline.$1),
            mimeType: inline.$2,
          );
        }
      }
      throw InferenceFailedException(
        'The provider did not return an image.',
        providerId: alias,
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
    final key = _requireApiKey();
    final client = clientFactory();
    try {
      final decoded = await postJson(
        client,
        _generateUri(model.externalModelId, key: key),
        headers: {'content-type': 'application/json'},
        body: {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text': 'Transcribe the spoken audio verbatim. Return only the transcription text.',
                },
                {
                  'inlineData': {
                    'mimeType': mimeType,
                    'data': base64Encode(bytes),
                  },
                },
              ],
            },
          ],
        },
      );
      return _textFromCompletion(decoded).trim();
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
    final key = _requireApiKey();
    final client = clientFactory();
    try {
      final decoded = await postJson(
        client,
        _generateUri(model.externalModelId, key: key),
        headers: {'content-type': 'application/json'},
        body: {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': text},
              ],
            },
          ],
          'generationConfig': {
            'responseModalities': ['AUDIO'],
            'speechConfig': {
              'voiceConfig': {
                'prebuiltVoiceConfig': {'voiceName': 'Kore'},
              },
            },
          },
        },
      );
      final inline = _firstInlineData(decoded);
      if (inline == null) {
        throw InferenceFailedException(
          'The provider did not return synthesized audio.',
          providerId: alias,
        );
      }
      final rawBytes = base64Decode(inline.$1);
      final mime = inline.$2.toLowerCase();
      if (mime.contains('l16') || mime.contains('pcm')) {
        return SynthesizedSpeech(
          bytes: _wrapPcmAsWav(rawBytes, sampleRate: 24000),
          mimeType: 'audio/wav',
        );
      }
      return SynthesizedSpeech(bytes: rawBytes, mimeType: inline.$2);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapError(error), stackTrace);
    } finally {
      client.close();
    }
  }

  String _requireApiKey() {
    final key = config.apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw ProviderUnavailableException(
        'No API key configured for Google Gemini.',
        providerId: alias,
      );
    }
    return key;
  }

  Uri _actionUri(String model, String action, {required String key}) {
    final baseUri = Uri.parse(_origin());
    final basePath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    final hasVersion = basePath.endsWith('/v1beta') || basePath.endsWith('/v1');
    final suffix = '/models/$model:$action';
    final path = hasVersion ? '$basePath$suffix' : '$basePath/v1beta$suffix';
    return baseUri.replace(
      path: path,
      queryParameters: {...baseUri.queryParameters, 'key': key},
    );
  }

  (String, String)? _firstInlineData(Map<String, dynamic> decoded) {
    final candidates = decoded['candidates'];
    if (candidates is! List) return null;
    for (final candidate in candidates) {
      if (candidate is! Map) continue;
      final content = candidate['content'];
      if (content is! Map) continue;
      final parts = content['parts'];
      if (parts is! List) continue;
      for (final part in parts) {
        if (part is! Map || part['thought'] == true) continue;
        final inline = part['inlineData'] ?? part['inline_data'];
        if (inline is! Map) continue;
        final data = inline['data'];
        final mime =
            _string(inline['mimeType'] ?? inline['mime_type']) ??
            'application/octet-stream';
        if (data is String && data.isNotEmpty) return (data, mime);
      }
    }
    return null;
  }

  Uint8List _wrapPcmAsWav(Uint8List pcm, {required int sampleRate}) {
    final dataLength = pcm.length;
    final byteRate = sampleRate * 2;
    final header = ByteData(44)
      ..setUint8(0, 0x52) // R
      ..setUint8(1, 0x49) // I
      ..setUint8(2, 0x46) // F
      ..setUint8(3, 0x46) // F
      ..setUint32(4, 36 + dataLength, Endian.little)
      ..setUint8(8, 0x57) // W
      ..setUint8(9, 0x41) // A
      ..setUint8(10, 0x56) // V
      ..setUint8(11, 0x45) // E
      ..setUint8(12, 0x66) // f
      ..setUint8(13, 0x6D) // m
      ..setUint8(14, 0x74) // t
      ..setUint8(15, 0x20) // ' '
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, byteRate, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint8(36, 0x64) // d
      ..setUint8(37, 0x61) // a
      ..setUint8(38, 0x74) // t
      ..setUint8(39, 0x61) // a
      ..setUint32(40, dataLength, Endian.little);
    final result = Uint8List(44 + dataLength)
      ..setRange(0, 44, header.buffer.asUint8List())
      ..setRange(44, 44 + dataLength, pcm);
    return result;
  }

  Map<String, String> _usageMetadata(Map<String, dynamic> completion) {
    final usage = completion['usageMetadata'];
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
