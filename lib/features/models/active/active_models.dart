import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../../data/app_database.dart';
import '../../../models/model_record.dart';
import '../../intelligence/models/task_registry.dart';
import '../../intelligence/providers/providers.dart';
import '../catalogue/catalogue_model.dart';
import '../domain/model_tags.dart';
import '../model_record_store.dart';
import '../setup/model_artifact_storage.dart';

enum ActiveAssignmentStatus { noModel, active, assigned, stale }

/// Capabilities routed through one multimodal model.
class MultiModelSelection {
  const MultiModelSelection({
    required this.modelId,
    required this.enabledCapabilities,
  });

  final String modelId;
  final Set<ModelCapability> enabledCapabilities;

  bool get isMultimodal => enabledCapabilities.length >= 2;

  MultiModelSelection copyWith({Set<ModelCapability>? enabledCapabilities}) {
    return MultiModelSelection(
      modelId: modelId,
      enabledCapabilities: enabledCapabilities ?? this.enabledCapabilities,
    );
  }

  Map<String, dynamic> toJson() => {
    'modelId': modelId,
    'enabledCapabilities': [
      for (final capability in enabledCapabilities) capability.name,
    ],
  };

  factory MultiModelSelection.fromJson(Map<String, dynamic> json) {
    final modelId = json['modelId'];
    if (modelId is! String || modelId.trim().isEmpty) {
      throw const FormatException('Missing multi-model id');
    }
    return MultiModelSelection(
      modelId: modelId,
      enabledCapabilities: _capabilitiesFrom(json['enabledCapabilities']),
    );
  }
}

/// Persisted Active Models selection. Exactly one JSON object in preferences.
class ActiveModelConfig {
  const ActiveModelConfig({this.multiModel, this.singleModels = const {}});

  final MultiModelSelection? multiModel;
  final Map<ModelCapability, String> singleModels;

  bool get isEmpty =>
      multiModel == null && singleModels.values.every((id) => id.isEmpty);

  Map<String, dynamic> toJson() => {
    'multiModel': multiModel?.toJson(),
    'singleModels': [
      for (final entry in singleModels.entries)
        {'capability': entry.key.name, 'modelId': entry.value},
    ],
  };

  factory ActiveModelConfig.fromJson(Map<String, dynamic> json) {
    MultiModelSelection? multi;
    final rawMulti = json['multiModel'];
    if (rawMulti is Map) {
      try {
        multi = MultiModelSelection.fromJson({
          for (final entry in rawMulti.entries) '${entry.key}': entry.value,
        });
      } on FormatException {
        multi = null;
      }
    }
    if (multi != null && !multi.isMultimodal) multi = null;

    final singles = <ModelCapability, String>{};
    final rawSingles = json['singleModels'];
    if (rawSingles is List) {
      for (final item in rawSingles) {
        if (item is! Map) continue;
        final capability = _capabilityFrom(item['capability']);
        final modelId = item['modelId'];
        if (capability == null || modelId is! String || modelId.isEmpty) {
          continue;
        }
        singles[capability] = modelId;
      }
    }
    return ActiveModelConfig(
      multiModel: multi,
      singleModels: Map.unmodifiable(singles),
    );
  }

  ActiveModelConfig withoutModels(Set<String> modelIds) {
    MultiModelSelection? multi = multiModel;
    if (multi != null && modelIds.contains(multi.modelId)) {
      multi = null;
    }
    final singles = {
      for (final entry in singleModels.entries)
        if (!modelIds.contains(entry.value)) entry.key: entry.value,
    };
    return ActiveModelConfig(
      multiModel: multi,
      singleModels: Map.unmodifiable(singles),
    );
  }
}

Set<ModelCapability> _capabilitiesFrom(Object? value) {
  final result = <ModelCapability>{};
  if (value is List) {
    for (final item in value) {
      final capability = _capabilityFrom(item);
      if (capability != null) result.add(capability);
    }
  }
  return Set.unmodifiable(result);
}

