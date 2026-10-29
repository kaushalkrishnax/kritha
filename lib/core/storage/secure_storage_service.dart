import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureStorageService {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class PlatformSecureStorageService implements SecureStorageService {
  const PlatformSecureStorageService([
    FlutterSecureStorage storage = _defaultStorage,
  ]) : _storage = storage;

  static const _defaultStorage = FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final secureStorageServiceProvider = Provider<SecureStorageService>(
  (ref) => const PlatformSecureStorageService(),
);
