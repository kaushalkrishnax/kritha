import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../intelligence/model_configuration.dart';
import 'provider_connection_tester.dart';
import 'provider_definition.dart';
import 'provider_stores.dart';

class ProviderConfiguration {
  const ProviderConfiguration({
    required this.providerId,
    required this.baseUrl,
    required this.hasCredential,
    this.configured = false,
  });

  final String providerId;
  final String baseUrl;
  final bool hasCredential;
  final bool configured;

  ProviderConfiguration copyWith({
    String? baseUrl,
    bool? hasCredential,
    bool? configured,
  }) {
    return ProviderConfiguration(
      providerId: providerId,
      baseUrl: baseUrl ?? this.baseUrl,
      hasCredential: hasCredential ?? this.hasCredential,
      configured: configured ?? this.configured,
    );
  }
}

class ProvidersState {
  const ProvidersState({
    required this.configurations,
    this.testResults = const {},
    this.testing = const {},
  });

  final Map<String, ProviderConfiguration> configurations;
  final Map<String, ProviderConnectionResult> testResults;
  final Set<String> testing;

  ProviderConfiguration? configurationFor(String providerId) =>
      configurations[providerId];

  ProvidersState copyWith({
    Map<String, ProviderConfiguration>? configurations,
    Map<String, ProviderConnectionResult>? testResults,
    Set<String>? testing,
  }) {
    return ProvidersState(
      configurations: configurations ?? this.configurations,
      testResults: testResults ?? this.testResults,
      testing: testing ?? this.testing,
    );
  }
}

class ProvidersController extends AsyncNotifier<ProvidersState> {
  Future<void> _writes = Future<void>.value();
  final Map<String, int> _testRevisions = {};

  @override
  Future<ProvidersState> build() async {
    final settingsStore = ref.watch(providerSettingsStoreProvider);
    final credentialStore = ref.watch(providerCredentialStoreProvider);
    await _writes;
    final stored = await settingsStore.read();
    final configurations = <String, ProviderConfiguration>{};
    for (final definition in supportedInferenceProviders) {
      final saved = stored[definition.id];
      final credential = await credentialStore.read(definition.id);
      final baseUrl = saved?.baseUrl ?? definition.defaultBaseUrl;
      final hasCredential = credential != null;
      configurations[definition.id] = ProviderConfiguration(
        providerId: definition.id,
        baseUrl: baseUrl,
        hasCredential: hasCredential,
        configured:
            (saved?.configured == true || definition.isLocal) &&
            _isConfigured(definition, baseUrl, hasCredential),
      );
    }
    return ProvidersState(configurations: Map.unmodifiable(configurations));
  }

  Future<void> setBaseUrl(String providerId, String baseUrl) async {
    final definition = providerDefinitionFor(providerId);
    final current = state.value;
    final configuration = current?.configurationFor(providerId);
    if (definition == null || current == null || configuration == null) return;
    final trimmed = baseUrl.trim();
    final next = Map<String, ProviderConfiguration>.from(current.configurations)
      ..[providerId] = configuration.copyWith(
        baseUrl: trimmed,
        configured: _isConfigured(
          definition,
          trimmed,
          configuration.hasCredential,
        ),
      );
    state = AsyncData(current.copyWith(configurations: Map.unmodifiable(next)));
    await _persist(next);
  }

  Future<void> saveCredential(String providerId, String credential) async {
    final definition = providerDefinitionFor(providerId);
    final current = state.value;
    final configuration = current?.configurationFor(providerId);
    if (definition == null || current == null || configuration == null) return;
    final store = ref.read(providerCredentialStoreProvider);
    final trimmed = credential.trim();
    if (trimmed.isEmpty) {
      await store.delete(providerId);
    } else {
      await store.write(providerId, trimmed);
    }
    if (!ref.mounted) return;
    final latest = state.value ?? current;
    final latestConfiguration = latest.configurationFor(providerId);
    if (latestConfiguration == null) return;
    final hasCredential = trimmed.isNotEmpty;
    final next = Map<String, ProviderConfiguration>.from(latest.configurations)
      ..[providerId] = latestConfiguration.copyWith(
        hasCredential: hasCredential,
        configured: _isConfigured(
          definition,
          latestConfiguration.baseUrl,
          hasCredential,
        ),
      );
    state = AsyncData(latest.copyWith(configurations: Map.unmodifiable(next)));
    await _persist(next);
  }

  Future<void> removeCredential(String providerId) async {
    final definition = providerDefinitionFor(providerId);
    await ref.read(providerCredentialStoreProvider).delete(providerId);
    final current = state.value;
    final configuration = current?.configurationFor(providerId);
    if (!ref.mounted || definition == null || current == null) return;
    if (configuration == null) return;
    final next = Map<String, ProviderConfiguration>.from(current.configurations)
      ..[providerId] = configuration.copyWith(
        hasCredential: false,
        configured: _isConfigured(definition, configuration.baseUrl, false),
      );
    state = AsyncData(current.copyWith(configurations: Map.unmodifiable(next)));
    await _persist(next);
  }

