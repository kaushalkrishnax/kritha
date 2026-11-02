import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/app_database.dart';
import '../../../models/model_record.dart';

abstract interface class ModelRecordStore {
  Future<void> save(ModelRecord model, List<ModelArtifactRecord> artifacts);

  Future<List<ModelRecord>> all();

  Future<ModelRecord?> find(String id);

  Future<void> delete(String id);
}

class DatabaseModelRecordStore implements ModelRecordStore {
  const DatabaseModelRecordStore(this._database);

  final AppDatabase _database;

  @override
  Future<void> save(
    ModelRecord model,
    List<ModelArtifactRecord> artifacts,
  ) async {
    await _database.saveModelRecord(model);
    for (final artifact in artifacts) {
      await _database.saveModelArtifact(artifact);
    }
  }

  @override
  Future<List<ModelRecord>> all() => _database.allModelRecords();

  @override
  Future<ModelRecord?> find(String id) => _database.modelRecordById(id);

  @override
  Future<void> delete(String id) async {
    await _database.deleteArtifactsForModel(id);
    await _database.deleteModelRecord(id);
  }
}

final modelRecordStoreProvider = Provider<ModelRecordStore>((ref) {
  return DatabaseModelRecordStore(ref.watch(databaseProvider));
});
