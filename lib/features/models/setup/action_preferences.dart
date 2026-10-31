import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/app_database.dart';

/// Keys stay stable across builds; the value encodes the user's choice.
abstract final class ActionPreferenceKeys {
  static const deleteArtifact = 'artifact.delete';
  static const deleteAllArtifacts = 'artifact.deleteAll';
  static const removeArtifactRow = 'artifact.removeRow';
  static const replaceArtifactSource = 'artifact.replace';
}

/// Persistence boundary for per-action choices such as muted confirmations.
abstract interface class ActionPreferenceStore {
  Future<bool> confirmationSuppressed(String actionKey);

  Future<void> setConfirmationSuppressed(String actionKey, bool value);
}

class DatabaseActionPreferenceStore implements ActionPreferenceStore {
  const DatabaseActionPreferenceStore(this._database);

  final AppDatabase _database;

  @override
  Future<bool> confirmationSuppressed(String actionKey) async {
    try {
      return await _database.actionPreference(actionKey) == 'true';
    } on Object {
      // A missing preference must never block the action itself.
      return false;
    }
  }

  @override
  Future<void> setConfirmationSuppressed(String actionKey, bool value) async {
    try {
      await _database.setActionPreference(actionKey, value.toString());
    } on Object {
      // Best-effort: the current action still proceeds.
    }
  }
}

final actionPreferenceStoreProvider = Provider<ActionPreferenceStore>((ref) {
  return DatabaseActionPreferenceStore(ref.watch(databaseProvider));
});
