import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../services/runtime_probe.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.open();
  ref.onDispose(database.close);
  return database;
});

/// Configured but intentionally unused: this demo never calls a backend.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.kritha.app/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'accept': 'application/json'},
    ),
  );
  dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));
  ref.onDispose(dio.close);
  return dio;
});

/// Probes every platform package once. The settings screen shows the outcome;
/// the chat header only needs to know whether the speech runtime loaded.
final runtimeStatusProvider = FutureProvider<RuntimeStatus>((ref) {
  final database = ref.watch(databaseProvider);
  final dio = ref.watch(dioProvider);
  return RuntimeProbe(database: database, dio: dio).run();
});
