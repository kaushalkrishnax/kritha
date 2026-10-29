import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_error_utils.dart';
import '../models/catalogue/catalogue_model.dart';
import 'provider_definition.dart';

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
  });

  final String id;
  final String name;
  final int? parameterCount;
  final List<ModelCapability>? capabilities;

  bool supports(ModelCapability capability) => capabilities == null
      ? capability == ModelCapability.text
      : capabilities!.contains(capability);
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

  Map<String, String> _headersFor(
    InferenceProviderDefinition definition,
    String? credential,
  ) {
    final headers = <String, String>{'accept': 'application/json'};
    final secret = credential?.trim();
    switch (definition.authStyle) {
      case ProviderAuthStyle.none:
        break;
      case ProviderAuthStyle.bearer:
        if (secret != null && secret.isNotEmpty) {
          headers['authorization'] = 'Bearer $secret';
        }
      case ProviderAuthStyle.anthropic:
        if (secret != null && secret.isNotEmpty) {
          headers['x-api-key'] = secret;
        }
        headers['anthropic-version'] = '2023-06-01';
      case ProviderAuthStyle.queryKey:
        break;
    }
    return headers;
  }

  Map<String, dynamic>? _queryFor(
    InferenceProviderDefinition definition,
    String? credential,
  ) {
    final secret = credential?.trim();
    if (definition.authStyle == ProviderAuthStyle.queryKey &&
        secret != null &&
        secret.isNotEmpty) {
      return {'key': secret};
    }
    return null;
  }

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
    final headers = _headersFor(definition, credential);
    final query = _queryFor(definition, credential);

    try {
      final response = await _dio.get<dynamic>(
        '$base$path',
        queryParameters: query,
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
    final response = await _dio.get<dynamic>(
      '$base${definition.testPath}',
      queryParameters: _queryFor(definition, credential),
      options: Options(
        headers: _headersFor(definition, credential),
        validateStatus: (_) => true,
        responseType: ResponseType.json,
      ),
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw StateError('Provider model list returned HTTP $status.');
    }
    final rows = switch (response.data) {
      Map data when data['data'] is List => data['data'] as List,
      Map data when data['models'] is List => data['models'] as List,
      List data => data,
      _ => const <Object?>[],
    };
    final models = <ProviderModelInfo>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final map = {
        for (final entry in row.entries) '${entry.key}': entry.value,
      };
      final id = map['id'] is String
          ? map['id'] as String
          : map['name'] is String
          ? map['name'] as String
          : map['model'] is String
          ? map['model'] as String
          : null;
      if (id == null || id.trim().isEmpty) continue;
      final name = map['display_name'] is String
          ? map['display_name'] as String
          : id;
      final task = map['pipeline_tag'] ?? map['task'];
      final capability = task is String
          ? ModelCapability.fromPipelineTag(task)
          : null;
      final taskList = map['supported_tasks'] ?? map['capabilities'];
      final declaredCapabilities = <ModelCapability>{};
      if (capability != null) declaredCapabilities.add(capability);
      if (taskList is List) {
        for (final item in taskList) {
          if (item is! String) continue;
          final taskCapability = ModelCapability.fromPipelineTag(item);
          if (taskCapability != null) declaredCapabilities.add(taskCapability);
        }
      }
      models.add(
        ProviderModelInfo(
          id: id,
          name: name,
          capabilities: declaredCapabilities.isEmpty
              ? null
              : List.unmodifiable(declaredCapabilities),
        ),
      );
    }
    return List.unmodifiable(models);
  }

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
