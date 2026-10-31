import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/models/catalogue/catalogue_controller.dart';
import 'package:kritha/features/models/catalogue/catalogue_failure.dart';
import 'package:kritha/features/models/catalogue/catalogue_filter.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';
import 'package:kritha/features/models/catalogue/catalogue_providers.dart';
import 'package:kritha/features/models/catalogue/hugging_face_hub_client.dart';
import 'package:kritha/features/models/catalogue/model_catalogue_repository.dart';

import '../../support/fake_workspace.dart';

void main() {
  group('catalogue parsing', () {
    test('maps Hub metadata and capabilities', () {
      final model = CatalogueModel.fromJson({
        'modelId': 'meta-llama/Llama-3.2-1B',
        'pipeline_tag': 'text-generation',
        'library_name': 'transformers',
        'tags': ['text-generation', 'license:llama3.2', 'safetensors'],
        'downloads': 1234567,
        'likes': 4321,
        'gated': 'manual',
        'private': true,
        'createdAt': '2026-01-02T03:04:05.000Z',
        'lastModified': '2026-02-03T04:05:06.000Z',
        'cardData': {'license': 'llama3.2'},
      });

      expect(model.id, 'meta-llama/Llama-3.2-1B');
      expect(model.namespace, 'meta-llama');
      expect(model.name, 'Llama-3.2-1B');
      expect(model.downloads, 1234567);
      expect(model.likes, 4321);
      expect(model.gated, isTrue);
      expect(model.isPrivate, isTrue);
      expect(model.license, 'llama3.2');
      expect(model.capabilities, contains(ModelCapability.text));
      expect(model.createdAt, isNotNull);
      expect(model.publisherLabel, 'Meta Llama');
      expect(model.id, 'meta-llama/Llama-3.2-1B');
    });

    test('groups pipeline tags into catalogue capabilities', () {
      expect(
        ModelCapability.fromPipelineTag('automatic-speech-recognition'),
        ModelCapability.speechRecognition,
      );
      expect(
        ModelCapability.fromPipelineTag('text-to-image'),
        ModelCapability.imageGeneration,
      );
      expect(
        ModelCapability.fromPipelineTag('video-text-to-text'),
        ModelCapability.video,
      );
      expect(
        ModelCapability.fromTags('feature-extraction', const ['safetensors']),
        [ModelCapability.embeddings],
      );
    });

    test(
      'task filtering excludes generation without excluding vision text',
      () {
        final text = CatalogueModel.fromJson({
          'id': 'google/gemma-vision',
          'pipeline_tag': 'image-text-to-text',
          'tags': ['text-generation'],
        });
        final imageGeneration = CatalogueModel.fromJson({
          'id': 'publisher/image-model',
          'pipeline_tag': 'text-to-image',
        });
        final audioGeneration = CatalogueModel.fromJson({
          'id': 'publisher/audio-model',
          'pipeline_tag': 'text-to-audio',
        });
        final videoGeneration = CatalogueModel.fromJson({
          'id': 'publisher/video-model',
          'pipeline_tag': 'text-to-video',
        });

        expect(text.hasDiscoverableTask, isTrue);
        expect(
          filterDiscoverableModels([
            text,
            imageGeneration,
            audioGeneration,
            videoGeneration,
          ]),
          [text],
        );
      },
    );

    test('formats model card metadata only when it is present', () {
      final model = CatalogueModel.fromJson({
        'id': 'google/gemma-vision',
        'author': 'google',
        'pipeline_tag': 'image-text-to-text',
        'safetensors': {
          'parameters': {'F16': 8000000000},
        },
      });
      final sparse = CatalogueModel.fromJson({'id': 'team/name-with-details'});

      expect(model.publisherLabel, 'Google');
      expect(model.name, 'gemma-vision');
      expect(model.parameterCount, 8000000000);
      expect(model.taskLabel, 'Image-Text-To-Text');
      expect(sparse.parameterCount, isNull);
      expect(sparse.lastModified, isNull);
      expect(sparse.publisher, 'team');
    });

    test('parses files, details and runtime format hints', () {
      final file = ModelFile.fromJson({
        'type': 'file',
        'path': 'model.litertlm',
        'size': 2048,
        'lfs': {'size': 4096},
      });
      expect(file.path, 'model.litertlm');
      expect(file.sizeBytes, 2048);
      expect(file.isLfs, isTrue);
      expect(file.isLitertLm, isTrue);
      expect(file.readableSize, '2.0 KB');

      final details = ModelDetails.fromJson(
        {
          'modelId': 'acme/tiny',
          'pipeline_tag': 'text-generation',
          'tags': ['gguf', 'license:mit'],
          'config': {
            'architectures': ['LlamaForCausalLM'],
            'model_type': 'llama',
          },
        },
        files: [file],
        readme: '# Tiny',
      );
      expect(details.hasLitertLmFile, isTrue);
      expect(details.formats, containsAll(['GGUF', 'LiteRT-LM']));
      expect(details.architecture, 'LlamaForCausalLM');
      expect(details.readme, '# Tiny');
    });

    test('formats large counts compactly', () {
      expect(formatCount(999), '999');
      expect(formatCount(1200), '1.2k');
      expect(formatCount(1500000), '1.5M');
    });

    test('extracts the next cursor from a Link header', () {
      expect(
        parseNextCursor(
          '<https://huggingface.co/api/models?limit=20&cursor=abc123>; rel="next"',
        ),
        'abc123',
      );
      expect(parseNextCursor(null), isNull);
      expect(
        parseNextCursor('<https://huggingface.co/api/models>; rel="prev"'),
        isNull,
      );
    });
  });

  group('Hub client', () {
    test('sends search, filter, sort, cursor and auth headers', () async {
      final adapter = _FakeHttpAdapter((options) async {
        return _jsonResponse(
          [
            {
              'modelId': 'acme/model',
              'pipeline_tag': 'text-generation',
              'downloads': 10,
              'likes': 2,
            },
          ],
          headers: {
            'link': [
              '<https://huggingface.co/api/models?cursor=next-page>; rel="next"',
            ],
          },
        );
      });
      final client = HuggingFaceHubClient(
        _dio(adapter),
        () async => 'hf_secret',
      );

      final page = await client.searchModels(
        query: '  llama  ',
        capability: ModelCapability.text,
        sort: CatalogueSort.likes,
        limit: 10,
        cursor: 'abc',
      );

      expect(page.models.single.id, 'acme/model');
      expect(page.nextCursor, 'next-page');
      final request = adapter.requests.single;
      expect(request.path, '/api/models');
      expect(
        request.uri.queryParametersAll['filter'],
        unorderedEquals(<String>['litert-lm', 'text-generation']),
      );
      expect(request.queryParameters['search'], 'llama');
      expect(request.queryParameters['sort'], 'likes');
      expect(request.queryParameters['direction'], -1);
      expect(request.queryParameters['limit'], 10);
      expect(request.queryParameters['cursor'], 'abc');
      expect(
        request.uri.queryParametersAll['expand'],
        containsAll(<String>['safetensors', 'downloads', 'likes']),
      );
      expect(request.headers['authorization'], 'Bearer hf_secret');
    });

    test('uses the Hub trending score with category filters', () async {
      final adapter = _FakeHttpAdapter((options) async => _jsonResponse([]));
      final client = HuggingFaceHubClient(_dio(adapter), () async => null);

      await client.searchModels(
        capability: ModelCapability.text,
        sort: CatalogueSort.trending,
      );

      final request = adapter.requests.single;
      expect(
        request.uri.queryParametersAll['filter'],
        unorderedEquals(<String>['litert-lm', 'text-generation']),
      );
      expect(request.queryParameters['sort'], 'trendingScore');
      expect(request.queryParameters['direction'], -1);
    });

    test('applies the LiteRT-LM filter to the initial listing', () async {
      final adapter = _FakeHttpAdapter((options) async => _jsonResponse([]));
      final client = HuggingFaceHubClient(_dio(adapter), () async => null);

      await client.searchModels();

      final request = adapter.requests.single;
      expect(request.queryParameters['search'], isNull);
      expect(
        request.uri.queryParametersAll['filter'],
        unorderedEquals(<String>['litert-lm']),
      );
    });

    test('omits the authorization header for public browsing', () async {
      final adapter = _FakeHttpAdapter((options) async => _jsonResponse([]));
      final client = HuggingFaceHubClient(_dio(adapter), () async => null);

      await client.searchModels();

      expect(
        adapter.requests.single.headers.containsKey('authorization'),
        isFalse,
      );
    });

    test(
      'sends preset and user filters and can omit the default tag',
      () async {
        final adapter = _FakeHttpAdapter((options) async => _jsonResponse([]));
        final client = HuggingFaceHubClient(_dio(adapter), () async => null);

        await client.searchModels(
          filters: const [
            CatalogueFilterPresets.litertLm,
            CatalogueFilter(value: 'apache-2.0'),
          ],
        );

        final request = adapter.requests.single;
        expect(
          request.uri.queryParametersAll['filter'],
          unorderedEquals(<String>['litert-lm', 'apache-2.0']),
        );

        await client.searchModels(filters: const []);

        expect(
          adapter.requests.last.queryParameters.containsKey('filter'),
          isFalse,
        );
      },
    );

    test('keeps public browsing working when the token store fails', () async {
      final adapter = _FakeHttpAdapter((options) async => _jsonResponse([]));
      final client = HuggingFaceHubClient(
        _dio(adapter),
        () async => throw StateError('secure storage unavailable'),
      );

      await client.searchModels();

      expect(
        adapter.requests.single.headers.containsKey('authorization'),
        isFalse,
      );
    });

    test('maps rate limits and unauthorized responses', () async {
      final rateLimited = HuggingFaceHubClient(
        _dio(
          _FakeHttpAdapter((options) async => _jsonResponse({}, status: 429)),
        ),
        () async => null,
      );
      await expectLater(
        rateLimited.searchModels(),
        throwsA(
          isA<CatalogueFailure>().having(
            (failure) => failure.kind,
            'kind',
            CatalogueFailureKind.rateLimited,
          ),
        ),
      );

      final unauthorized = HuggingFaceHubClient(
        _dio(
          _FakeHttpAdapter((options) async => _jsonResponse({}, status: 401)),
        ),
        () async => 'bad',
      );
      await expectLater(
        unauthorized.searchModels(),
        throwsA(
          isA<CatalogueFailure>().having(
            (failure) => failure.kind,
            'kind',
            CatalogueFailureKind.unauthorized,
          ),
        ),
      );
    });

    test('rejects a response that is not a model array', () async {
      final client = HuggingFaceHubClient(
        _dio(_FakeHttpAdapter((options) async => _jsonResponse({'data': []}))),
        () async => null,
      );
      await expectLater(
        client.searchModels(),
        throwsA(
          isA<CatalogueFailure>().having(
            (failure) => failure.kind,
            'kind',
            CatalogueFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('treats a missing README and file tree as empty', () async {
      final adapter = _FakeHttpAdapter((options) async {
        if (options.path.contains('README')) {
          return _textResponse('not found', status: 404);
        }
        return _jsonResponse({}, status: 404);
      });
      final client = HuggingFaceHubClient(_dio(adapter), () async => null);

      expect(await client.fetchReadme('acme/model'), isNull);
      expect(await client.fetchFiles('acme/model'), isEmpty);
    });

    test(
      'fetches organization statistics and falls back to a user profile',
      () async {
        final adapter = _FakeHttpAdapter((options) async {
          if (options.path.contains('/organizations/')) {
            return _jsonResponse({}, status: 404);
          }
          return _jsonResponse({
            'name': 'someone',
            'numFollowers': 12,
            'numFollowing': 4,
          });
        });
        final client = HuggingFaceHubClient(_dio(adapter), () async => null);

        final publisher = await client.fetchPublisher('someone');

        expect(publisher?.name, 'someone');
        expect(publisher?.isOrganization, isFalse);
        expect(publisher?.followers, 12);
        expect(publisher?.following, 4);
        expect(adapter.requests.map((request) => request.path), [
          '/api/organizations/someone/overview',
          '/api/users/someone/overview',
        ]);
      },
    );

    test('resolves a publisher avatar through the user fallback', () async {
      final adapter = _FakeHttpAdapter((options) async {
        if (options.path.contains('/organizations/')) {
          return _jsonResponse({}, status: 404);
        }
        return _jsonResponse({
          'avatarUrl':
              'https://cdn-avatars.huggingface.co/v1/production/uploads/a.png',
        });
      });
      final client = HuggingFaceHubClient(_dio(adapter), () async => null);

      final avatar = await client.fetchPublisherAvatar('someone');

      expect(
        avatar,
        'https://cdn-avatars.huggingface.co/v1/production/uploads/a.png',
      );
      expect(adapter.requests.map((request) => request.path), [
        '/api/organizations/someone/avatar',
        '/api/users/someone/avatar',
      ]);
    });

    test('requests the top-level repository tree', () async {
      final adapter = _FakeHttpAdapter(
        (options) async => _jsonResponse([
          {'path': 'nested', 'type': 'directory'},
          {'path': 'model.litertlm', 'type': 'file', 'size': 2048},
        ]),
      );
      final client = HuggingFaceHubClient(_dio(adapter), () async => null);

      final files = await client.fetchFiles('acme/model');

      expect(adapter.requests.single.path, '/api/models/acme/model/tree/main');
      expect(adapter.requests.single.queryParameters, isEmpty);
      expect(files, hasLength(2));
      expect(files.first.isDirectory, isTrue);
      expect(files.last.readableSize, '2.0 KB');
    });

    test('validates a token through whoami-v2', () async {
      final adapter = _FakeHttpAdapter((options) async {
        return _jsonResponse({'name': 'kaushal', 'fullname': 'Kaushal'});
      });
      final client = HuggingFaceHubClient(_dio(adapter), () async => null);

      final account = await client.validateToken('hf_candidate');

      expect(account.name, 'kaushal');
      expect(adapter.requests.single.path, '/api/whoami-v2');
      expect(
        adapter.requests.single.headers['authorization'],
        'Bearer hf_candidate',
      );
    });

    test('surfaces cancellation as an internal signal', () async {
      final client = HuggingFaceHubClient(
        _dio(_FakeHttpAdapter((options) async => _jsonResponse([]))),
        () async => null,
      );
      final cancel = CancelToken()..cancel();

      await expectLater(
        client.searchModels(cancelToken: cancel),
        throwsA(isA<CatalogueCancelled>()),
      );
    });
  });

  group('catalogue controller', () {
    test('loads a page and appends the next cursor', () async {
      final fake = FakeModelCatalogue(
        pages: const {
          null: ModelPage(
            models: [
              CatalogueModel(id: 'acme/one'),
              CatalogueModel(id: 'acme/two'),
            ],
            nextCursor: 'c1',
          ),
          'c1': ModelPage(models: [CatalogueModel(id: 'acme/three')]),
        },
      );
      final container = ProviderContainer(
        overrides: [modelCatalogueProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final controller = container.read(catalogueProvider.notifier);
      await controller.search(query: 'acme');
      expect(container.read(catalogueProvider).models, hasLength(2));
      expect(container.read(catalogueProvider).nextCursor, 'c1');

      await controller.loadMore();
      final state = container.read(catalogueProvider);
      expect(state.models.map((model) => model.id), [
        'acme/one',
        'acme/two',
        'acme/three',
      ]);
      expect(state.nextCursor, isNull);
      expect(fake.calls, hasLength(2));
      expect(fake.calls.last.cursor, 'c1');
      expect(fake.calls.last.query, 'acme');
    });

    test('filters generation tasks in search and appended pages', () async {
      final fake = FakeModelCatalogue(
        pages: const {
          null: ModelPage(
            models: [
              CatalogueModel(id: 'org/text', pipelineTag: 'text-generation'),
              CatalogueModel(id: 'org/image', pipelineTag: 'text-to-image'),
            ],
            nextCursor: 'next',
          ),
          'next': ModelPage(
            models: [
              CatalogueModel(id: 'org/audio', pipelineTag: 'text-to-audio'),
              CatalogueModel(
                id: 'org/vision-text',
                pipelineTag: 'image-text-to-text',
              ),
            ],
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [modelCatalogueProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final controller = container.read(catalogueProvider.notifier);
      await controller.search(query: 'org');
      expect(container.read(catalogueProvider).models.map((m) => m.id), [
        'org/text',
      ]);
      await controller.loadMore();
      expect(container.read(catalogueProvider).models.map((m) => m.id), [
        'org/text',
        'org/vision-text',
      ]);
    });

    test('keeps the selected filters on later pages', () async {
      final fake = FakeModelCatalogue(
        pages: const {
          null: ModelPage(
            models: [CatalogueModel(id: 'acme/one')],
            nextCursor: 'c1',
          ),
          'c1': ModelPage(models: [CatalogueModel(id: 'acme/two')]),
        },
      );
      final container = ProviderContainer(
        overrides: [modelCatalogueProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      const filters = [CatalogueFilter(value: 'apache-2.0')];
      final controller = container.read(catalogueProvider.notifier);
      expect(
        container.read(catalogueProvider).filters,
        CatalogueFilterPresets.defaults,
      );

      await controller.search(filters: filters);
      expect(container.read(catalogueProvider).filters, filters);
      expect(fake.calls.last.filters, filters);

      await controller.loadMore();
      expect(fake.calls.last.filters, filters);
      expect(fake.calls.last.cursor, 'c1');
    });

    test('ignores a stale first search when a newer one wins', () async {
      final fake = _DelayedCatalogue();
      final container = ProviderContainer(
        overrides: [modelCatalogueProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      final controller = container.read(catalogueProvider.notifier);

      final first = controller.search(query: 'first');
      final second = controller.search(query: 'second');
      fake.complete(
        0,
        const ModelPage(models: [CatalogueModel(id: 'stale/model')]),
      );
      fake.complete(
        1,
        const ModelPage(models: [CatalogueModel(id: 'fresh/model')]),
      );
      await Future.wait([first, second]);

      final state = container.read(catalogueProvider);
      expect(state.query, 'second');
      expect(state.models.single.id, 'fresh/model');
    });
  });
}

Dio _dio(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: HuggingFaceHubClient.baseUrl));
  dio.httpClientAdapter = adapter;
  return dio;
}

ResponseBody _jsonResponse(
  Object? data, {
  int status = 200,
  Map<String, List<String>>? headers,
}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
      ...?headers,
    },
  );
}

ResponseBody _textResponse(String data, {int status = 200}) {
  return ResponseBody.fromString(
    data,
    status,
    headers: {
      Headers.contentTypeHeader: ['text/plain'],
    },
  );
}

class _FakeHttpAdapter implements HttpClientAdapter {
  _FakeHttpAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _DelayedCatalogue implements ModelCatalogue {
  final _completers = <Completer<ModelPage>>[];

  @override
  Future<ModelPage> search({
    String? query,
    ModelCapability? capability,
    CatalogueSort sort = CatalogueSort.downloads,
    int limit = 24,
    String? cursor,
    List<CatalogueFilter> filters = CatalogueFilterPresets.defaults,
    CancelToken? cancelToken,
  }) {
    final completer = Completer<ModelPage>();
    _completers.add(completer);
    return completer.future;
  }

  @override
  Future<ModelDetails> details(String id, {CancelToken? cancelToken}) {
    throw UnimplementedError();
  }

  @override
  Future<HubAccount> validateToken(String token) {
    throw UnimplementedError();
  }

  void complete(int index, ModelPage page) {
    _completers[index].complete(page);
  }
}