ModelCapability? _capabilityFrom(Object? value) {
  if (value is! String) return null;
  for (final capability in ModelCapability.values) {
    if (capability.name == value) return capability;
  }
  return null;
}

/// One capability slot resolved against the unified model repository.
///
/// [modelId] is the internal model UUID. The executing provider is resolved
/// from the model record's [ModelRecord.providerId].
class ActiveModelAssignment {
  const ActiveModelAssignment({
    required this.capability,
    required this.modelId,
    required this.displayName,
    required this.activatedAt,
    this.enabledTaskIds = const [],
    this.enabledCapabilities = const {},
  });

  final ModelCapability capability;
  final String modelId;
  final String displayName;
  final DateTime activatedAt;
  final List<String> enabledTaskIds;
  final Set<ModelCapability> enabledCapabilities;

  bool get isMultimodal => enabledCapabilities.length >= 2;

  static ActiveModelAssignment? forModel({
    required ModelCapability capability,
    required ModelRecord model,
    required ModelTags tags,
    Set<ModelCapability> enabledCapabilities = const {},
  }) {
    if (!modelSupportsCapability(model, tags, capability)) return null;
    return ActiveModelAssignment(
      capability: capability,
      modelId: model.id,
      displayName: model.displayName,
      activatedAt: DateTime.now(),
      enabledTaskIds: tags.executableTasks.isNotEmpty
          ? [for (final task in tags.executableTasks) task.id]
          : [canonicalTaskForCapability(capability).id],
      enabledCapabilities: enabledCapabilities,
    );
  }
}

bool modelSupportsCapability(
  ModelRecord model,
  ModelTags? tags,
  ModelCapability capability,
) {
  final task = canonicalTaskForCapability(capability);
  if (tags != null && tags.canExecuteTask(task)) return true;
  if (tags != null && tags.supportsTask(task)) return true;
  if (model.tasks.any((t) => t.task == task)) return true;
  if (capability == ModelCapability.text) {
    return model.tasks.isEmpty ||
        model.tasks.any(
          (t) =>
              t.task == AiTaskId.textGeneration ||
              t.task == AiTaskId.imageTextToText ||
              t.task == AiTaskId.audioUnderstanding ||
              t.task == AiTaskId.videoTextToText,
        );
  }
  return false;
}

AiTaskId canonicalTaskForCapability(ModelCapability capability) {
  return switch (capability) {
    ModelCapability.text => AiTaskId.textGeneration,
    ModelCapability.vision => AiTaskId.imageTextToText,
    ModelCapability.imageGeneration => AiTaskId.textToImage,
    ModelCapability.speechRecognition => AiTaskId.automaticSpeechRecognition,
    ModelCapability.textToSpeech => AiTaskId.textToSpeech,
    ModelCapability.audio => AiTaskId.audioUnderstanding,
    ModelCapability.video => AiTaskId.videoTextToText,
    ModelCapability.embeddings => AiTaskId.embeddings,
  };
}

class RecentModelRef {
  const RecentModelRef({required this.capability, required this.modelId});

  final ModelCapability capability;
  final String modelId;

  Map<String, dynamic> toJson() => {
    'capability': capability.name,
    'modelId': modelId,
  };

  factory RecentModelRef.fromJson(Map<String, dynamic> json) {
    final capability = _capabilityFrom(json['capability']);
    final modelId = json['modelId'];
    if (capability == null || modelId is! String || modelId.isEmpty) {
      throw const FormatException('Invalid recent model');
    }
    return RecentModelRef(capability: capability, modelId: modelId);
  }
}

