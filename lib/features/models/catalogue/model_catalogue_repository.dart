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
    final model = CatalogueModel.fromJson(document);
    final publisherName = model.author ?? model.namespace;
    final results = await Future.wait<Object?>([
      _client.fetchFiles(id, cancelToken: cancelToken),
      _client.fetchReadme(id, cancelToken: cancelToken),
      publisherName.isEmpty
          ? Future<HubPublisher?>.value()
          : _client.fetchPublisher(publisherName, cancelToken: cancelToken),
    ]);
    return ModelDetails.fromJson(
      document,
      files: results[0] as List<ModelFile>,
      readme: results[1] as String?,
      publisher: results[2] as HubPublisher?,
    );
  }

  @override
  Future<HubAccount> validateToken(String token) =>
      _client.validateToken(token);
}
