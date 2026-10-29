import 'package:dio/dio.dart';

import 'catalogue_model.dart';
import 'hugging_face_hub_client.dart';

/// The catalogue surface the UI and controllers depend on.
abstract interface class ModelCatalogue {
  Future<ModelPage> search({
    String? query,
    ModelCapability? capability,
    CatalogueSort sort = CatalogueSort.downloads,
    int limit = 24,
    String? cursor,
    CancelToken? cancelToken,
  });

  Future<ModelDetails> details(String id, {CancelToken? cancelToken});

  Future<HubAccount> validateToken(String token);
}

class ModelCatalogueRepository implements ModelCatalogue {
  ModelCatalogueRepository(this._client);

  final HuggingFaceHubClient _client;

  @override
  Future<ModelPage> search({
    String? query,
    ModelCapability? capability,
    CatalogueSort sort = CatalogueSort.downloads,
    int limit = 24,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    final page = await _client.searchModels(
      query: query,
      capability: capability,
      sort: sort,
      limit: limit,
      cursor: cursor,
      cancelToken: cancelToken,
    );
    return ModelPage(
      models: filterDiscoverableModels(page.models),
      nextCursor: page.nextCursor,
    );
  }

  @override
  Future<ModelDetails> details(String id, {CancelToken? cancelToken}) async {
    final document = await _client.fetchModelDocument(
      id,
      cancelToken: cancelToken,
    );
    final files = await _client.fetchFiles(id, cancelToken: cancelToken);
    final readme = await _client.fetchReadme(id, cancelToken: cancelToken);
    return ModelDetails.fromJson(document, files: files, readme: readme);
  }

  @override
  Future<HubAccount> validateToken(String token) =>
      _client.validateToken(token);
}