class ActiveModelException implements Exception {
  const ActiveModelException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ActiveModelsState {
  const ActiveModelsState({
    required this.config,
    required this.assignments,
    required this.recents,
    required this.recentRefs,
    required this.models,
    required this.tags,
    required this.artifactFiles,
  });

  final ActiveModelConfig config;
  final Map<ModelCapability, ActiveModelAssignment> assignments;
  final List<ActiveModelAssignment> recents;
  final List<RecentModelRef> recentRefs;
  final Map<String, ModelRecord> models;
  final Map<String, ModelTags> tags;
  final Map<String, List<ResolvedModelArtifactFile>> artifactFiles;

  MultiModelSelection? get multiModel => config.multiModel;

  Map<ModelCapability, String> get singleModels => config.singleModels;

  ActiveAssignmentStatus statusFor(ModelCapability capability) {
    final assignment = assignments[capability];
    if (assignment == null) return ActiveAssignmentStatus.noModel;
    final model = models[assignment.modelId];
    final tags = this.tags[assignment.modelId];
    if (model == null || !modelSupportsCapability(model, tags, capability)) {
      return ActiveAssignmentStatus.stale;
    }
    return ActiveAssignmentStatus.active;
  }

  /// Internal provider UUID executing the model, or empty if unknown.
  String providerIdFor(String modelId) {
    final model = models[modelId];
    if (model == null) return '';
    return model.providerId;
  }

  /// External model identifier used by the executing provider.
  String providerModelIdFor(String modelId) {
    final model = models[modelId];
    if (model == null) return '';
    return model.externalModelId;
  }

  /// Canonical task to model selection, multi-model first without fallback.
  Map<AiTaskId, String> get executableSelection {
    final result = <AiTaskId, String>{};
    final multi = multiModel;
    if (multi != null && multi.isMultimodal) {
      final model = models[multi.modelId];
      final modelTags = tags[multi.modelId];
      if (model != null) {
        for (final capability in multi.enabledCapabilities) {
          if (modelSupportsCapability(model, modelTags, capability)) {
            result[canonicalTaskForCapability(capability)] = multi.modelId;
          }
        }
      }
    }
    for (final entry in singleModels.entries) {
      final task = canonicalTaskForCapability(entry.key);
      if (result.containsKey(task)) continue;
      final model = models[entry.value];
      final modelTags = tags[entry.value];
      if (model != null &&
          modelSupportsCapability(model, modelTags, entry.key)) {
        result[task] = entry.value;
      }
    }
    return Map.unmodifiable(result);
  }
}

abstract interface class ActiveModelStore {
  Future<ActiveModelConfig> read();

  Future<void> write(ActiveModelConfig config);
}

class SharedPreferencesActiveModelStore implements ActiveModelStore {
  const SharedPreferencesActiveModelStore();

  static const preferenceKey = 'kritha.models.active.assignments';

  @override
  Future<ActiveModelConfig> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(preferenceKey);
    if (raw == null || raw.isEmpty) return const ActiveModelConfig();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const ActiveModelConfig();
      return ActiveModelConfig.fromJson({
        for (final entry in decoded.entries) '${entry.key}': entry.value,
      });
    } on FormatException {
      return const ActiveModelConfig();
    }
  }

  @override
  Future<void> write(ActiveModelConfig config) async {
    final preferences = await SharedPreferences.getInstance();
    if (config.isEmpty) {
      await preferences.remove(preferenceKey);
      return;
    }
    await preferences.setString(preferenceKey, jsonEncode(config.toJson()));
  }
}

abstract interface class RecentModelStore {
  Future<List<RecentModelRef>> read();

  Future<void> write(List<RecentModelRef> models);
}

class SharedPreferencesRecentModelStore implements RecentModelStore {
  const SharedPreferencesRecentModelStore();

  static const preferenceKey = 'kritha.models.active.recents';

  @override
  Future<List<RecentModelRef>> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(preferenceKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final refs = <RecentModelRef>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          refs.add(
            RecentModelRef.fromJson({
              for (final entry in item.entries) '${entry.key}': entry.value,
            }),
          );
        } on FormatException {
          continue;
        }
      }
      return List.unmodifiable(refs);
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> write(List<RecentModelRef> models) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      preferenceKey,
      jsonEncode([for (final model in models) model.toJson()]),
    );
  }
}

class ActiveModelsController extends AsyncNotifier<ActiveModelsState> {
  Future<void> _writes = Future<void>.value();

