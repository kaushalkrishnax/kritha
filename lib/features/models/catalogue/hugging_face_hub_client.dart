import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/dio_error_utils.dart';
import 'catalogue_failure.dart';
import 'catalogue_filter.dart';
import 'catalogue_model.dart';
import 'hugging_face_urls.dart';

typedef HubTokenReader = Future<String?> Function();

/// Thin transport over the official Hugging Face Hub API.
///
/// This client owns URL construction, authentication headers and JSON parsing.
/// It never logs requests, and it must be given a [Dio] without a
/// `LogInterceptor` so a Hub token cannot leak into console output.
class HuggingFaceHubClient {
  HuggingFaceHubClient(this._dio, this._readToken);

  static const baseUrl = HuggingFaceUrls.origin;

  // The Hub only returns safetensors metadata when it is explicitly expanded.
  // Expand every list field the catalogue reads so cards can show real
  // parameter counts without a second request per repository.
  static const _listFields = <String>[
    'author',
    'createdAt',
    'lastModified',
    'downloads',
    'likes',
    'pipeline_tag',
    'private',
    'gated',
    'disabled',
    'tags',
    'library_name',
    'safetensors',
  ];

  final Dio _dio;
  final HubTokenReader _readToken;

  Future<ModelPage> searchModels({
    String? query,
    ModelCapability? capability,
    CatalogueSort sort = CatalogueSort.downloads,
    int limit = 24,
    String? cursor,
    List<CatalogueFilter> filters = CatalogueFilterPresets.defaults,
    CancelToken? cancelToken,
  }) async {
    final filterParameters = <String, List<String>>{};
    if (capability != null) {
      (filterParameters['filter'] ??= []).add(capability.pipelineTag);
    }
    for (final filter in filters) {
      if (!filter.isValid) continue;
      (filterParameters[filter.key] ??= []).add(filter.value);
    }
    final response = await _get(
      '/api/models',
      queryParameters: {
        for (final entry in filterParameters.entries)
          entry.key: entry.value.length == 1 ? entry.value.single : entry.value,
        if (query != null && query.trim().isNotEmpty) 'search': query.trim(),
        'sort': sort.apiValue,
        'direction': -1,
        'limit': limit.clamp(1, 100),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'expand': _listFields,
      },
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data is! List) {
      throw const CatalogueFailure(
        kind: CatalogueFailureKind.invalidResponse,
        message: 'The model list was not a JSON array.',
      );
    }
    final models = <CatalogueModel>[];
    for (final item in data) {
      if (item is! Map) {
        throw const CatalogueFailure(
          kind: CatalogueFailureKind.invalidResponse,
          message: 'A model entry was not a JSON object.',
        );
      }
      final model = CatalogueModel.fromJson(_asMap(item));
      if (model.id.isEmpty) {
        throw const CatalogueFailure(
          kind: CatalogueFailureKind.invalidResponse,
          message: 'A model entry was missing its repository id.',
        );
      }
      models.add(model);
    }
    return ModelPage(
      models: List.unmodifiable(models),
      nextCursor: parseNextCursor(response.headers.value('link')),
    );
  }

  Future<Map<String, dynamic>> fetchModelDocument(
    String id, {
    CancelToken? cancelToken,
  }) async {
    final response = await _get(
      '/api/models/${_modelPath(id)}',
      queryParameters: const {'full': true},
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data is! Map) {
      throw const CatalogueFailure(
        kind: CatalogueFailureKind.invalidResponse,
        message: 'The repository response was not a JSON object.',
      );
    }
    final document = _asMap(data);
    if (CatalogueModel.fromJson(document).id.isEmpty) {
      throw const CatalogueFailure(
        kind: CatalogueFailureKind.invalidResponse,
        message: 'The repository response was missing its id.',
      );
    }
    return document;
  }

  Future<List<ModelFile>> fetchFiles(
    String id, {
    String revision = 'main',
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _get(
        '/api/models/${_modelPath(id)}/tree/${Uri.encodeComponent(revision)}',
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is! List) {
        throw const CatalogueFailure(
          kind: CatalogueFailureKind.invalidResponse,
          message: 'The file tree was not a JSON array.',
        );
      }
      return List.unmodifiable([
        for (final item in data)
          if (item is Map && item['path'] != null)
            ModelFile.fromJson(_fileJson(item)),
      ]);
    } on CatalogueFailure catch (failure) {
      if (failure.kind == CatalogueFailureKind.notFound) return const [];
      rethrow;
    }
  }

