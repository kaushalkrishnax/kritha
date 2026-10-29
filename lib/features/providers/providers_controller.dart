import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../intelligence/model_configuration.dart';
import 'provider_alias.dart';
import 'provider_connection_tester.dart';
import 'provider_definition.dart';
import 'provider_stores.dart';

class ProviderConfigurationException implements Exception {
  const ProviderConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProviderConfiguration {
  const ProviderConfiguration({
    required this.definition,
    required this.baseUrl,
    required this.hasCredential,
    this.configured = false,
  });

  final InferenceProviderDefinition definition;
  final String baseUrl;
  final bool hasCredential;
  final bool configured;

  String get providerId => definition.id;
  String get alias => definition.displayAlias;
  String get name => definition.name;
  bool get isLocal => definition.isLocal;
  bool get isCustom => definition.isCustom;
  bool get hasRequiredCredentials =>
      !definition.requiresCredential || hasCredential;

  ProviderConfiguration copyWith({
    InferenceProviderDefinition? definition,
    String? baseUrl,
    bool? hasCredential,
    bool? configured,
  }) {
    return ProviderConfiguration(
      definition: definition ?? this.definition,
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

  ProviderConfiguration? configurationForAlias(String alias) {
    final normalized = normalizeProviderAlias(alias);
    for (final configuration in configurations.values) {
      if (normalizeProviderAlias(configuration.alias) == normalized) {
        return configuration;
      }
    }
    return null;
  }

  List<ProviderConfiguration> get customConfigurations => [
    for (final configuration in configurations.values)
      if (configuration.isCustom) configuration,
  ];

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

    for (final definition in builtInInferenceProviders) {
      final saved = stored[definition.id];
      final credential = await credentialStore.read(definition.id);
      final baseUrl = saved?.baseUrl ?? definition.defaultBaseUrl;
      final hasCredential = credential != null;
      configurations[definition.id] = ProviderConfiguration(
        definition: definition,
        baseUrl: baseUrl,
        hasCredential: hasCredential,
        configured: _isConfigured(definition, baseUrl, hasCredential),
      );
    }

    for (final entry in stored.entries) {
      if (isBuiltInProviderId(entry.key)) continue;
      final saved = entry.value;
      final alias = _storedAliasFor(entry.key, saved);
      final definition = customProviderDefinition(id: entry.key, alias: alias);
      final credential = await credentialStore.read(entry.key);
      final hasCredential = credential != null;
      configurations[entry.key] = ProviderConfiguration(
        definition: definition,
        baseUrl: saved.baseUrl,
        hasCredential: hasCredential,
        configured: _isConfigured(definition, saved.baseUrl, hasCredential),
      );
    }

    return ProvidersState(configurations: Map.unmodifiable(configurations));
  }

  Future<ProviderConfiguration> createCustomProvider({
    required String baseUrl,
    required String alias,
    String credential = '',
  }) async {
    final current = state.value;
    if (current == null) {
      throw const ProviderConfigurationException(
        'Provider settings are still loading.',
      );
    }
    final trimmedUrl = baseUrl.trim();
    _validateBaseUrl(trimmedUrl);
    final effectiveAlias = _resolveAlias(alias, trimmedUrl);
    _ensureAliasAvailable(current, effectiveAlias);
    final id = _newCustomId(current);
    final definition = customProviderDefinition(id: id, alias: effectiveAlias);
    final trimmedCredential = credential.trim();
    if (trimmedCredential.isNotEmpty) {
      await ref
          .read(providerCredentialStoreProvider)
          .write(id, trimmedCredential);
    }
    if (!ref.mounted) {
      throw const ProviderConfigurationException(
        'Provider settings are no longer available.',
      );
    }
    final configuration = ProviderConfiguration(
      definition: definition,
      baseUrl: trimmedUrl,
      hasCredential: trimmedCredential.isNotEmpty,
      configured: _isConfigured(
        definition,
        trimmedUrl,
        trimmedCredential.isNotEmpty,
      ),
    );
    final next = Map<String, ProviderConfiguration>.from(current.configurations)
      ..[id] = configuration;
    await _persist(next);
    if (!ref.mounted) return configuration;
    state = AsyncData(current.copyWith(configurations: Map.unmodifiable(next)));
    return configuration;
  }

  Future<ProviderConfiguration> updateCustomProvider(
    String providerId, {
    required String baseUrl,
    required String alias,
    String? credential,
  }) async {
    final current = state.value;
    final configuration = current?.configurationFor(providerId);
    if (current == null || configuration == null || !configuration.isCustom) {
      throw const ProviderConfigurationException('Unknown custom provider.');
    }
    final trimmedUrl = baseUrl.trim();
    _validateBaseUrl(trimmedUrl);
    final effectiveAlias = _resolveAlias(alias, trimmedUrl);
    _ensureAliasAvailable(
      current,
      effectiveAlias,
      excludingProviderId: providerId,
    );

    var hasCredential = configuration.hasCredential;
    final trimmedCredential = credential?.trim();
    if (trimmedCredential != null && trimmedCredential.isNotEmpty) {
      await ref
          .read(providerCredentialStoreProvider)
          .write(providerId, trimmedCredential);
      hasCredential = true;
    }
    if (!ref.mounted) {
      throw const ProviderConfigurationException(
        'Provider settings are no longer available.',
      );
    }

    final definition = customProviderDefinition(
      id: providerId,
      alias: effectiveAlias,
    );
    final updated = configuration.copyWith(
      definition: definition,
      baseUrl: trimmedUrl,
      hasCredential: hasCredential,
      configured: _isConfigured(definition, trimmedUrl, hasCredential),
    );
    final next = Map<String, ProviderConfiguration>.from(current.configurations)
      ..[providerId] = updated;
    await _persist(next);
    if (!ref.mounted) return updated;
    state = AsyncData(current.copyWith(configurations: Map.unmodifiable(next)));
    return updated;
  }

  Future<void> setBaseUrl(String providerId, String baseUrl) async {
    final current = state.value;
    final configuration = current?.configurationFor(providerId);
    if (current == null || configuration == null) return;
    final definition = configuration.definition;
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
    final current = state.value;
    final configuration = current?.configurationFor(providerId);
    if (current == null || configuration == null) return;
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
          latestConfiguration.definition,
          latestConfiguration.baseUrl,
          hasCredential,
        ),
      );
    state = AsyncData(latest.copyWith(configurations: Map.unmodifiable(next)));
    await _persist(next);
  }

