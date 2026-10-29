import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/intelligence/model_configuration.dart';
import 'package:kritha/features/intelligence/runtime_ids.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';
import 'package:kritha/features/providers/provider_connection_tester.dart';
import 'package:kritha/features/providers/provider_definition.dart';
import 'package:kritha/features/providers/provider_stores.dart';
import 'package:kritha/features/providers/providers_controller.dart';

import 'support/fake_inference.dart';
import 'support/fake_workspace.dart';

void main() {
  ProviderContainer buildContainer({
    InMemoryProviderSettingsStore? settings,
    InMemoryProviderCredentialStore? credentials,
    FakeProviderConnectionTester? tester,
    String? modelPath,
  }) {
    return ProviderContainer(
      overrides: [
        providerSettingsStoreProvider.overrideWithValue(
          settings ?? InMemoryProviderSettingsStore(),
        ),
        providerCredentialStoreProvider.overrideWithValue(
          credentials ?? InMemoryProviderCredentialStore(),
        ),
        providerConnectionTesterProvider.overrideWithValue(
          tester ?? FakeProviderConnectionTester(),
        ),
        modelConfigStoreProvider.overrideWithValue(
          InMemoryModelConfigStore(modelPath),
        ),
      ],
    );
  }

  group('provider configuration', () {
    test(
      'starts with the local runtime configured and hosted providers off',
      () async {
        final container = buildContainer();
        addTearDown(container.dispose);

        final state = await container.read(providersControllerProvider.future);

        expect(state.configurationFor('local-litertlm')!.configured, isTrue);
        expect(state.configurationFor('openai')!.configured, isFalse);
        expect(
          state.configurationFor('openai')!.baseUrl,
          'https://api.openai.com/v1',
        );
        expect(
          state.configurationFor('mistral')!.baseUrl,
          'https://api.mistral.ai/v1',
        );
      },
    );

    test('persists endpoint changes without credentials', () async {
      final settings = InMemoryProviderSettingsStore();
      final container = buildContainer(settings: settings);
      addTearDown(container.dispose);
      await container.read(providersControllerProvider.future);
      final controller = container.read(providersControllerProvider.notifier);

      await controller.setBaseUrl('mistral', 'https://proxy.example.com/v1');

      expect(
        settings.settings['mistral']!.baseUrl,
        'https://proxy.example.com/v1',
      );
      expect(settings.settings['mistral']!.configured, isFalse);
      expect(
        container
            .read(providersControllerProvider)
            .value!
            .configurationFor('mistral')!
            .baseUrl,
        'https://proxy.example.com/v1',
      );
    });

    test(
      'stores credentials in the credential store, never in settings',
      () async {
        final settings = InMemoryProviderSettingsStore();
        final credentials = InMemoryProviderCredentialStore();
        final container = buildContainer(
          settings: settings,
          credentials: credentials,
        );
        addTearDown(container.dispose);
        await container.read(providersControllerProvider.future);
        final controller = container.read(providersControllerProvider.notifier);

        await controller.saveCredential('openai', '  sk-test  ');

        expect(credentials.credentials['openai'], 'sk-test');
        expect(settings.settings['openai']!.configured, isTrue);
        final state = container.read(providersControllerProvider).value!;
        expect(state.configurationFor('openai')!.hasCredential, isTrue);
        expect(
          state.configurationFor('openai')!.hasRequiredCredentials,
          isTrue,
        );
        expect(state.configurationFor('openai')!.configured, isTrue);
        expect(state.toString(), isNot(contains('sk-test')));

        await controller.removeCredential('openai');
        expect(credentials.credentials.containsKey('openai'), isFalse);
        final removed = container
            .read(providersControllerProvider)
            .value!
            .configurationFor('openai')!;
        expect(removed.hasCredential, isFalse);
        expect(removed.hasRequiredCredentials, isFalse);
        expect(removed.configured, isFalse);
        expect(settings.settings.containsKey('openai'), isTrue);
      },
    );

    test(
      'does not call a provider when a required credential is missing',
      () async {
        final tester = FakeProviderConnectionTester();
        final container = buildContainer(tester: tester);
        addTearDown(container.dispose);
        await container.read(providersControllerProvider.future);

        final result = await container
            .read(providersControllerProvider.notifier)
            .testConnection('openai');

        expect(result.ok, isFalse);
        expect(result.message, contains('before testing'));
        expect(tester.testedProviderIds, isEmpty);
      },
    );

    test('stores a real connection-test result', () async {
      final tester = FakeProviderConnectionTester();
      final credentials = InMemoryProviderCredentialStore({
        'openai': 'sk-test',
      });
      final container = buildContainer(
        tester: tester,
        credentials: credentials,
      );
      addTearDown(container.dispose);
      await container.read(providersControllerProvider.future);

      final result = await container
          .read(providersControllerProvider.notifier)
          .testConnection('openai');

      expect(result.ok, isTrue);
      expect(tester.testedProviderIds, ['openai']);
      final state = container.read(providersControllerProvider).value!;
      expect(state.testResults['openai']!.ok, isTrue);
      expect(state.testing, isEmpty);
    });

    test(
      'configured provider models are exposed to the shared model picker',
      () async {
        final tester = FakeProviderConnectionTester()
          ..models['openai'] = const [
            ProviderModelInfo(id: 'gpt-4o', name: 'GPT-4o'),
          ];
        final settings = InMemoryProviderSettingsStore({
          'openai': const StoredProviderSettings(
            baseUrl: 'https://api.openai.com/v1',
            configured: true,
          ),
        });
        final credentials = InMemoryProviderCredentialStore({
          'openai': 'sk-test',
        });
        final container = buildContainer(
          settings: settings,
          credentials: credentials,
          tester: tester,
        );
        addTearDown(container.dispose);

        final models = await container.read(
          providerModelsProvider('openai').future,
        );

        expect(models.single.id, 'gpt-4o');
        expect(tester.testedProviderIds, isEmpty);
      },
    );

    test(
      'local test reports the validated file instead of a network call',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('kritha-provider-');
        addTearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });
        final path = '${tempDir.path}/local.litertlm';
        File(path).writeAsBytesSync([1, 2, 3]);
        final container = buildContainer(modelPath: path);
        addTearDown(container.dispose);
        await container.read(providersControllerProvider.future);

        final result = await container
            .read(providersControllerProvider.notifier)
            .testConnection('local-litertlm');

        expect(result.ok, isTrue);
        expect(result.message, contains('local.litertlm'));
        expect(result.message, contains('loads only when a request is made'));
      },
    );

    test('local test reports a missing model honestly', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      await container.read(providersControllerProvider.future);

      final result = await container
          .read(providersControllerProvider.notifier)
          .testConnection('local-litertlm');

      expect(result.ok, isFalse);
      expect(result.message, contains('No local model is selected'));
    });
  });

  group('custom providers', () {
    test(
      'creates independent providers with derived and edited aliases',
      () async {
        final settings = InMemoryProviderSettingsStore();
        final credentials = InMemoryProviderCredentialStore();
        final tester = FakeProviderConnectionTester();
        final container = buildContainer(
          settings: settings,
          credentials: credentials,
          tester: tester,
        );
        addTearDown(container.dispose);
        await container.read(providersControllerProvider.future);
        final controller = container.read(providersControllerProvider.notifier);

        final first = await controller.createCustomProvider(
          baseUrl: 'https://api.example.co.uk/v1',
          alias: '',
          credential: 'key-a',
        );
        final second = await controller.createCustomProvider(
          baseUrl: 'https://example.com/v1',
          alias: 'My Work API',
          credential: 'key-b',
        );

        expect(first.alias, 'Example Api');
        expect(second.alias, 'My Work API');
        expect(first.providerId, isNot(second.providerId));
        expect(first.configured, isTrue);
        expect(settings.settings[first.providerId]!.alias, 'Example Api');
        expect(settings.settings[second.providerId]!.alias, 'My Work API');
        expect(credentials.credentials[first.providerId], 'key-a');
        expect(credentials.credentials[second.providerId], 'key-b');

        final state = container.read(providersControllerProvider).value!;
        expect(state.customConfigurations, hasLength(2));
        expect(
          state.configurationForAlias('EXAMPLE API')?.providerId,
          first.providerId,
        );

        await expectLater(
          controller.createCustomProvider(
            baseUrl: 'https://another.example.com/v1',
            alias: 'my work api',
          ),
          throwsA(isA<ProviderConfigurationException>()),
        );
        await expectLater(
          controller.createCustomProvider(
            baseUrl: 'https://another.example.com/v1',
            alias: 'openai',
          ),
          throwsA(isA<ProviderConfigurationException>()),
        );
        expect(
          settings.settings.keys.where((id) => id.startsWith('custom-')),
          hasLength(2),
        );

        final updated = await controller.updateCustomProvider(
          first.providerId,
          baseUrl: 'https://api.example.com/v1',
          alias: 'Renamed API',
        );
        expect(updated.providerId, first.providerId);
        expect(updated.alias, 'Renamed API');
        expect(settings.settings[first.providerId]!.alias, 'Renamed API');
        expect(credentials.credentials[first.providerId], 'key-a');
      },
    );

    test(
      'removing a custom credential keeps the provider configured',
      () async {
        final settings = InMemoryProviderSettingsStore();
        final credentials = InMemoryProviderCredentialStore();
        final container = buildContainer(
          settings: settings,
          credentials: credentials,
        );
        addTearDown(container.dispose);
        await container.read(providersControllerProvider.future);
        final controller = container.read(providersControllerProvider.notifier);

        final custom = await controller.createCustomProvider(
          baseUrl: 'https://api.example.com/v1',
          alias: 'my-api',
          credential: 'custom-secret',
        );
        expect(custom.hasCredential, isTrue);
        expect(custom.hasRequiredCredentials, isTrue);
        expect(custom.configured, isTrue);

        await controller.removeCredential(custom.providerId);

        final state = container.read(providersControllerProvider).value!;
        final updated = state.configurationFor(custom.providerId)!;
        expect(credentials.credentials.containsKey(custom.providerId), isFalse);
        expect(settings.settings.containsKey(custom.providerId), isTrue);
        expect(updated.hasCredential, isFalse);
        expect(updated.hasRequiredCredentials, isTrue);
        expect(updated.configured, isTrue);
      },
    );

    test('preserves the legacy custom provider configuration', () async {
      final settings = InMemoryProviderSettingsStore({
        'custom': const StoredProviderSettings(
          baseUrl: 'https://api.deepseek.com',
        ),
      });
      final credentials = InMemoryProviderCredentialStore({
        'custom': 'ds-test',
      });
      final container = buildContainer(
        settings: settings,
        credentials: credentials,
      );
      addTearDown(container.dispose);

      final state = await container.read(providersControllerProvider.future);
      final legacy = state.configurationFor('custom');

      expect(legacy, isNotNull);
      expect(legacy!.alias, 'custom');
      expect(legacy.definition.runtimeId, openAiRuntimeId);
      expect(legacy.baseUrl, 'https://api.deepseek.com');
      expect(legacy.hasCredential, isTrue);
      expect(legacy.configured, isTrue);
    });

    test('lists identical model IDs independently for each provider', () async {
      final tester = FakeProviderConnectionTester();
      final container = buildContainer(tester: tester);
      addTearDown(container.dispose);
      await container.read(providersControllerProvider.future);
      final controller = container.read(providersControllerProvider.notifier);

      final first = await controller.createCustomProvider(
        baseUrl: 'https://a.example.com/v1',
        alias: 'provider-a',
      );
      final second = await controller.createCustomProvider(
        baseUrl: 'https://b.example.com/v1',
        alias: 'provider-b',
      );
      tester.models[first.providerId] = const [
        ProviderModelInfo(id: 'shared:model', name: 'Shared'),
      ];
      tester.models[second.providerId] = const [
        ProviderModelInfo(id: 'shared:model', name: 'Shared'),
      ];

      final firstModels = await container.read(
        providerModelsProvider(first.providerId).future,
      );
      final secondModels = await container.read(
        providerModelsProvider(second.providerId).future,
      );

      expect(firstModels.single.id, 'shared:model');
      expect(secondModels.single.id, 'shared:model');
      expect(first.providerId, isNot(second.providerId));
    });
  });

  group('HTTP connection tester', () {
    test(
      'reports a reachable OpenAI-compatible endpoint and model count',
      () async {
        final adapter = _FakeHttpAdapter(
          (options) async => _jsonResponse({
            'data': [
              {'id': 'model-one'},
            ],
          }),
        );
        final tester = HttpProviderConnectionTester(_dio(adapter));

        final result = await tester.test(
          providerDefinitionFor('openai')!,
          baseUrl: 'https://api.openai.com/v1',
          credential: 'sk-test',
        );

        expect(result.ok, isTrue);
        expect(result.modelCount, 1);
        expect(result.message, contains('1 model'));
        final request = adapter.requests.single;
        expect(request.uri.toString(), 'https://api.openai.com/v1/models');
        expect(request.headers['authorization'], 'Bearer sk-test');
      },
    );

    test('provider model metadata remains capability-aware', () async {
      final adapter = _FakeHttpAdapter(
        (options) async => _jsonResponse({
          'data': [
            {'id': 'gpt-4o', 'pipeline_tag': 'text-generation'},
            {'id': 'whisper', 'task': 'automatic-speech-recognition'},
            {'id': 'image-model', 'task': 'text-to-image'},
          ],
        }),
      );
      final models = await HttpProviderConnectionTester(_dio(adapter))
          .listModels(
            providerDefinitionFor('openai')!,
            baseUrl: 'https://api.openai.com/v1',
            credential: 'sk-test',
          );

      expect(models[0].supports(ModelCapability.text), isTrue);
      expect(models[1].supports(ModelCapability.text), isFalse);
      expect(models[1].supports(ModelCapability.speechRecognition), isTrue);
      expect(models[2].supports(ModelCapability.text), isFalse);
    });

    test('sends Anthropic-specific headers', () async {
      final adapter = _FakeHttpAdapter(
        (options) async => _jsonResponse({'data': []}),
      );
      final tester = HttpProviderConnectionTester(_dio(adapter));

      final result = await tester.test(
        providerDefinitionFor('anthropic')!,
        baseUrl: 'https://api.anthropic.com/v1',
        credential: 'sk-ant',
      );

      expect(result.ok, isTrue);
      expect(adapter.requests.single.headers['x-api-key'], 'sk-ant');
      expect(
        adapter.requests.single.headers['anthropic-version'],
        '2023-06-01',
      );
    });

    test('sends the Google key as a query parameter', () async {
      final adapter = _FakeHttpAdapter(
        (options) async => _jsonResponse({'models': []}),
      );
      final tester = HttpProviderConnectionTester(_dio(adapter));

      final result = await tester.test(
        providerDefinitionFor('google')!,
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        credential: 'google-key',
      );

      expect(result.ok, isTrue);
      expect(adapter.requests.single.queryParameters['key'], 'google-key');
    });

    test('reports authentication failures without claiming success', () async {
      final adapter = _FakeHttpAdapter(
        (options) async => _jsonResponse({}, status: 401),
      );
      final tester = HttpProviderConnectionTester(_dio(adapter));

      final result = await tester.test(
        providerDefinitionFor('openai')!,
        baseUrl: 'https://api.openai.com/v1',
        credential: 'bad',
      );

      expect(result.ok, isFalse);
      expect(result.message, contains('Authentication failed'));
    });

    test('reports an unreachable endpoint', () async {
      final adapter = _FakeHttpAdapter(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      final tester = HttpProviderConnectionTester(_dio(adapter));

      final result = await tester.test(
        providerDefinitionFor('mistral')!,
        baseUrl: 'https://api.mistral.ai/v1',
        credential: 'key',
      );

      expect(result.ok, isFalse);
      expect(result.message, contains('Could not reach the endpoint'));
    });

    test('requires an endpoint for custom providers', () async {
      final tester = HttpProviderConnectionTester(
        _dio(_FakeHttpAdapter((options) async => _jsonResponse({}))),
      );

      final result = await tester.test(
        providerDefinitionFor('custom')!,
        baseUrl: '   ',
      );

      expect(result.ok, isFalse);
      expect(result.message, contains('Enter an endpoint URL'));
    });
  });
}

Dio _dio(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(validateStatus: (_) => true));
  dio.httpClientAdapter = adapter;
  return dio;
}

ResponseBody _jsonResponse(Object? data, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
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
