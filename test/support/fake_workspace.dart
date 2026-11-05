import 'package:dio/dio.dart';
import 'package:kritha/core/storage/secure_storage_service.dart';
import 'package:kritha/features/intelligence/models/model_capabilities.dart';
import 'package:kritha/features/intelligence/models/task_registry.dart';
import 'package:kritha/features/models/active/active_models.dart';
import 'package:kritha/features/models/catalogue/catalogue_failure.dart';
import 'package:kritha/features/models/catalogue/catalogue_filter.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';
import 'package:kritha/features/models/catalogue/model_catalogue_repository.dart';
import 'package:kritha/features/models/domain/model_tags.dart';
import 'package:kritha/features/models/model_record_store.dart';
import 'package:kritha/features/models/setup/model_artifact_storage.dart';
import 'package:kritha/features/models/token/hugging_face_token_store.dart';
import 'package:kritha/models/model_record.dart';
import 'package:kritha/features/intelligence/providers/provider.dart';
import 'package:kritha/features/providers/provider_stores.dart';
import 'package:kritha/services/runtime_probe.dart';

class InMemorySecureStorageService implements SecureStorageService {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class InMemoryHuggingFaceTokenStore implements HuggingFaceTokenStore {
  InMemoryHuggingFaceTokenStore([this.token]);

  String? token;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async {
    token = value.trim();
  }

  @override
  Future<void> deleteToken() async {
    token = null;
  }
}

class CatalogueSearchCall {
  const CatalogueSearchCall({
    this.query,
    this.capability,
    this.sort = CatalogueSort.downloads,
    this.limit = 24,
    this.cursor,
    this.filters = CatalogueFilterPresets.defaults,
  });

  final String? query;
  final ModelCapability? capability;
  final CatalogueSort sort;
  final int limit;
  final String? cursor;
  final List<CatalogueFilter> filters;
}

class FakeModelCatalogue implements ModelCatalogue {
  FakeModelCatalogue({
    this.pages = const {null: ModelPage(models: [])},
    this.detailsById = const {},
    this.account = const HubAccount(name: 'tester'),
    this.searchFailure,
    this.detailsFailure,
    this.tokenFailure,
  });

  final Map<String?, ModelPage> pages;
  final Map<String, ModelDetails> detailsById;
  final HubAccount account;
  final CatalogueFailure? searchFailure;
  final CatalogueFailure? detailsFailure;
  final CatalogueFailure? tokenFailure;
  final List<CatalogueSearchCall> calls = [];

  @override
  Future<ModelPage> search({
    String? query,
    ModelCapability? capability,
    CatalogueSort sort = CatalogueSort.downloads,
    int limit = 24,
    String? cursor,
    List<CatalogueFilter> filters = CatalogueFilterPresets.defaults,
    CancelToken? cancelToken,
  }) async {
    calls.add(
      CatalogueSearchCall(
        query: query,
        capability: capability,
        sort: sort,
        limit: limit,
        cursor: cursor,
        filters: filters,
      ),
    );
    if (searchFailure != null) throw searchFailure!;
    return pages[cursor] ?? const ModelPage(models: []);
  }

  @override
  Future<ModelDetails> details(String id, {CancelToken? cancelToken}) async {
    if (detailsFailure != null) throw detailsFailure!;
    final details = detailsById[id];
    if (details == null) {
      throw const CatalogueFailure(
        kind: CatalogueFailureKind.notFound,
        message: 'Repository not found.',
        statusCode: 404,
      );
    }
    return details;
  }

  @override
  Future<HubAccount> validateToken(String token) async {
    if (tokenFailure != null) throw tokenFailure!;
    return account;
  }
}

class InMemoryActiveModelStore implements ActiveModelStore {
  InMemoryActiveModelStore([ActiveModelConfig? config])
    : config = config ?? const ActiveModelConfig();

  ActiveModelConfig config;

  Map<ModelCapability, String> get singleModels => config.singleModels;

  @override
  Future<ActiveModelConfig> read() async => config;

  @override
  Future<void> write(ActiveModelConfig value) async {
    config = value;
  }
}

class InMemoryRecentModelStore implements RecentModelStore {
  InMemoryRecentModelStore([List<RecentModelRef>? refs]) : models = refs ?? [];

  List<RecentModelRef> models;

  @override
  Future<List<RecentModelRef>> read() async => List.unmodifiable(models);

