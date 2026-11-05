import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../data/app_database.dart';
import '../models/active/active_models.dart';
import 'provider_alias.dart';

class ProviderConfigurationException implements Exception {
  const ProviderConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProviderConfiguration {
  const ProviderConfiguration({
    required this.id,
    required this.alias,
    this.baseUrl,
    this.apiKey,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String alias;
  final String? baseUrl;
  final String? apiKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLocal => baseUrl == null;

  bool get hasCredential => apiKey != null && apiKey!.isNotEmpty;

  ProviderConfiguration copyWith({
    String? alias,
    String? baseUrl,
    String? apiKey,
    DateTime? updatedAt,
  }) {
    return ProviderConfiguration(
      id: id,
      alias: alias ?? this.alias,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProvidersState {
  const ProvidersState({required this.configurations});

  final List<ProviderConfiguration> configurations;

  ProviderConfiguration? configurationFor(String id) {
    try {
      return configurations.firstWhere((c) => c.id == id);
    } on StateError {
      return null;
    }
  }

  ProviderConfiguration? configurationForAlias(String alias) {
    final normalized = normalizeProviderAlias(alias);
    try {
      return configurations.firstWhere(
        (c) => normalizeProviderAlias(c.alias) == normalized,
      );
    } on StateError {
      return null;
    }
  }

  List<ProviderConfiguration> get defaultProviders => [
    for (final configuration in configurations)
      if (defaultProviderIds.contains(configuration.id)) configuration,
  ];

  List<ProviderConfiguration> get customProviders => [
    for (final configuration in configurations)
      if (!defaultProviderIds.contains(configuration.id)) configuration,
  ];

  ProvidersState copyWith({
    List<ProviderConfiguration>? configurations,
  }) {
    return ProvidersState(
      configurations: configurations ?? this.configurations,
    );
  }
}

/// Manages providers persisted in the unified providers table.
class ProvidersController extends AsyncNotifier<ProvidersState> {
  final Future<void> _writes = Future<void>.value();

  @override
  Future<ProvidersState> build() async {
    await _writes;
    final database = ref.read(databaseProvider);
    final rows = await database.allProviders();
    return ProvidersState(
      configurations: [
        for (final row in rows)
          ProviderConfiguration(
            id: row.id,
            alias: row.alias,
            baseUrl: row.baseUrl,
            apiKey: row.apiKey,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          ),
      ],
    );
  }

  Future<ProviderConfiguration> createCustomProvider({
    required String baseUrl,
    required String alias,
    String apiKey = '',
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
    await _ensureAliasAvailable(current, effectiveAlias);
    final id = const Uuid().v4();
    final now = DateTime.now();
    final database = ref.read(databaseProvider);
    await database.saveProvider(
      ProviderRow(
        id: id,
        alias: effectiveAlias,
        baseUrl: trimmedUrl,
        apiKey: apiKey.trim().isEmpty ? null : apiKey.trim(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (!ref.mounted) {
      throw const ProviderConfigurationException(
        'Provider settings are no longer available.',
      );
    }
    final configuration = ProviderConfiguration(
      id: id,
      alias: effectiveAlias,
      baseUrl: trimmedUrl,
      apiKey: apiKey.trim().isEmpty ? null : apiKey.trim(),
      createdAt: now,
      updatedAt: now,
    );
    final next = [...current.configurations, configuration];
    state = AsyncData(current.copyWith(configurations: next));
    return configuration;
  }

  Future<ProviderConfiguration> updateCustomProvider(
    String providerId, {
    required String baseUrl,
    required String alias,
    String? apiKey,
  }) async {
    final current = state.value;
    final configuration = current?.configurationFor(providerId);
    if (current == null || configuration == null) {
      throw const ProviderConfigurationException('Unknown provider.');
    }
    final trimmedUrl = baseUrl.trim();
    _validateBaseUrl(trimmedUrl);
    final effectiveAlias = _resolveAlias(alias, trimmedUrl);
    await _ensureAliasAvailable(
      current,
      effectiveAlias,
      excludingProviderId: providerId,
    );
    final database = ref.read(databaseProvider);
    final effectiveApiKey = apiKey == null
        ? configuration.apiKey
        : (apiKey.trim().isEmpty ? null : apiKey.trim());
    await database.updateProviderConfig(
      providerId,
      baseUrl: trimmedUrl,
      apiKey: effectiveApiKey,
    );
    if (!ref.mounted) {
      throw const ProviderConfigurationException(
        'Provider settings are no longer available.',
      );
    }
    final next = [
      for (final c in current.configurations)
        if (c.id == providerId)
          ProviderConfiguration(
            id: c.id,
            alias: effectiveAlias,
            baseUrl: trimmedUrl,
            apiKey: effectiveApiKey,
            createdAt: c.createdAt,
            updatedAt: DateTime.now(),
          )
        else
          c,
    ];
    state = AsyncData(current.copyWith(configurations: next));
    return configuration.copyWith(
      alias: effectiveAlias,
      baseUrl: trimmedUrl,
      apiKey: effectiveApiKey,
    );
  }

  Future<void> saveCredential(String providerId, String apiKey) async {
    final current = state.value;
    final configuration = current?.configurationFor(providerId);
    if (current == null || configuration == null) return;
    final trimmed = apiKey.trim();
    final database = ref.read(databaseProvider);
    await database.updateProviderConfig(
      providerId,
      apiKey: trimmed,
    );
    if (!ref.mounted) return;
    final latest = state.value ?? current;
    final latestConfiguration = latest.configurationFor(providerId);
    if (latestConfiguration == null) return;
    final next = [
      for (final c in latest.configurations)
        if (c.id == providerId)
          ProviderConfiguration(
            id: c.id,
            alias: c.alias,
            baseUrl: c.baseUrl,
            apiKey: trimmed.isEmpty ? null : trimmed,
            createdAt: c.createdAt,
            updatedAt: DateTime.now(),
          )
        else
          c,
    ];
    state = AsyncData(latest.copyWith(configurations: next));
  }

  Future<void> deleteProvider(String providerId) async {
    final current = state.value;
    final configuration = current?.configurationFor(providerId);
    if (current == null || configuration == null) return;
    if (defaultProviderIds.contains(providerId)) {
      throw const ProviderConfigurationException(
        'Default providers cannot be deleted.',
      );
    }
    final database = ref.read(databaseProvider);

    final deletedModels = await database.allModelRecords();
    final deletedIds = {
      for (final m in deletedModels)
        if (m.providerId == providerId) m.id,
    };

    await database.deleteModelsForProvider(providerId);
    await database.deleteProvider(providerId);

    if (deletedIds.isNotEmpty) {
      const store = SharedPreferencesActiveModelStore();
      final config = await store.read();
      final pruned = config.withoutModels(deletedIds);
      await store.write(pruned);
    }

    if (!ref.mounted) return;
    final next = [
      for (final c in current.configurations)
        if (c.id != providerId) c,
    ];
    state = AsyncData(current.copyWith(configurations: next));
  }

  /// Returns an error message if [alias] is already taken, null otherwise.
  Future<String?> aliasConflict(
    String alias, {
    String? excludingProviderId,
  }) async {
    final trimmed = alias.trim();
    if (trimmed.isEmpty) return null;
    final database = ref.read(databaseProvider);
    final normalized = normalizeProviderAlias(trimmed);
    final taken = await database.providerAliasTaken(
      normalized,
      excludingProviderId: excludingProviderId,
    );
    return taken ? 'Provider alias is already taken' : null;
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

  Future<void> _ensureAliasAvailable(
    ProvidersState current,
    String alias, {
    String? excludingProviderId,
  }) async {
    final normalized = normalizeProviderAlias(alias);
    for (final configuration in current.configurations) {
      if (configuration.id == excludingProviderId) continue;
      if (normalizeProviderAlias(configuration.alias) == normalized) {
        throw ProviderConfigurationException(
          'The alias "$alias" is already used by another provider.',
        );
      }
    }
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
}

final providersControllerProvider =
    AsyncNotifierProvider<ProvidersController, ProvidersState>(
      ProvidersController.new,
    );
