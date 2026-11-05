import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/app_database.dart';
import '../../models/model_record.dart';
import '../intelligence/models/model_capabilities.dart';
import '../intelligence/models/task_registry.dart';
import '../intelligence/providers/provider.dart';
import 'domain/model_tags.dart';
import 'setup/model_artifact_storage.dart';

/// Single access point for unified model identity, artifacts and derived tags.
abstract interface class ModelRepository {
  Future<void> saveModel(
    ModelRecord model, {
    List<ModelArtifactRecord> artifacts = const [],
  });

  Future<List<ModelRecord>> allModels();

  Future<ModelRecord?> findById(String id);

  Future<ModelRecord?> findByProviderAndExternal(
    String providerId,
    String externalModelId,
  );

  Future<List<ModelRecord>> variantsOf(String baseModelId);

  Future<ModelRecord?> baseModelFor(String modelId);

  Future<List<ModelArtifactRecord>> ownArtifacts(String modelId);

  /// Own plus inherited base artifacts, resolved without duplicating rows.
  Future<List<ResolvedModelArtifact>> artifactsFor(String modelId);

  Future<List<ResolvedModelArtifactFile>> resolveArtifacts(
    String modelId, {
    required String documentsPath,
  });

  Future<ModelSettingsRecord?> settingsFor(String modelId);

  Future<void> saveSettings(ModelSettingsRecord settings);

  Future<ModelTags> tagsFor(String modelId, {bool artifactsReady = true});

  Future<List<AiTaskId>> supportedTasksFor(
    String modelId, {
    bool artifactsReady = true,
  });

  Future<void> deleteModel(String id);

  /// Provider configuration resolved from the providers table.
  Future<ProviderConfig?> providerConfigFor(String providerId);

  /// All models associated with a provider.
  Future<List<ModelRecord>> modelsForProvider(String providerId);
}

class DatabaseModelRepository implements ModelRepository {
  const DatabaseModelRepository(this._database, this._derivation);

  final AppDatabase _database;
  final ModelTagDerivation _derivation;

  @override
  Future<void> saveModel(
    ModelRecord model, {
    List<ModelArtifactRecord> artifacts = const [],
  }) {
    if (artifacts.isEmpty) return _database.saveModelRecord(model);
    return _database.saveModelWithArtifacts(model, artifacts);
  }

  @override
  Future<List<ModelRecord>> allModels() => _database.allModelRecords();

  @override
  Future<ModelRecord?> findById(String id) => _database.modelRecordById(id);

  @override
  Future<ModelRecord?> findByProviderAndExternal(
    String providerId,
    String externalModelId,
  ) async =>
      _database.modelRecordByProviderAndExternal(providerId, externalModelId);

  @override
  Future<List<ModelRecord>> variantsOf(String baseModelId) =>
      _database.childModelsOf(baseModelId);

  @override
  Future<ModelRecord?> baseModelFor(String modelId) =>
      _database.baseModelFor(modelId);

  @override
  Future<List<ModelArtifactRecord>> ownArtifacts(String modelId) async {
    final resolved = await _database.artifactsForModel(modelId);
    return [
      for (final artifact in resolved)
        if (!artifact.inherited) artifact.record,
    ];
  }

  @override
  Future<List<ResolvedModelArtifact>> artifactsFor(String modelId) =>
      _database.artifactsForModel(modelId);

  @override
  Future<List<ResolvedModelArtifactFile>> resolveArtifacts(
    String modelId, {
    required String documentsPath,
  }) async {
    final artifacts = await artifactsFor(modelId);
    return ModelArtifactStorageResolver(documentsPath).resolve(artifacts);
  }

  @override
  Future<ModelSettingsRecord?> settingsFor(String modelId) =>
      _database.modelSettingsFor(modelId);

  @override
  Future<void> saveSettings(ModelSettingsRecord settings) =>
      _database.saveModelInferenceSettings(settings);

  @override
  Future<ModelTags> tagsFor(
    String modelId, {
    bool artifactsReady = true,
  }) async {
    final model = await _database.modelRecordById(modelId);
    if (model == null) return const ModelTags();
    final base = model.parentModelId == null
        ? null
        : await _database.modelRecordById(model.parentModelId!);
    final merged = base == null || base.id == model.id
        ? model
        : model.copyWith(
            tasks: normaliseTaskDeclarations([...base.tasks, ...model.tasks]),
          );
    return _derivation.derive(merged, artifactsReady: artifactsReady);
  }

  @override
  Future<List<AiTaskId>> supportedTasksFor(
    String modelId, {
    bool artifactsReady = true,
  }) async {
    final tags = await tagsFor(modelId, artifactsReady: artifactsReady);
    return tags.supportedTasks;
  }

  @override
  Future<void> deleteModel(String id) => _database.deleteModelRecord(id);

  @override
  Future<ProviderConfig?> providerConfigFor(String providerId) async {
    final row = await _database.providerById(providerId);
    if (row == null) return null;
    return ProviderConfig(
      id: row.id,
      alias: row.alias,
      baseUrl: row.baseUrl,
      apiKey: row.apiKey,
    );
  }

  @override
  Future<List<ModelRecord>> modelsForProvider(String providerId) async {
    final all = await _database.allModelRecords();
    return [
      for (final model in all) if (model.providerId == providerId) model,
    ];
  }
}

final modelRepositoryProvider = Provider<ModelRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return DatabaseModelRepository(
    database,
    ModelTagDerivation(
      runtimes: {
        localLitertlmProviderId: const ModelRuntimeSignature(
          id: 'local-litertlm',
          capabilities: {InferenceCapability.textGeneration},
          platforms: {'android', 'ios', 'macos', 'windows', 'linux'},
          formats: {'litertlm'},
          available: true,
        ),
      },
      localRuntimeProviderId: localLitertlmProviderId,
      platform: currentRuntimePlatform(),
    ),
  );
});
