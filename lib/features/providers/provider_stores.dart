import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/secure_storage_service.dart';

class StoredProviderSettings {
  const StoredProviderSettings({
    required this.baseUrl,
    this.configured = true,
    this.alias,
  });

  final String baseUrl;
  final bool configured;

  /// Editable alias for user-created providers. Built-ins leave this null and
  /// use their definition's stable display name.
  final String? alias;

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'configured': configured,
    if (alias != null) 'alias': alias,
  };
}

abstract interface class ProviderSettingsStore {
  Future<Map<String, StoredProviderSettings>> read();

  Future<void> write(Map<String, StoredProviderSettings> settings);
}

class SharedPreferencesProviderSettingsStore implements ProviderSettingsStore {
  const SharedPreferencesProviderSettingsStore();

  static const preferenceKey = 'kritha.providers.settings';

  @override
  Future<Map<String, StoredProviderSettings>> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(preferenceKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final result = <String, StoredProviderSettings>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        result['${entry.key}'] = StoredProviderSettings(
          baseUrl: value['baseUrl'] is String ? value['baseUrl'] as String : '',
          configured: value['configured'] != false,
          alias: value['alias'] is String ? value['alias'] as String : null,
        );
      }
      return Map.unmodifiable(result);
    } on FormatException {
      return const {};
    }
  }

  @override
  Future<void> write(Map<String, StoredProviderSettings> settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      preferenceKey,
      jsonEncode({
        for (final entry in settings.entries) entry.key: entry.value.toJson(),
      }),
    );
  }
}

abstract interface class ProviderCredentialStore {
  Future<String?> read(String providerId);

  Future<void> write(String providerId, String credential);

  Future<void> delete(String providerId);
}

class SecureProviderCredentialStore implements ProviderCredentialStore {
  const SecureProviderCredentialStore(this._storage);

  final SecureStorageService _storage;

  static String keyFor(String providerId) =>
      'kritha.providers.$providerId.credential';

  @override
  Future<String?> read(String providerId) async {
    final value = await _storage.read(keyFor(providerId));
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> write(String providerId, String credential) {
    return _storage.write(keyFor(providerId), credential.trim());
  }

  @override
  Future<void> delete(String providerId) => _storage.delete(keyFor(providerId));
}

final providerSettingsStoreProvider = Provider<ProviderSettingsStore>(
  (ref) => const SharedPreferencesProviderSettingsStore(),
);

final providerCredentialStoreProvider = Provider<ProviderCredentialStore>(
  (ref) =>
      SecureProviderCredentialStore(ref.watch(secureStorageServiceProvider)),
);