  @override
  Future<ActiveModelsState> build() async {
    await _writes;
    await syncProviderModels();
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await syncProviderModels();
      return _load();
    });
  }

  Future<void> syncProviderModels({bool reloadState = false}) async {
    final database = ref.read(databaseProvider);
    final engine = ref.read(intelligenceEngineProvider);
    final repository = ref.read(modelRepositoryProvider);
    final providers = await database.allProviders();
    var changed = false;

    for (final provider in providers) {
      if (provider.id == localLitertlmProviderId) continue;
      final hasKey = provider.apiKey != null && provider.apiKey!.trim().isNotEmpty;
      final hasUrl = provider.baseUrl != null && provider.baseUrl!.trim().isNotEmpty;
      if (!hasKey && !hasUrl) continue;

      try {
        final discovered = await engine.discoverModelsForProvider(provider.id);
        for (final item in discovered) {
          final existing = await repository.findByProviderAndExternal(
            provider.id,
            item.externalModelId,
          );
          final record = ModelRecord(
            id: existing?.id ?? const Uuid().v4(),
            providerId: provider.id,
            externalModelId: item.externalModelId,
            displayName: item.displayName,
            parentModelId: existing?.parentModelId,
            suffix: existing?.suffix,
            publisher: existing?.publisher,
            metadata: {...existing?.metadata ?? const {}, ...item.metadata},
            tasks: item.tasks.isNotEmpty
                ? item.tasks
                : (existing?.tasks ?? const [
                    TaskDeclaration(
                      task: AiTaskId.textGeneration,
                      confidence: TaskMetadataConfidence.explicit,
                      source: TaskMetadataSource.provider,
                    ),
                  ]),
            createdAt: existing?.createdAt ?? DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await repository.saveModel(record);
          changed = true;
        }
      } catch (_) {}
    }

    if (reloadState && changed && ref.mounted) {
      state = AsyncData(await _load());
    }
  }

  Future<ActiveModelsState> _load() async {
    final repository = ref.read(modelRepositoryProvider);
    final store = ref.read(activeModelStoreProvider);
    final recentStore = ref.read(recentModelStoreProvider);
    final config = await store.read();
    final recentRefs = await recentStore.read();

    final modelsList = await repository.allModels();
    final models = <String, ModelRecord>{
      for (final model in modelsList) model.id: model,
    };
    final documentsPath = await _documentsPath();
    final tags = <String, ModelTags>{};
    final artifactFiles = <String, List<ResolvedModelArtifactFile>>{};
    for (final model in modelsList) {
      var files = const <ResolvedModelArtifactFile>[];
      files = await repository.resolveArtifacts(
        model.id,
        documentsPath: documentsPath,
      );
      artifactFiles[model.id] = files;
      tags[model.id] = await repository.tagsFor(
        model.id,
        artifactsReady: _artifactsReady(files),
      );
    }

    final sanitized = _sanitize(config, models, tags);
    if (jsonEncode(sanitized.toJson()) != jsonEncode(config.toJson())) {
      await store.write(sanitized);
    }
    final validRecents = _sanitizeRecents(recentRefs, models, tags);
    if (jsonEncode([for (final ref in validRecents) ref.toJson()]) !=
        jsonEncode([for (final ref in recentRefs) ref.toJson()])) {
      await recentStore.write(validRecents);
    }

    return _compose(
      config: sanitized,
      recentRefs: validRecents,
      models: models,
      tags: tags,
      artifactFiles: artifactFiles,
    );
  }

  Future<String> _documentsPath() async {
    try {
      final runtime = await ref.read(runtimeStatusProvider.future);
      return runtime.documentsPath;
    } on Object {
      return '';
    }
  }

  Future<void> _persist(
    ActiveModelConfig config,
    List<RecentModelRef> recents,
  ) {
    final previous = _writes;
    final done = () async {
      await previous;
      await ref.read(activeModelStoreProvider).write(config);
      await ref.read(recentModelStoreProvider).write(recents);
    }();
    _writes = done.catchError((Object _) {});
    return done;
  }

  Future<void> assignModel({
    required ModelCapability capability,
    required String modelId,
    Set<ModelCapability> enabledCapabilities = const {},
  }) async {
    final current = state.value;
    if (current == null) return;
    final repository = ref.read(modelRepositoryProvider);
    final record = await repository.findById(modelId);
    if (record == null) {
      throw const ActiveModelException(
        'The selected model is no longer available.',
      );
    }

    final tags = await repository.tagsFor(record.id);
    final requested = enabledCapabilities.isEmpty
        ? {capability}
        : Set<ModelCapability>.from(enabledCapabilities);
    for (final item in requested) {
      if (!modelSupportsCapability(record, tags, item)) {
        throw ActiveModelException(
          '${record.displayName} cannot execute ${item.label.toLowerCase()}.',
        );
      }
    }

    final recents = [
      for (final item in requested)
        RecentModelRef(capability: item, modelId: record.id),
      ...current.recentRefs.where(
        (ref) =>
            !(requested.contains(ref.capability) && ref.modelId == record.id),
      ),
    ].take(12).toList(growable: false);

    var config = current.config;
    if (requested.length >= 2) {
      final singles = Map<ModelCapability, String>.from(config.singleModels)
        ..removeWhere((item, _) => requested.contains(item));
      config = ActiveModelConfig(
        multiModel: MultiModelSelection(
          modelId: record.id,
          enabledCapabilities: Set.unmodifiable(requested),
        ),
        singleModels: Map.unmodifiable(singles),
      );
    } else {
      final single = requested.single;
      var multi = config.multiModel;
      if (multi != null && multi.enabledCapabilities.contains(single)) {
        final remaining = Set<ModelCapability>.from(multi.enabledCapabilities)
          ..remove(single);
        multi = remaining.length >= 2
            ? multi.copyWith(enabledCapabilities: Set.unmodifiable(remaining))
            : null;
      }
      config = ActiveModelConfig(
        multiModel: multi,
        singleModels: Map.unmodifiable({
          ...config.singleModels,
          single: record.id,
        }),
      );
    }
    await _persist(config, recents);
    if (!ref.mounted) return;
    state = AsyncData(await _load());
  }

  Future<void> clearMultiModel() async {
    final current = state.value;
    if (current == null || current.config.multiModel == null) return;
    final config = ActiveModelConfig(singleModels: current.config.singleModels);
    await _persist(config, current.recentRefs);
    if (!ref.mounted) return;
    state = AsyncData(await _load());
  }

  Future<void> deactivate(ModelCapability capability) async {
    final current = state.value;
    if (current == null) return;
    var config = current.config;
    var multi = config.multiModel;
    final singles = Map<ModelCapability, String>.from(config.singleModels)
      ..remove(capability);
    if (multi != null && multi.enabledCapabilities.contains(capability)) {
      final remaining = Set<ModelCapability>.from(multi.enabledCapabilities)
        ..remove(capability);
      if (remaining.length >= 2) {
        multi = multi.copyWith(
          enabledCapabilities: Set.unmodifiable(remaining),
        );
      } else {
        for (final item in remaining) {
          singles.putIfAbsent(item, () => multi!.modelId);
        }
        multi = null;
      }
    }
    config = ActiveModelConfig(
      multiModel: multi,
      singleModels: Map.unmodifiable(singles),
    );
    await _persist(config, current.recentRefs);
    if (!ref.mounted) return;
    state = AsyncData(await _load());
  }
}