  Future<void> removeProvider(String providerId) async {
    final definition = providerDefinitionFor(providerId);
    final current = state.value;
    final configuration = current?.configurationFor(providerId);
    if (definition == null || current == null || configuration == null) return;
    await ref.read(providerCredentialStoreProvider).delete(providerId);
    final next = Map<String, ProviderConfiguration>.from(current.configurations)
      ..[providerId] = ProviderConfiguration(
        providerId: providerId,
        baseUrl: definition.defaultBaseUrl,
        hasCredential: false,
      );
    if (!definition.isLocal) {
      await _persist(next);
    }
    if (!ref.mounted) return;
    state = AsyncData(current.copyWith(configurations: Map.unmodifiable(next)));
  }

  Future<ProviderConnectionResult> testConnection(String providerId) async {
    final definition = providerDefinitionFor(providerId);
    final current = state.value;
    final configuration = current?.configurationFor(providerId);
    if (definition == null || current == null || configuration == null) {
      return const ProviderConnectionResult(
        ok: false,
        message: 'Unknown provider.',
      );
    }
    final revision = (_testRevisions[providerId] ?? 0) + 1;
    _testRevisions[providerId] = revision;
    state = AsyncData(
      current.copyWith(testing: {...current.testing, providerId}),
    );

    ProviderConnectionResult result;
    try {
      if (definition.isLocal) {
        final configurationState = await ref.read(
          modelConfigurationProvider.future,
        );
        final model = configurationState.descriptor;
        if (model == null) {
          result = ProviderConnectionResult(
            ok: false,
            message:
                configurationState.message ??
                'No validated local model file is selected.',
          );
        } else {
          result = ProviderConnectionResult(
            ok: true,
            message:
                'Local file present: ${configurationState.fileName ?? model.displayName}. '
                'The native engine loads only when a request is made.',
          );
        }
      } else {
        final credential = await ref
            .read(providerCredentialStoreProvider)
            .read(providerId);
        if (definition.requiresCredential &&
            (credential == null || credential.isEmpty)) {
          result = ProviderConnectionResult(
            ok: false,
            message:
                'Save a ${definition.credentialLabel.toLowerCase()} before testing.',
          );
        } else {
          result = await ref
              .read(providerConnectionTesterProvider)
              .test(
                definition,
                baseUrl: configuration.baseUrl,
                credential: credential,
              );
        }
      }
    } on Object {
      result = const ProviderConnectionResult(
        ok: false,
        message: 'The connection test could not be completed.',
      );
    }

    if (!ref.mounted) return result;
    final latest = state.value;
    if (latest == null) return result;
    if (_testRevisions[providerId] != revision) return result;
    state = AsyncData(
      latest.copyWith(
        testing: {...latest.testing}..remove(providerId),
        testResults: {...latest.testResults, providerId: result},
      ),
    );
    return result;
  }

  Future<void> _persist(Map<String, ProviderConfiguration> configurations) {
    final stored = {
      for (final entry in configurations.entries)
        entry.key: StoredProviderSettings(
          baseUrl: entry.value.baseUrl,
          configured: entry.value.configured,
        ),
    };
    final previous = _writes;
    final done = () async {
      await previous;
      await ref.read(providerSettingsStoreProvider).write(stored);
    }();
    _writes = done.catchError((Object _) {});
    return done;
  }
}

bool _isConfigured(
  InferenceProviderDefinition definition,
  String baseUrl,
  bool hasCredential,
) {
  if (definition.isLocal) return true;
  final uri = Uri.tryParse(baseUrl.trim());
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    return false;
  }
  if (definition.requiresCredential && !hasCredential) return false;
  return true;
}

final providersControllerProvider =
    AsyncNotifierProvider<ProvidersController, ProvidersState>(
      ProvidersController.new,
    );

final providerModelsProvider =
    FutureProvider.family<List<ProviderModelInfo>, String>((
      ref,
      providerId,
    ) async {
      final definition = providerDefinitionFor(providerId);
      final state = await ref.watch(providersControllerProvider.future);
      final configuration = state.configurationFor(providerId);
      if (definition == null ||
          definition.isLocal ||
          configuration == null ||
          !configuration.configured) {
        return const [];
      }
      final credential = await ref
          .watch(providerCredentialStoreProvider)
          .read(providerId);
      if (definition.requiresCredential && credential == null) {
        throw StateError('Add provider credentials to list its models.');
      }
      return ref
          .watch(providerConnectionTesterProvider)
          .listModels(
            definition,
            baseUrl: configuration.baseUrl,
            credential: credential,
          );
    });
