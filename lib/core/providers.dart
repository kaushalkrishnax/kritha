import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import '../services/runtime_probe.dart';

enum KrithaThemePreference { system, light, dark }

extension KrithaThemePreferenceX on KrithaThemePreference {
  ThemeMode get themeMode => switch (this) {
    KrithaThemePreference.system => ThemeMode.system,
    KrithaThemePreference.light => ThemeMode.light,
    KrithaThemePreference.dark => ThemeMode.dark,
  };

  String get storageValue => name;
}

class ThemePreferenceNotifier extends Notifier<KrithaThemePreference> {
  static const _key = 'kritha.theme.preference';

  @override
  KrithaThemePreference build() {
    _restore();
    return KrithaThemePreference.system;
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_key);
    final preference = KrithaThemePreference.values.where(
      (item) => item.storageValue == value,
    );
    if (ref.mounted && preference.isNotEmpty) state = preference.first;
  }

  Future<void> setPreference(KrithaThemePreference preference) async {
    state = preference;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, preference.storageValue);
  }
}

final themePreferenceProvider =
    NotifierProvider<ThemePreferenceNotifier, KrithaThemePreference>(
      ThemePreferenceNotifier.new,
    );

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
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 30),
      headers: {'accept': 'application/json'},
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