ActiveModelsState _compose({
  required ActiveModelConfig config,
  required List<RecentModelRef> recentRefs,
  required Map<String, ModelRecord> models,
  required Map<String, ModelTags> tags,
  required Map<String, List<ResolvedModelArtifactFile>> artifactFiles,
}) {
  final assignments = <ModelCapability, ActiveModelAssignment>{};
  final multi = config.multiModel;
  if (multi != null && multi.isMultimodal) {
    final model = models[multi.modelId];
    final tagsForModel = tags[multi.modelId];
    if (model != null && tagsForModel != null) {
      for (final capability in multi.enabledCapabilities) {
        final assignment = ActiveModelAssignment.forModel(
          capability: capability,
          model: model,
          tags: tagsForModel,
          enabledCapabilities: multi.enabledCapabilities,
        );
        if (assignment != null) assignments[capability] = assignment;
      }
    }
  }
  for (final entry in config.singleModels.entries) {
    if (assignments.containsKey(entry.key)) continue;
    final model = models[entry.value];
    final tagsForModel = tags[entry.value];
    if (model == null || tagsForModel == null) continue;
    final assignment = ActiveModelAssignment.forModel(
      capability: entry.key,
      model: model,
      tags: tagsForModel,
    );
    if (assignment != null) assignments[entry.key] = assignment;
  }

  final recents = <ActiveModelAssignment>[];
  for (final ref in recentRefs) {
    if (recents.any(
      (item) =>
          item.capability == ref.capability && item.modelId == ref.modelId,
    )) {
      continue;
    }
    final model = models[ref.modelId];
    final tagsForModel = tags[ref.modelId];
    if (model == null || tagsForModel == null) continue;
    final assignment = ActiveModelAssignment.forModel(
      capability: ref.capability,
      model: model,
      tags: tagsForModel,
    );
    if (assignment != null) recents.add(assignment);
  }

  return ActiveModelsState(
    config: config,
    assignments: Map.unmodifiable(assignments),
    recents: List.unmodifiable(recents),
    recentRefs: List.unmodifiable(recentRefs),
    models: Map.unmodifiable(models),
    tags: Map.unmodifiable(tags),
    artifactFiles: Map.unmodifiable(artifactFiles),
  );
}