  @override
  Future<void> write(List<RecentModelRef> value) async {
    models = List.of(value);
  }
}

RuntimeStatus testRuntimeStatus({String documentsPath = '/tmp/kritha'}) {
  return RuntimeStatus(
    liteRtLmReady: true,
    sherpaVersion: '',
    onnxRuntimeVersion: '',
    sqliteVersion: '',
    secureStorageReady: true,
    preferencesReady: true,
    microphone: 'granted',
    recorderReady: false,
    audioPlayerReady: false,
    dioBaseUrl: '',
    documentsPath: documentsPath,
  );
}

ModelRecord testModelRecord({
  required String providerId,
  required String externalModelId,
  String? displayName,
  List<AiTaskId> tasks = const [AiTaskId.textGeneration],
}) {
  final now = DateTime(2026);
  return ModelRecord(
    id: modelRecordId(providerId, externalModelId),
    providerId: providerId,
    externalModelId: externalModelId,
    displayName: displayName ?? externalModelId,
    tasks: [
      for (final task in tasks)
        TaskDeclaration(
          task: task,
          confidence: TaskMetadataConfidence.explicit,
          source: TaskMetadataSource.provider,
        ),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

ResolvedModelArtifactFile testArtifactFile({
  required String modelId,
  required String path,
  String kind = 'weights',
  bool exists = true,
}) {
  final now = DateTime(2026);
  return ResolvedModelArtifactFile(
    resolved: ResolvedModelArtifact(
      record: ModelArtifactRecord(
        id: '$modelId:$kind',
        modelId: modelId,
        externalPath: path,
        kind: kind,
        targetPath: path,
        createdAt: now,
        updatedAt: now,
      ),
      ownerModelId: modelId,
      inherited: false,
    ),
    absolutePath: path,
    exists: exists,
  );
}

/// Repository fake with deterministic tag derivation for widget and routing tests.
class InMemoryModelRepository implements ModelRepository {
  InMemoryModelRepository({
    Iterable<ModelRecord> models = const [],
    Map<String, List<ModelArtifactRecord>> artifacts = const {},
    Map<String, List<ResolvedModelArtifactFile>> artifactFiles = const {},
    Map<String, ModelTags> tagsById = const {},
    ModelTagDerivation? derivation,
    this.settings,
  }) : _models = {for (final model in models) model.id: model},
       _artifacts = {
         for (final entry in artifacts.entries) entry.key: [...entry.value],
       },
       _artifactFiles = {
         for (final entry in artifactFiles.entries) entry.key: [...entry.value],
       },
       _tagsById = Map.of(tagsById),
       _derivation =
           derivation ??
           ModelTagDerivation(
             runtimes: {
               for (final model in models)
                 model.providerId: ModelRuntimeSignature(
                   id: model.providerId,
                   capabilities: const {
                     InferenceCapability.textGeneration,
                     InferenceCapability.imageInput,
                     InferenceCapability.audioInput,
                   },
                 ),
             },
           );

  final Map<String, ModelRecord> _models;
  final Map<String, List<ModelArtifactRecord>> _artifacts;
  final Map<String, List<ResolvedModelArtifactFile>> _artifactFiles;
  final Map<String, ModelTags> _tagsById;
  final ModelTagDerivation _derivation;
  ModelSettingsRecord? settings;

  Map<String, ModelRecord> get models => Map.unmodifiable(_models);

  @override
  Future<void> saveModel(
    ModelRecord model, {
    List<ModelArtifactRecord> artifacts = const [],
  }) async {
    _models[model.id] = model;
    if (artifacts.isNotEmpty) {
      _artifacts[model.id] = [...artifacts];
    }
  }

  @override
  Future<List<ModelRecord>> allModels() async => List.unmodifiable(
    _models.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName)),
  );

  @override
  Future<ModelRecord?> findById(String id) async => _models[id];

  @override
  Future<ModelRecord?> findByProviderAndExternal(
    String providerId,
    String externalModelId,
  ) async {
    for (final model in _models.values) {
      if (model.providerId == providerId &&
          model.externalModelId == externalModelId) {
        return model;
      }
    }
    return null;
  }

  @override
  Future<List<ModelRecord>> variantsOf(String baseModelId) async => [
    for (final model in _models.values)
      if (model.parentModelId == baseModelId) model,
  ];

  @override
  Future<ModelRecord?> baseModelFor(String modelId) async {
    final model = _models[modelId];
    if (model == null) return null;
    return model.parentModelId == null ? model : _models[model.parentModelId];
  }

  @override
  Future<List<ModelArtifactRecord>> ownArtifacts(String modelId) async =>
      List.unmodifiable(_artifacts[modelId] ?? const []);

  @override
  Future<List<ResolvedModelArtifact>> artifactsFor(String modelId) async {
    final model = _models[modelId];
    if (model == null) return const [];
    final own = [
      for (final artifact
          in _artifacts[modelId] ?? const <ModelArtifactRecord>[])
        ResolvedModelArtifact(
          record: artifact,
          ownerModelId: modelId,
          inherited: false,
          ownerSuffix: model.suffix,
        ),
    ];
    final parentId = model.parentModelId;
    if (parentId == null) return List.unmodifiable(own);
    final parent = _models[parentId];
    return List.unmodifiable([
      for (final artifact
          in _artifacts[parentId] ?? const <ModelArtifactRecord>[])
        ResolvedModelArtifact(
          record: artifact,
          ownerModelId: parentId,
          inherited: true,
          ownerSuffix: parent?.suffix,
        ),
      ...own,
    ]);
  }

  @override
  Future<List<ResolvedModelArtifactFile>> resolveArtifacts(
    String modelId, {
    required String documentsPath,
  }) async {
    final explicit = _artifactFiles[modelId];
    if (explicit != null) return List.unmodifiable(explicit);
    return [
      for (final resolved in await artifactsFor(modelId))
        if (resolved.record.targetPath != null)
          ResolvedModelArtifactFile(
            resolved: resolved,
            absolutePath: [documentsPath, resolved.record.targetPath].join('/'),
            exists: true,
          ),
    ];
  }

  @override
  Future<ModelSettingsRecord?> settingsFor(String modelId) async =>
      settings?.modelId == modelId ? settings : null;

  @override
  Future<void> saveSettings(ModelSettingsRecord value) async {
    settings = value;
  }

  @override
  Future<ModelTags> tagsFor(
    String modelId, {
    bool artifactsReady = true,
  }) async {
    final override = _tagsById[modelId];
    if (override != null) return override;
    final model = _models[modelId];
    if (model == null) return const ModelTags();
    final base = model.parentModelId == null
        ? null
        : _models[model.parentModelId];
    final merged = base == null
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
  }) async =>
      (await tagsFor(modelId, artifactsReady: artifactsReady)).supportedTasks;

  @override
  Future<void> deleteModel(String id) async {
    _models.remove(id);
    _artifacts.remove(id);
    _artifactFiles.remove(id);
  }

  @override
  Future<ProviderConfig?> providerConfigFor(String providerId) async {
    return ProviderConfig(
      id: providerId,
      alias: providerId,
      baseUrl: null,
      apiKey: null,
    );
  }

  @override
  Future<List<ModelRecord>> modelsForProvider(String providerId) async {
    return [
      for (final model in _models.values)
        if (model.providerId == providerId) model,
    ];
  }
}

class InMemoryProviderSettingsStore implements ProviderSettingsStore {
  InMemoryProviderSettingsStore([Map<String, StoredProviderSettings>? settings])
    : settings = settings ?? {};

  Map<String, StoredProviderSettings> settings;

  @override
  Future<Map<String, StoredProviderSettings>> read() async =>
      Map.unmodifiable(settings);

  @override
  Future<void> write(Map<String, StoredProviderSettings> value) async {
    settings = Map.of(value);
  }
}

class InMemoryProviderCredentialStore implements ProviderCredentialStore {
  InMemoryProviderCredentialStore([Map<String, String>? credentials])
    : credentials = credentials ?? {};

  Map<String, String> credentials;

  @override
  Future<String?> read(String providerId) async => credentials[providerId];

  @override
  Future<void> write(String providerId, String credential) async {
    credentials[providerId] = credential.trim();
  }

  @override
  Future<void> delete(String providerId) async {
    credentials.remove(providerId);
  }
}

class InMemoryProviderUsageStore implements ProviderUsageStore {
  InMemoryProviderUsageStore([Map<String, ProviderUsage>? usage])
    : usage = usage ?? {};

  Map<String, ProviderUsage> usage;

  @override
  Future<Map<String, ProviderUsage>> read() async => Map.unmodifiable(usage);

  @override
  Future<void> write(Map<String, ProviderUsage> value) async {
    usage = Map.of(value);
  }
}