  Future<void> removeCredential(String providerId) async {
    await ref.read(providerCredentialStoreProvider).delete(providerId);
    final current = state.value;
    final configuration = current?.configurationFor(providerId);
    if (!ref.mounted || current == null || configuration == null) return;
    final next = Map<String, ProviderConfiguration>.from(current.configurations)
      ..[providerId] = configuration.copyWith(
        hasCredential: false,
        configured: _isConfigured(
          configuration.definition,
          configuration.baseUrl,
          false,
        ),
      );
    state = AsyncData(current.copyWith(configurations: Map.unmodifiable(next)));
    await _persist(next);
  }

  Future<void> removeProvider(String providerId) async {
    final current = state.value;
    final configuration = current?.configurationFor(providerId);
    if (current == null || configuration == null) return;
    await ref.read(providerCredentialStoreProvider).delete(providerId);
    final next = Map<String, ProviderConfiguration>.from(
      current.configurations,
    );
    if (configuration.isCustom) {
      next.remove(providerId);
    } else {
      next[providerId] = ProviderConfiguration(
        definition: configuration.definition,
        baseUrl: configuration.definition.defaultBaseUrl,
        hasCredential: false,
      );
    }
    if (!configuration.isLocal) {
      await _persist(next);
    }
    if (!ref.mounted) return;
    state = AsyncData(
      current.copyWith(
        configurations: Map.unmodifiable(next),
        testResults: {...current.testResults}..remove(providerId),
      ),
    );
  }

  Future<ProviderConnectionResult> testConnection(String providerId) async {
    final current = state.value;
    final configuration = current?.configurationFor(providerId);
    if (current == null || configuration == null) {
      return const ProviderConnectionResult(
        ok: false,
        message: 'Unknown provider.',
      );
    }
    final definition = configuration.definition;
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
          alias: entry.value.isCustom ? entry.value.alias : null,
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

  String _newCustomId(ProvidersState current) {
    var id = 'custom-${DateTime.now().microsecondsSinceEpoch}';
    while (current.configurations.containsKey(id)) {
      id = '$id-1';
    }
    return id;
  }

  String _resolveAlias(String alias, String baseUrl) {
    final cleaned = cleanProviderAlias(alias);
    final effective = cleaned.isEmpty ? deriveProviderAlias(baseUrl) : cleaned;
    if (effective == null || effective.isEmpty) {
      throw const ProviderConfigurationException(
        'Enter an alias for this provider.',
      );
    }
    if (!isValidProviderAlias(effective)) {
      throw const ProviderConfigurationException(
        'Use letters, numbers, spaces and hyphens for the alias.',
      );
    }
    return effective;
  }

  void _ensureAliasAvailable(
    ProvidersState current,
    String alias, {
    String? excludingProviderId,
  }) {
    final normalized = normalizeProviderAlias(alias);
    for (final configuration in current.configurations.values) {
      if (configuration.providerId == excludingProviderId) continue;
      if (normalizeProviderAlias(configuration.alias) == normalized) {
        throw ProviderConfigurationException(
          'The alias "$alias" is already used by another provider.',
        );
      }
    }
  }
}

String _storedAliasFor(String providerId, StoredProviderSettings settings) {
  final saved = cleanProviderAlias(settings.alias ?? '');
  if (saved.isNotEmpty && isValidProviderAlias(saved)) return saved;
  // The pre-multi-provider build stored one custom provider under "custom".
  // Keeping that alias preserves its saved credential and assignments.
  if (providerId == 'custom') return 'custom';
  return deriveProviderAlias(settings.baseUrl) ??
      normalizeProviderAlias(providerId);
}

void _validateBaseUrl(String baseUrl) {
  final uri = Uri.tryParse(baseUrl);
  if (baseUrl.isEmpty ||
      uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    throw const ProviderConfigurationException(
      'Enter a full http:// or https:// endpoint URL.',
    );
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
      final state = await ref.watch(providersControllerProvider.future);
      final configuration = state.configurationFor(providerId);
      if (configuration == null ||
          configuration.isLocal ||
          !configuration.configured) {
        return const [];
      }
      final definition = configuration.definition;
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
