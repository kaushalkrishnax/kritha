import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'provider_stores.dart';

class ProviderUsageController
    extends AsyncNotifier<Map<String, ProviderUsage>> {
  Future<void> _writes = Future<void>.value();

  @override
  Future<Map<String, ProviderUsage>> build() async {
    try {
      return await ref.watch(providerUsageStoreProvider).read();
    } on Object {
      return const {};
    }
  }

  Future<void> record(String providerId, {required bool ok}) {
    final previous = _writes;
    final done = () async {
      await previous;
      try {
        await future;
      } on Object {
        // Counts recorded in memory remain usable after a storage read failure.
      }
      if (!ref.mounted) return;
      final current = state.value ?? const <String, ProviderUsage>{};
      final updated = Map<String, ProviderUsage>.from(current);
      updated[providerId] = (updated[providerId] ?? const ProviderUsage())
          .record(ok: ok);
      state = AsyncData(Map.unmodifiable(updated));
      try {
        await ref.read(providerUsageStoreProvider).write(updated);
      } on Object {
        // Usage is best-effort; storage must never break inference.
      }
    }();
    _writes = done.catchError((Object _) {});
    return done;
  }
}

final providerUsageProvider =
    AsyncNotifierProvider<ProviderUsageController, Map<String, ProviderUsage>>(
      ProviderUsageController.new,
    );