ActiveModelConfig _sanitize(
  ActiveModelConfig config,
  Map<String, ModelRecord> models,
  Map<String, ModelTags> tags,
) {
  var multi = config.multiModel;
  final singles = <ModelCapability, String>{};
  bool canExecute(String modelId, ModelCapability capability) {
    final model = models[modelId];
    if (model == null) return false;
    final tagsForModel = tags[modelId];
    return modelSupportsCapability(model, tagsForModel, capability);
  }

  if (multi != null) {
    final multiModel = multi;
    final enabled = {
      for (final capability in multiModel.enabledCapabilities)
        if (canExecute(multiModel.modelId, capability)) capability,
    };
    if (enabled.length >= 2) {
      multi = multi.copyWith(enabledCapabilities: Set.unmodifiable(enabled));
    } else {
      for (final capability in enabled) {
        singles.putIfAbsent(capability, () => multi!.modelId);
      }
      multi = null;
    }
  }
  for (final entry in config.singleModels.entries) {
    if (canExecute(entry.value, entry.key)) singles[entry.key] = entry.value;
  }
  return ActiveModelConfig(
    multiModel: multi,
    singleModels: Map.unmodifiable(singles),
  );
}

List<RecentModelRef> _sanitizeRecents(
  List<RecentModelRef> refs,
  Map<String, ModelRecord> models,
  Map<String, ModelTags> tags,
) {
  final result = <RecentModelRef>[];
  for (final ref in refs) {
    final model = models[ref.modelId];
    if (model == null) continue;
    final tagsForModel = tags[ref.modelId];
    if (!modelSupportsCapability(model, tagsForModel, ref.capability)) {
      continue;
    }
    if (result.any(
      (item) =>
          item.capability == ref.capability && item.modelId == ref.modelId,
    )) {
      continue;
    }
    result.add(ref);
  }
  return List.unmodifiable(result);
}

bool _artifactsReady(List<ResolvedModelArtifactFile> files) {
  final selected = [
    for (final file in files)
      if (file.selected) file,
  ];
  if (selected.isEmpty) return false;
  if (!selected.any((file) => file.artifact.kind == 'weights')) return false;
  return selected.every((file) => file.ready);
}

final activeModelStoreProvider = Provider<ActiveModelStore>(
  (ref) => const SharedPreferencesActiveModelStore(),
);

final recentModelStoreProvider = Provider<RecentModelStore>(
  (ref) => const SharedPreferencesRecentModelStore(),
);

final activeModelsProvider =
    AsyncNotifierProvider<ActiveModelsController, ActiveModelsState>(
      ActiveModelsController.new,
    );
