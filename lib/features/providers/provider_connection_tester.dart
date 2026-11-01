import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_error_utils.dart';
import '../models/catalogue/catalogue_model.dart';
import '../intelligence/models/task_registry.dart';
import 'provider_definition.dart';
import 'provider_http_auth.dart';

class ProviderConnectionResult {
  const ProviderConnectionResult({
    required this.ok,
    required this.message,
    this.statusCode,
    this.modelCount,
  });

  final bool ok;
  final String message;
  final int? statusCode;
  final int? modelCount;
}

class ProviderModelInfo {
  const ProviderModelInfo({
    required this.id,
    required this.name,
    this.parameterCount,
    this.capabilities,
    this.tasks = const [],
    this.metadataConfidence = TaskMetadataConfidence.unknown,
    this.metadataSource = TaskMetadataSource.provider,
    this.inputModalities = const {},
    this.outputModalities = const {},
    this.features = const {},
    this.providerModelId,
    this.rawMetadata = const {},
    this.contextWindow,
    this.maxOutputTokens,
    this.unsupportedTasks = const {},
  });

  final String id;
  final String name;
  final int? parameterCount;
  final List<ModelCapability>? capabilities;
  final List<TaskDeclaration> tasks;
  final TaskMetadataConfidence metadataConfidence;
  final TaskMetadataSource metadataSource;
  final Set<AiModality> inputModalities;
  final Set<AiModality> outputModalities;
  final Set<AiFeature> features;
  final String? providerModelId;
  final Map<String, dynamic> rawMetadata;
  final int? contextWindow;
  final int? maxOutputTokens;
  final Set<AiTaskId> unsupportedTasks;

  bool supports(ModelCapability capability) =>
      capabilities?.contains(capability) ?? false;
}

class _DiscoveryResponse {
  const _DiscoveryResponse(this.data, this.catalogue);

  final Object? data;
  final String catalogue;
}

abstract interface class ProviderConnectionTester {
  Future<ProviderConnectionResult> test(
    InferenceProviderDefinition definition, {
    required String baseUrl,
    String? credential,
  });

  Future<List<ProviderModelInfo>> listModels(
    InferenceProviderDefinition definition, {
    required String baseUrl,
    String? credential,
  });
}

class HttpProviderConnectionTester implements ProviderConnectionTester {
  HttpProviderConnectionTester(this._dio);

  final Dio _dio;

  @override
  Future<ProviderConnectionResult> test(
    InferenceProviderDefinition definition, {
    required String baseUrl,
    String? credential,
  }) async {
    if (!definition.canTest) {
      return const ProviderConnectionResult(
        ok: false,
        message: 'This provider has no HTTP connection test.',
      );
    }
    final base = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      return const ProviderConnectionResult(
        ok: false,
        message: 'Enter an endpoint URL before testing.',
      );
    }
    final path = definition.testPath!;
    final headers = providerAuthHeaders(definition, credential);

    try {
      final response = await _dio.get<dynamic>(
        '$base$path',
        options: Options(
          headers: headers,
          validateStatus: (_) => true,
          responseType: ResponseType.json,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        final count = _modelCount(response.data);
        return ProviderConnectionResult(
          ok: true,
          statusCode: status,
          modelCount: count,
          message: count == null
              ? 'Endpoint reachable (HTTP $status).'
              : 'Endpoint reachable — returned $count model${count == 1 ? '' : 's'}.',
        );
      }
      return ProviderConnectionResult(
        ok: false,
        statusCode: status,
        message: switch (status) {
          401 || 403 => 'Authentication failed (HTTP $status).',
          404 => 'Endpoint reachable, but the models path returned 404.',
          429 => 'The provider rate-limited the test (HTTP 429).',
          >= 500 => 'The provider returned a server error (HTTP $status).',
          _ => 'The endpoint returned HTTP $status.',
        },
      );
    } on DioException catch (error) {
      if (isNetworkUnavailable(error)) {
        return const ProviderConnectionResult(
          ok: false,
          message: 'Could not reach the endpoint. Check the URL and network.',
        );
      }
      return ProviderConnectionResult(
        ok: false,
        message: 'The connection test failed (${error.type.name}).',
      );
    } on Object {
      return const ProviderConnectionResult(
        ok: false,
        message: 'The connection test failed unexpectedly.',
      );
    }
  }

  @override
  Future<List<ProviderModelInfo>> listModels(
    InferenceProviderDefinition definition, {
    required String baseUrl,
    String? credential,
  }) async {
    if (!definition.canTest) return const [];
    final base = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (base.isEmpty) return const [];
    final responses = await _discoveryResponses(definition, base, credential);
    final models = <ProviderModelInfo>[];
    for (final response in responses) {
      final rows = switch (response.data) {
        Map data when data['data'] is List => data['data'] as List,
        Map data when data['models'] is List => data['models'] as List,
        Map data when data['items'] is List => data['items'] as List,
        List data => data,
        _ => const <Object?>[],
      };
      for (final row in rows) {
        if (row is! Map) continue;
        final map = {
          for (final entry in row.entries) '${entry.key}': entry.value,
        };
        final model = _normalizeModel(
          definition,
          map,
          catalogue: response.catalogue,
        );
        if (model != null) models.add(model);
      }
    }
    return List.unmodifiable(models);
  }

