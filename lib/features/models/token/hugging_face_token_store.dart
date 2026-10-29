import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage_service.dart';

abstract interface class HuggingFaceTokenStore {
  Future<String?> readToken();

  Future<void> writeToken(String token);

  Future<void> deleteToken();
}

class SecureHuggingFaceTokenStore implements HuggingFaceTokenStore {
  const SecureHuggingFaceTokenStore(this._storage);

  static const storageKey = 'kritha.huggingface.token';
  final SecureStorageService _storage;

  @override
  Future<String?> readToken() async {
    final value = await _storage.read(storageKey);
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> writeToken(String token) {
    return _storage.write(storageKey, token.trim());
  }

  @override
  Future<void> deleteToken() => _storage.delete(storageKey);
}

final huggingFaceTokenStoreProvider = Provider<HuggingFaceTokenStore>(
  (ref) => SecureHuggingFaceTokenStore(ref.watch(secureStorageServiceProvider)),
);
