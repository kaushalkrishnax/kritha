import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/app_database.dart';
import '../../../models/model_configuration_record.dart';

/// Persistence boundary for saved model configurations.
///
/// Pre-check results never cross this boundary. A future Configured Models
/// screen reads the same records through [ConfiguredModelStore.all].
abstract interface class ConfiguredModelStore {
  Future<void> save(ConfiguredModel model);

  Future<List<ConfiguredModel>> all();

  Future<ConfiguredModel?> find(String id);

  Future<void> delete(String id);
}

class DatabaseConfiguredModelStore implements ConfiguredModelStore {
  const DatabaseConfiguredModelStore(this._database);

  final AppDatabase _database;

  @override
  Future<void> save(ConfiguredModel model) =>
      _database.saveModelConfiguration(model);

  @override
  Future<List<ConfiguredModel>> all() => _database.configuredModels();

  @override
  Future<ConfiguredModel?> find(String id) => _database.configuredModelById(id);

  @override
  Future<void> delete(String id) => _database.deleteModelConfiguration(id);
}

final configuredModelStoreProvider = Provider<ConfiguredModelStore>((ref) {
  return DatabaseConfiguredModelStore(ref.watch(databaseProvider));
});