  Future<List<_DiscoveryResponse>> _discoveryResponses(
    InferenceProviderDefinition definition,
    String base,
    String? credential,
  ) async {
    final urls = switch (definition.id) {
      'xai' => const [
        ('https://api.x.ai/v1/language-models', 'language'),
        ('https://api.x.ai/v1/image-generation-models', 'image'),
        ('https://api.x.ai/v1/video-generation-models', 'video'),
      ],
      'deepseek' => const [('https://api.deepseek.com/models', 'models')],
      'google' => const [
        ('https://generativelanguage.googleapis.com/v1beta/models', 'models'),
      ],
      'qwen' => [(_qwenDiscoveryUrl(base), 'models')],
      'huggingface' => const [
        ('https://router.huggingface.co/v1/models', 'router'),
      ],
      _ => [('$base${definition.testPath}', 'models')],
    };

    final responses = <_DiscoveryResponse>[];
    for (final (url, catalogue) in urls) {
      Object? pageToken;
      var page = 0;
      do {
        final query = <String, dynamic>{
          if (definition.id == 'anthropic') 'limit': 100,
          if (pageToken != null) ..._pageQuery(definition.id, pageToken),
          if (definition.id == 'google' && credential != null)
            'key': credential,
          if (definition.id == 'qwen') 'pageSize': 100,
        };
        final response = await _dio.get<dynamic>(
          url,
          queryParameters: query.isEmpty ? null : query,
          options: Options(
            headers: providerAuthHeaders(definition, credential),
            validateStatus: (_) => true,
            responseType: ResponseType.json,
          ),
        );
        final status = response.statusCode ?? 0;
        if (status < 200 || status >= 300) {
          throw StateError(
            '${definition.id} model discovery returned HTTP $status.',
          );
        }
        responses.add(_DiscoveryResponse(response.data, catalogue));
        pageToken = _nextPageToken(definition.id, response.data);
        page++;
      } while (pageToken != null && page < 100);
    }
    return responses;
  }

  String _qwenDiscoveryUrl(String base) {
    final uri = Uri.tryParse(base);
    final host = uri?.host ?? '';
    if (host.contains('dashscope-intl') || host.contains('dashscope-us')) {
      return '${uri!.scheme}://${uri.host}/api/v1/models';
    }
    return 'https://dashscope.aliyuncs.com/api/v1/models';
  }

  Map<String, dynamic> _pageQuery(String providerId, Object token) =>
      switch (providerId) {
        'anthropic' => {'after_id': token},
        'google' => {'pageToken': token},
        'qwen' => {'pageNo': token},
        _ => {'page': token},
      };

  Object? _nextPageToken(String providerId, Object? data) {
    if (data is! Map) return null;
    final token =
        data['next_page_token'] ??
        data['nextPageToken'] ??
        data['next_page'] ??
        data['nextPage'];
    if (token is String && token.isNotEmpty) return token;
    if (providerId == 'anthropic' && data['has_more'] == true) {
      final models = data['data'];
      if (models is List && models.isNotEmpty && models.last is Map) {
        return models.last['id'];
      }
    }
    return null;
  }

  ProviderModelInfo? _normalizeModel(
    InferenceProviderDefinition definition,
    Map<String, dynamic> map, {
    required String catalogue,
  }) {
    final id =
        _stringValue(map['id']) ??
        _stringValue(map['name']) ??
        _stringValue(map['model']);
    if (id == null || id.trim().isEmpty) return null;
    final tasks = <TaskDeclaration>{};
    final capabilities = <ModelCapability>{};
    final explicitTasks = _taskValues(definition.id, map, catalogue);
    for (final task in explicitTasks) {
      final declaration = declarationFromPipelineTag(
        task,
        source: TaskMetadataSource.provider,
      );
      if (declaration != null) {
        tasks.add(declaration);
        final capability = ModelCapability.fromPipelineTag(task);
        if (capability != null) capabilities.add(capability);
      }
    }
    final metadataConfidence = tasks.isEmpty
        ? TaskMetadataConfidence.unknown
        : _isPartialMetadata(definition.id, map)
        ? TaskMetadataConfidence.partial
        : TaskMetadataConfidence.explicit;
    final normalized = Map<String, dynamic>.from(map)
      ..['_discovery_catalogue'] = catalogue;
    final unsupportedTasks = <AiTaskId>{};
    final unsupported = map['unsupported_tasks'] ?? map['unsupportedTasks'];
    if (unsupported is List) {
      for (final value in unsupported) {
        if (value is String) {
          final task = taskFromPipelineTag(value) ?? AiTaskId.fromId(value);
          if (task != null) unsupportedTasks.add(task);
        }
      }
    }
    return ProviderModelInfo(
      id: id,
      name:
          _stringValue(map['display_name']) ??
          _stringValue(map['displayName']) ??
          id,
      capabilities: capabilities.isEmpty
          ? null
          : List.unmodifiable(capabilities),
      tasks: List.unmodifiable(tasks),
      metadataConfidence: metadataConfidence,
      inputModalities: _modalities(
        map['input_modalities'] ?? map['inputModalities'] ?? map['modalities'],
      ),
      outputModalities: _modalities(
        map['output_modalities'] ?? map['outputModalities'],
      ),
      features: _featuresFor(definition.id, map),
      providerModelId: id,
      rawMetadata: normalized,
      contextWindow: _intValue(
        map['inputTokenLimit'] ??
            map['input_token_limit'] ??
            map['context_length'] ??
            map['max_context_length'],
      ),
      maxOutputTokens: _intValue(
        map['outputTokenLimit'] ??
            map['output_token_limit'] ??
            map['max_output_tokens'],
      ),
      unsupportedTasks: Set.unmodifiable(unsupportedTasks),
    );
  }

