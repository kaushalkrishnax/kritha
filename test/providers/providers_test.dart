import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kritha/core/providers.dart';
import 'package:kritha/data/app_database.dart';
import 'package:kritha/features/intelligence/intelligence_exception.dart';
import 'package:kritha/features/intelligence/providers/local/litertlm_provider.dart';
import 'package:kritha/features/intelligence/providers/provider.dart';
import 'package:kritha/features/intelligence/providers/provider_registry.dart';
import 'package:kritha/features/intelligence/providers/remote/oai_spec_provider.dart';
import 'package:kritha/features/intelligence/providers/remote/xai_provider.dart';
import 'package:kritha/features/models/active/active_models.dart';
import 'package:kritha/features/models/model_record_store.dart';
import 'package:kritha/models/model_record.dart';
import 'package:kritha/features/providers/provider_alias.dart';
import 'package:kritha/features/providers/providers_controller.dart';
import 'package:kritha/features/providers/provider_stores.dart';
import 'package:kritha/services/runtime_probe.dart';
import 'package:litertlm/litertlm.dart' as lite;

import '../support/fake_workspace.dart';

class _MockDatabase extends AppDatabase {
  _MockDatabase() : super(NativeDatabase.memory()) {
    final now = DateTime.now();
    _rows = [
      ProviderRow(
        id: '11111111-1111-1111-1111-111111111101',
        alias: 'local-litertlm',
        baseUrl: null,
        apiKey: null,
        createdAt: now,
        updatedAt: now,
      ),
      ProviderRow(
        id: '11111111-1111-1111-1111-111111111102',
        alias: 'google-gemini',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        apiKey: null,
        createdAt: now,
        updatedAt: now,
      ),
      ProviderRow(
        id: '11111111-1111-1111-1111-111111111103',
        alias: 'anthropic',
        baseUrl: 'https://api.anthropic.com/v1',
        apiKey: null,
        createdAt: now,
        updatedAt: now,
      ),
      ProviderRow(
        id: '11111111-1111-1111-1111-111111111104',
        alias: 'xai',
        baseUrl: 'https://api.x.ai/v1',
        apiKey: null,
        createdAt: now,
        updatedAt: now,
      ),
      ProviderRow(
        id: '11111111-1111-1111-1111-111111111105',
        alias: 'mistral',
        baseUrl: 'https://api.mistral.ai/v1',
        apiKey: null,
        createdAt: now,
        updatedAt: now,
      ),
      ProviderRow(
        id: '11111111-1111-1111-1111-111111111106',
        alias: 'openai',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: null,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  List<ProviderRow> _rows = [];

  @override
  Future<List<ProviderRow>> allProviders() async => List.unmodifiable(_rows);

  @override
  Future<ProviderRow?> providerById(String id) async {
    for (final r in _rows) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<ProviderRow?> providerByAlias(String alias) async => null;

  @override
  Future<bool> providerAliasTaken(
    String alias, {
    String? excludingProviderId,
  }) async => _rows.any((r) => r.alias == alias && r.id != excludingProviderId);

  @override
  Future<void> saveProvider(ProviderRow provider) async {
    _rows.removeWhere((r) => r.id == provider.id);
    _rows.add(provider);
  }

  @override
  Future<void> updateProviderAlias(String id, String alias) async {
    final index = _rows.indexWhere((r) => r.id == id);
    if (index >= 0) {
      _rows[index] = _rows[index].copyWith(alias: alias);
    }
  }

  @override
  Future<void> updateProviderConfig(
    String id, {
    String? baseUrl,
    String? apiKey,
  }) async {
    final index = _rows.indexWhere((r) => r.id == id);
    if (index >= 0) {
      _rows[index] = _rows[index].copyWith(
        baseUrl: baseUrl == null ? const Value.absent() : Value(baseUrl),
        apiKey: apiKey == null ? Value(null) : Value(apiKey),
      );
    }
  }

  @override
  Future<void> deleteProvider(String id) async {
    _rows.removeWhere((r) => r.id == id);
  }

  @override
  Future<List<ModelRecord>> allModelRecords() async => const [];
  @override
  Future<ModelRecord?> modelRecordById(String id) async => null;
  @override
  Future<ModelRecord?> modelRecordByProviderAndExternal(
    String providerId,
    String externalModelId,
  ) async => null;
  @override
  Future<void> deleteArtifactsForModel(String modelId) async {}
  @override
  Future<void> deleteModelRecord(String id) async {}
  @override
  Future<void> deleteModelsForProvider(String providerId) async {}
  @override
  Future<void> updateModelSuffix(String modelId, String suffix) async {}
  @override
  Future<List<ModelRecord>> childModelsOf(String parentModelId) async =>
      const [];
  @override
  Future<ModelRecord?> baseModelFor(String modelId) async => null;
  @override
  Future<List<ResolvedModelArtifact>> artifactsForModel(String modelId) async =>
      const [];
  @override
  Future<ModelSettingsRecord?> modelSettingsFor(String modelId) async => null;
  @override
  Future<void> saveModelRecord(ModelRecord model) async {}
  @override
  Future<void> saveModelWithArtifacts(
    ModelRecord model,
    List<ModelArtifactRecord> artifacts,
  ) async {}
  @override
  Future<void> saveModelArtifact(ModelArtifactRecord artifact) async {}
  @override
  Future<void> saveModelInferenceSettings(ModelSettingsRecord settings) async {}
  @override
  Future<String?> actionPreference(String actionKey) async => null;
  @override
  Future<void> setActionPreference(String actionKey, String value) async {}
}

ProviderContainer buildContainer({
  InMemoryProviderSettingsStore? settings,
  InMemoryProviderCredentialStore? credentials,
  InMemoryProviderUsageStore? usage,
  InMemoryModelRepository? modelRepository,
  InMemoryActiveModelStore? activeStore,
  RuntimeStatus? runtime,
}) {
  return ProviderContainer(
    overrides: [
      providerSettingsStoreProvider.overrideWithValue(
        settings ?? InMemoryProviderSettingsStore(),
      ),
      providerCredentialStoreProvider.overrideWithValue(
        credentials ?? InMemoryProviderCredentialStore(),
      ),
      providerUsageStoreProvider.overrideWithValue(
        usage ?? InMemoryProviderUsageStore(),
      ),
      modelRepositoryProvider.overrideWithValue(
        modelRepository ?? InMemoryModelRepository(),
      ),
      activeModelStoreProvider.overrideWithValue(
        activeStore ?? InMemoryActiveModelStore(),
      ),
      recentModelStoreProvider.overrideWithValue(InMemoryRecentModelStore()),
      runtimeStatusProvider.overrideWith(
        (ref) async => runtime ?? testRuntimeStatus(),
      ),
      databaseProvider.overrideWithValue(_MockDatabase()),
    ],
  );
}

class _FakeLiteRtLmEngine implements LiteRtLmEngine {
  _FakeLiteRtLmEngine();

  @override
  Future<void> initialize() async {}

  @override
  Future<String> complete({
    required lite.ConversationConfig conversation,
    required lite.Message message,
  }) async {
    return 'ok';
  }

  @override
  Stream<String> stream({
    required lite.ConversationConfig conversation,
    required lite.Message message,
  }) async* {
    yield 'ok';
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('provider alias derivation', () {
    test('uses title-cased domain then subdomain labels', () {
      expect(deriveProviderAlias('https://openai.com/v1'), 'Openai');
      expect(deriveProviderAlias('https://api.openai.com/v1'), 'Openai Api');
      expect(
        deriveProviderAlias('https://api.anthropic.com/v1'),
        'Anthropic Api',
      );
      expect(
        deriveProviderAlias('https://generativelanguage.googleapis.com/v1'),
        'Googleapis Generativelanguage',
      );
      expect(deriveProviderAlias('https://example.com/v1'), 'Example');
      expect(
        deriveProviderAlias('https://api.example.co.uk/v1'),
        'Example Api',
      );
      expect(
        deriveProviderAlias('https://api.example.co.jp/v1'),
        'Example Api',
      );
      expect(
        deriveProviderAlias('https://api.example.com.au/v1'),
        'Example Api',
      );
      expect(deriveProviderAlias('https://foo.github.io/v1'), 'Github Foo');
    });

    test('ignores ports, paths, queries and the www label', () {
      expect(
        deriveProviderAlias('https://www.example.com:8443/v1?region=eu'),
        'Example',
      );
    });

    test('leaves ambiguous hosts empty for manual entry', () {
      expect(deriveProviderAlias('http://localhost:8080/v1'), isNull);
      expect(deriveProviderAlias('http://127.0.0.1:8080/v1'), isNull);
      expect(deriveProviderAlias('https://api.'), isNull);
      expect(deriveProviderAlias('https://api'), isNull);
      expect(deriveProviderAlias('not a url'), isNull);
    });

    test('normalizes aliases consistently for comparison', () {
      expect(normalizeProviderAlias('  My API  '), 'my-api');
      expect(normalizeProviderAlias('API_Example'), 'api-example');
      expect(normalizeProviderAlias('---'), isEmpty);
    });

    test('preserves display aliases with spaces and capitals', () {
      expect(cleanProviderAlias('  My Work API  '), 'My Work API');
      expect(cleanProviderAlias('My   Work  API'), 'My Work API');
      expect(isValidProviderAlias('My Work API'), isTrue);
      expect(isValidProviderAlias('My-API 2'), isTrue);
      expect(isValidProviderAlias('my-api'), isTrue);
      expect(isValidProviderAlias(''), isFalse);
      expect(isValidProviderAlias('---'), isFalse);
    });
  });

  group('provider registry', () {
    test('resolves dedicated implementations', () {
      final registry = ProviderRegistry(
        factories: {
          'local-litertlm': (config) {
            return LiteRtLmLocalProvider(
              config: config,
              createEngine: (path) => _FakeLiteRtLmEngine(),
              localModels: () async => [],
            );
          },
          'xai': (config) {
            return XaiProvider(
              config: config,
              clientFactory: () => http.Client(),
            );
          },
        },
      );

      expect(registry.isRegistered('local-litertlm'), isTrue);
      expect(registry.isRegistered('xai'), isTrue);
      expect(registry.isRegistered('custom-alias'), isFalse);

      final local = registry.createProvider(
        ProviderConfig(id: 'local-id', alias: 'local-litertlm'),
      );
      expect(local.alias, 'local-litertlm');

      final xai = registry.createProvider(
        ProviderConfig(id: 'xai-id', alias: 'xai'),
      );
      expect(xai.alias, 'xai');
    });

    test('throws for unknown alias', () {
      final registry = ProviderRegistry(factories: const {});
      expect(
        () => registry.createProvider(
          ProviderConfig(id: 'unknown', alias: 'no-such-provider'),
        ),
        throwsA(isA<ProviderUnavailableException>()),
      );
    });
  });

  group('custom providers', () {
    test(
      'creates independent providers with derived and edited aliases',
      () async {
        final container = buildContainer();
        addTearDown(container.dispose);

        await container.read(providersControllerProvider.future);
        final controller = container.read(providersControllerProvider.notifier);

        final first = await controller.createCustomProvider(
          baseUrl: 'https://api.example.co.uk/v1',
          alias: '',
          apiKey: 'key-a',
        );
        final second = await controller.createCustomProvider(
          baseUrl: 'https://example.com/v1',
          alias: 'My Work API',
          apiKey: 'key-b',
        );

        expect(first.alias, 'Example Api');
        expect(second.alias, 'My Work API');
        expect(first.id, isNot(second.id));
        expect(first.hasCredential, isTrue);
        expect(second.hasCredential, isTrue);

        final state = container.read(providersControllerProvider).value!;
        expect(state.customProviders, hasLength(2));
        expect(state.configurationForAlias('EXAMPLE API')?.id, first.id);

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
            alias: 'local-litertlm',
          ),
          throwsA(isA<ProviderConfigurationException>()),
        );

        final updated = await controller.updateCustomProvider(
          first.id,
          baseUrl: 'https://api.example.com/v1',
          alias: 'Renamed API',
        );
        expect(updated.id, first.id);
        expect(updated.alias, 'Renamed API');
      },
    );

    test('loads edits and clears API key', () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      await container.read(providersControllerProvider.future);
      final controller = container.read(providersControllerProvider.notifier);

      final custom = await controller.createCustomProvider(
        baseUrl: 'https://api.example.com/v1',
        alias: 'my-api',
        apiKey: 'custom-secret',
      );
      expect(custom.hasCredential, isTrue);

      await controller.saveCredential(custom.id, 'new-secret');
      final state = container.read(providersControllerProvider).value!;
      expect(state.configurationFor(custom.id)!.apiKey, 'new-secret');

      await controller.saveCredential(custom.id, '');
      final cleared = container
          .read(providersControllerProvider)
          .value!
          .configurationFor(custom.id)!;
      expect(cleared.apiKey, isNull);
      expect(cleared.hasCredential, isFalse);
    });

    test('alias uniqueness validation excludes current provider', () async {
      final container = buildContainer();
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
      expect(second.id, isNot(equals(first.id)));

      // Renaming first to second's alias should fail.
      await expectLater(
        controller.updateCustomProvider(
          first.id,
          baseUrl: 'https://a.example.com/v1',
          alias: 'provider-b',
        ),
        throwsA(isA<ProviderConfigurationException>()),
      );

      // Renaming first to its own alias should succeed.
      await controller.updateCustomProvider(
        first.id,
        baseUrl: 'https://a.example.com/v1',
        alias: 'provider-a',
      );
    });
  });

  group('custom providers use OpenAI spec implementation', () {
    test('registry falls back to OaiSpecProvider for custom alias', () {
      final registry = ProviderRegistry(
        factories: const {},
        fallback: (config) =>
            OaiSpecProvider(config: config, clientFactory: () => http.Client()),
      );

      expect(registry.isRegistered('my-custom'), isFalse);
      final provider = registry.createProvider(
        ProviderConfig(
          id: 'custom-1',
          alias: 'my-custom',
          baseUrl: 'https://api.example.com/v1',
          apiKey: 'sk-test',
        ),
      );
      expect(provider, isA<OaiSpecProvider>());
      expect(provider.config.baseUrl, 'https://api.example.com/v1');
      expect(provider.config.apiKey, 'sk-test');
    });
  });

  group('default provider protection', () {
    test('deleteProvider throws for a seeded default provider', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      await container.read(providersControllerProvider.future);

      await expectLater(
        container
            .read(providersControllerProvider.notifier)
            .deleteProvider('11111111-1111-1111-1111-111111111101'),
        throwsA(isA<ProviderConfigurationException>()),
      );
    });
  });

  group('provider listing groups', () {
    test(
      'custom providers are separate and seeded providers split by setup',
      () async {
        final container = buildContainer();
        addTearDown(container.dispose);
        await container.read(providersControllerProvider.future);

        final controller = container.read(providersControllerProvider.notifier);
        final custom = await controller.createCustomProvider(
          baseUrl: 'https://api.example.com/v1',
          alias: 'my-custom',
        );
        await controller.saveCredential(
          '11111111-1111-1111-1111-111111111102',
          'key',
        );

        final state = container.read(providersControllerProvider).value!;
        expect(state.customProviders.map((c) => c.id), [custom.id]);
        expect(
          state.configuredDefaultProviders.map((c) => c.id),
          containsAll([
            '11111111-1111-1111-1111-111111111101',
            '11111111-1111-1111-1111-111111111102',
          ]),
        );
        expect(
          state.unconfiguredDefaultProviders.map((c) => c.id),
          isNot(contains('11111111-1111-1111-1111-111111111102')),
        );
        final groupedDefaults = {
          ...state.configuredDefaultProviders.map((c) => c.id),
          ...state.unconfiguredDefaultProviders.map((c) => c.id),
        };
        expect(
          groupedDefaults,
          state.defaultProviders.map((c) => c.id).toSet(),
        );
        expect(
          state.customProviders.map((c) => c.alias),
          isNot(contains('local-litertlm')),
        );
      },
    );
  });

  group('custom provider deletion cleanup', () {
    test('deleting a custom provider removes it from state', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      await container.read(providersControllerProvider.future);

      final provider = await container
          .read(providersControllerProvider.notifier)
          .createCustomProvider(
            baseUrl: 'https://api.test.com/v1',
            alias: 'test-provider',
          );

      final state = container.read(providersControllerProvider).value!;
      expect(state.customProviders.map((c) => c.id), contains(provider.id));

      await container
          .read(providersControllerProvider.notifier)
          .deleteProvider(provider.id);

      final after = container.read(providersControllerProvider).value!;
      expect(
        after.customProviders.map((c) => c.id),
        isNot(contains(provider.id)),
      );
    });
  });
}