  Future<HubPublisher?> fetchPublisher(
    String name, {
    CancelToken? cancelToken,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return null;
    final encoded = Uri.encodeComponent(normalized);
    for (final (path, organization) in [
      ('/api/organizations/$encoded/overview', true),
      ('/api/users/$encoded/overview', false),
    ]) {
      try {
        final response = await _get(path, cancelToken: cancelToken);
        final data = response.data;
        if (data is! Map) continue;
        return HubPublisher.fromJson(
          _asMap(data),
          fallbackName: normalized,
          organization: organization,
        );
      } on CatalogueFailure catch (failure) {
        if (failure.kind == CatalogueFailureKind.notFound) continue;
        return null;
      }
    }
    return null;
  }

  /// Search results carry only the publisher name, so the avatar needs a
  /// second, per-publisher lookup. Callers should cache the result.
  Future<String?> fetchPublisherAvatar(
    String name, {
    CancelToken? cancelToken,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return null;
    final encoded = Uri.encodeComponent(normalized);
    for (final path in [
      '/api/organizations/$encoded/avatar',
      '/api/users/$encoded/avatar',
    ]) {
      try {
        final response = await _get(path, cancelToken: cancelToken);
        final data = response.data;
        if (data is! Map) continue;
        final url = data['avatarUrl'];
        if (url is String && url.trim().isNotEmpty) return url.trim();
      } on CatalogueFailure catch (failure) {
        if (failure.kind == CatalogueFailureKind.notFound) continue;
        return null;
      }
    }
    return null;
  }

  Future<String?> fetchReadme(String id, {CancelToken? cancelToken}) async {
    try {
      final response = await _get(
        '/${_modelPath(id)}/raw/main/README.md',
        responseType: ResponseType.plain,
        cancelToken: cancelToken,
      );
      final data = response.data;
      return data is String && data.trim().isNotEmpty ? data : null;
    } on CatalogueFailure catch (failure) {
      if (failure.kind == CatalogueFailureKind.notFound) return null;
      rethrow;
    }
  }

  Future<HubAccount> validateToken(String token) async {
    final response = await _get('/api/whoami-v2', tokenOverride: token);
    final data = response.data;
    if (data is! Map) {
      throw const CatalogueFailure(
        kind: CatalogueFailureKind.invalidResponse,
        message: 'The token response was not a JSON object.',
      );
    }
    return HubAccount.fromJson(_asMap(data));
  }

  /// Downloads one repository file to [destinationPath]; the caller owns the
  /// destination directory and any cleanup after a failure.
  Future<void> downloadFile({
    required String repositoryId,
    required String revision,
    required String path,
    required String destinationPath,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    String? token;
    try {
      token = await _readToken();
    } on Object {
      token = null;
    }
    final trimmed = token?.trim();
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    if (await file.exists()) await file.delete();
    try {
      await _dio.download(
        '/${_modelPath(repositoryId)}/resolve/'
        '${Uri.encodeComponent(revision)}/${_encodePath(path)}',
        destinationPath,
        cancelToken: cancelToken,
        deleteOnError: true,
        options: Options(
          headers: trimmed == null || trimmed.isEmpty
              ? null
              : {'authorization': 'Bearer $trimmed'},
        ),
        onReceiveProgress: (received, total) {
          onProgress(received, total);
        },
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) throw const CatalogueCancelled();
      throw _failureFor(error);
    }
  }

  /// Opens one byte range of a repository file as a raw stream.
  ///
  /// The caller appends chunks to the partial file and calls this again with a
  /// new offset after an interruption. A `416` response means the file already
  /// holds every byte the server has, and a `200` response means the server
  /// ignored the range and sent the whole file from the start.
  Future<HubDownloadChunk> openDownload({
    required String repositoryId,
    required String revision,
    required String path,
    int offset = 0,
  }) async {
    String? token;
    try {
      token = await _readToken();
    } on Object {
      token = null;
    }
    final trimmed = token?.trim();
    final headers = <String, dynamic>{
      if (trimmed != null && trimmed.isNotEmpty)
        'authorization': 'Bearer $trimmed',
      if (offset > 0) HttpHeaders.rangeHeader: 'bytes=$offset-',
    };
    final cancelToken = CancelToken();
    Response<ResponseBody> response;
    try {
      response = await _dio.get<ResponseBody>(
        '/${_modelPath(repositoryId)}/resolve/'
        '${Uri.encodeComponent(revision)}/${_encodePath(path)}',
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          validateStatus: (status) =>
              status != null && (status < 300 || status == 416),
        ),
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) throw const CatalogueCancelled();
      throw _failureFor(error);
    }

    final status = response.statusCode ?? 0;
    if (status == HttpStatus.requestedRangeNotSatisfiable) {
      return HubDownloadChunk(
        stream: const Stream<List<int>>.empty(),
        startOffset: offset,
        totalBytes: offset,
        cancel: () {},
      );
    }

    final body = response.data;
    if (body == null) {
      throw const CatalogueFailure(
        kind: CatalogueFailureKind.invalidResponse,
        message: 'The Hub returned an empty download stream.',
      );
    }

    if (status == HttpStatus.partialContent) {
      final range = _parseContentRange(
        response.headers.value(HttpHeaders.contentRangeHeader),
      );
      return HubDownloadChunk(
        stream: body.stream,
        startOffset: range?.start ?? offset,
        totalBytes: range?.total,
        cancel: () => cancelToken.cancel(),
      );
    }

    return HubDownloadChunk(
      stream: body.stream,
      startOffset: 0,
      totalBytes: _headerInt(
        response.headers.value(HttpHeaders.contentLengthHeader),
      ),
      cancel: () => cancelToken.cancel(),
    );
  }

  Future<Response<dynamic>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
    ResponseType responseType = ResponseType.json,
    CancelToken? cancelToken,
    String? tokenOverride,
  }) async {
    String? token = tokenOverride;
    if (token == null) {
      try {
        token = await _readToken();
      } on Object {
        token = null;
      }
    }
    final trimmed = token?.trim();
    try {
      return await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          responseType: responseType,
          headers: trimmed == null || trimmed.isEmpty
              ? null
              : {'authorization': 'Bearer $trimmed'},
        ),
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) throw const CatalogueCancelled();
      throw _failureFor(error);
    }
  }

  CatalogueFailure _failureFor(DioException error) {
    final status = error.response?.statusCode;
    if (status != null) {
      return switch (status) {
        401 || 403 => CatalogueFailure(
          kind: CatalogueFailureKind.unauthorized,
          message: 'The Hugging Face token is missing, invalid, or lacks access to this repository.',
          statusCode: status,
        ),
        404 => CatalogueFailure(
          kind: CatalogueFailureKind.notFound,
          message: 'Hugging Face has no repository at that address.',
          statusCode: status,
        ),
        429 => CatalogueFailure(
          kind: CatalogueFailureKind.rateLimited,
          message: 'The Hub rate limit was reached. Wait a moment and retry.',
          statusCode: status,
        ),
        >= 500 => CatalogueFailure(
          kind: CatalogueFailureKind.server,
          message: 'The Hub returned a server error (HTTP $status).',
          statusCode: status,
        ),
        _ => CatalogueFailure(
          kind: CatalogueFailureKind.unknown,
          message: 'The Hub returned HTTP $status.',
          statusCode: status,
        ),
      };
    }

    if (isNetworkUnavailable(error)) {
      return const CatalogueFailure(
        kind: CatalogueFailureKind.offline,
        message: 'Could not reach huggingface.co. Check your connection.',
      );
    }

    return CatalogueFailure(
      kind: CatalogueFailureKind.unknown,
      message: 'The catalogue request failed (${error.type.name}).',
    );
  }

  static int? _headerInt(String? value) => int.tryParse(value?.trim() ?? '');

  static _ContentRange? _parseContentRange(String? header) {
    if (header == null) return null;
    final match = RegExp(
      r'bytes\s+(\d+)-(\d+)/(\d+|\*)',
      caseSensitive: false,
    ).firstMatch(header);
    if (match == null) return null;
    return _ContentRange(
      start: int.tryParse(match.group(1) ?? ''),
      total: int.tryParse(match.group(3) ?? ''),
    );
  }

  static String _modelPath(String id) {
    final segments = id.trim().split('/').where((part) => part.isNotEmpty);
    return segments.map(Uri.encodeComponent).join('/');
  }

  static String _encodePath(String value) => value
      .split('/')
      .where((part) => part.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('/');

  static Map<String, dynamic> _asMap(Map<dynamic, dynamic> value) {
    return {for (final entry in value.entries) '${entry.key}': entry.value};
  }

  static Map<String, dynamic> _fileJson(Object? item) {
    if (item is! Map) {
      throw const CatalogueFailure(
        kind: CatalogueFailureKind.invalidResponse,
        message: 'A file entry was not a JSON object.',
      );
    }
    return _asMap(item);
  }
}

/// One open byte range of a repository file.
class HubDownloadChunk {
  const HubDownloadChunk({
    required this.stream,
    required this.startOffset,
    required this.totalBytes,
    required this.cancel,
  });

  final Stream<List<int>> stream;
  final int startOffset;
  final int? totalBytes;
  final void Function() cancel;
}

class _ContentRange {
  const _ContentRange({this.start, this.total});

  final int? start;
  final int? total;
}

/// Extracts the cursor from an RFC 8288 `Link` header returned by the Hub.
String? parseNextCursor(String? linkHeader) {
  if (linkHeader == null || linkHeader.trim().isEmpty) return null;
  final match = RegExp(
    r'<([^>]+)>\s*;\s*rel="?next"?',
    caseSensitive: false,
  ).firstMatch(linkHeader);
  final url = match?.group(1);
  if (url == null) return null;
  final cursor = Uri.tryParse(url)?.queryParameters['cursor'];
  return cursor == null || cursor.isEmpty ? null : cursor;
}