  List<String> _taskValues(
    String providerId,
    Map<String, dynamic> map,
    String catalogue,
  ) {
    final result = <String>[];
    void add(Object? value) {
      if (value is String) result.add(value);
      if (value is List) {
        for (final item in value) {
          if (item is String) result.add(item);
        }
      }
    }

    add(map['pipeline_tag']);
    add(map['task']);
    add(map['supported_tasks']);
    if (providerId == 'google') {
      final methods = map['supportedGenerationMethods'];
      if (methods is List && methods.contains('generateContent')) {
        result.add('text-generation');
      }
    }
    if (providerId == 'mistral') {
      final capabilities = map['capabilities'];
      if (capabilities is Map && capabilities['completion_chat'] == true) {
        result.add('text-generation');
      }
      if (capabilities is Map && capabilities['vision'] == true) {
        result.add('image-text-to-text');
      }
    }
    if (providerId == 'anthropic') {
      final capabilities = map['capabilities'];
      if (capabilities is Map &&
          (capabilities['image_input'] == true ||
              capabilities['supports_vision'] == true)) {
        result.add('image-text-to-text');
      }
    }
    if (providerId == 'xai') {
      result.add(switch (catalogue) {
        'image' => 'text-to-image',
        'video' => 'text-to-video',
        _ => 'text-generation',
      });
    }
    return result;
  }

  bool _isPartialMetadata(String providerId, Map<String, dynamic> map) {
    return providerId == 'deepseek' ||
        (providerId == 'google' && map['supportedGenerationMethods'] != null);
  }

  Set<AiFeature> _featuresFor(String providerId, Map<String, dynamic> map) {
    final result = _features(map);
    final capabilities = map['capabilities'];
    if (capabilities is Map) {
      if (capabilities['function_calling'] == true ||
          capabilities['functionCalling'] == true) {
        result.add(AiFeature.toolCalling);
      }
      if (capabilities['vision'] == true) result.add(AiFeature.reasoning);
    }
    if (providerId == 'anthropic' && map['thinking'] != null) {
      result.add(AiFeature.reasoning);
    }
    return result;
  }

  String? _stringValue(Object? value) => value is String ? value : null;

  int? _intValue(Object? value) => value is num ? value.toInt() : null;

  Set<AiModality> _modalities(Object? value) {
    if (value is Map) {
      return _modalities([
        for (final entry in value.entries)
          if (entry.value == true) entry.key,
      ]);
    }
    if (value is! List) return const {};
    return {
      for (final item in value)
        if (item is String)
          ...switch (item.toLowerCase()) {
            'text' => [AiModality.text],
            'image' || 'vision' => [AiModality.image],
            'audio' => [AiModality.audio],
            'video' => [AiModality.video],
            _ => const <AiModality>[],
          },
    };
  }

  Set<AiFeature> _features(Map<String, dynamic> map) => {
    if (map['tool_calls'] == true || map['tools'] == true)
      AiFeature.toolCalling,
    if (map['structured_outputs'] == true || map['structured_output'] == true)
      AiFeature.structuredOutput,
    if (map['reasoning'] == true || map['thinking'] == true)
      AiFeature.reasoning,
  };

  int? _modelCount(Object? data) {
    if (data is List) return data.length;
    if (data is Map) {
      final models = data['models'];
      if (models is List) return models.length;
      final items = data['data'];
      if (items is List) return items.length;
    }
    return null;
  }
}

final providerTestDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final providerConnectionTesterProvider = Provider<ProviderConnectionTester>(
  (ref) => HttpProviderConnectionTester(ref.watch(providerTestDioProvider)),
);
