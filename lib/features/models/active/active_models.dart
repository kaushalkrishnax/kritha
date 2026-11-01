import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../intelligence/model_configuration.dart';
import '../../intelligence/models/model_descriptor.dart';
import '../../intelligence/models/model_capabilities.dart';
import '../../intelligence/runtime_ids.dart';
import '../../intelligence/models/task_registry.dart';
import '../../providers/provider_definition.dart';
import '../../providers/providers_controller.dart';
import '../catalogue/catalogue_model.dart';

enum ActiveAssignmentStatus { noModel, ready, active, assigned, stale }

class ActiveModelAssignment {
  const ActiveModelAssignment({
    required this.capability,
    required this.modelId,
    required this.displayName,
    required this.runtimeId,
    required this.activatedAt,
    this.sourceId = localProviderId,
    this.taskId,
    this.enabledTaskIds = const [],
  });

  final ModelCapability capability;
  final String modelId;
  final String displayName;
  final String runtimeId;
  final DateTime activatedAt;
  final String sourceId;
  final String? taskId;
  final List<String> enabledTaskIds;

  bool get isMultimodal => enabledTaskIds.length > 1;

  String get canonicalTaskId =>
      taskId ??
      (enabledTaskIds.isEmpty
          ? _canonicalTaskIdForCapability(capability)
          : enabledTaskIds.first);

  Map<String, dynamic> toJson() => {
    'capability': capability.name,
    'modelId': modelId,
    'displayName': displayName,
    'runtimeId': runtimeId,
    'activatedAt': activatedAt.toIso8601String(),
    'sourceId': sourceId,
    'taskId': canonicalTaskId,
    'enabledTaskIds': enabledTaskIds.isEmpty
        ? [canonicalTaskId]
        : enabledTaskIds,
  };

  factory ActiveModelAssignment.fromJson(
    ModelCapability capability,
    Map<String, dynamic> json,
  ) {
    final modelId = json['modelId'];
    if (modelId is! String || modelId.trim().isEmpty) {
      throw const FormatException('Missing model id');
    }
    final sourceId = _canonicalSourceId(
      json['sourceId'] is String ? json['sourceId'] as String : null,
    );
    return ActiveModelAssignment(
      capability: capability,
      modelId: modelId,
      displayName: json['displayName'] is String
          ? json['displayName'] as String
          : modelId,
      runtimeId: _canonicalRuntimeId(
        sourceId,
        json['runtimeId'] is String ? json['runtimeId'] as String : null,
      ),
      activatedAt:
          DateTime.tryParse('${json['activatedAt']}') ?? DateTime.now(),
      sourceId: sourceId,
      taskId: json['taskId'] is String ? json['taskId'] as String : null,
      enabledTaskIds: _stringList(json['enabledTaskIds']),
    );
  }
}

List<String> _stringList(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is String && item.isNotEmpty) item,
      ]
    : const [];

Set<InferenceCapability> inferenceCapabilitiesForTaskId(String taskId) {
  final task = AiTaskId.fromId(taskId);
  return task == null ? const {} : capabilitiesForTask(task);
}

InferenceCapability? routingCapabilityForTaskId(String taskId) {
  return switch (AiTaskId.fromId(taskId)) {
    AiTaskId.textGeneration => InferenceCapability.textGeneration,
    AiTaskId.imageTextToText => InferenceCapability.imageInput,
    AiTaskId.videoTextToText => null,
    AiTaskId.audioUnderstanding ||
    AiTaskId.automaticSpeechRecognition => InferenceCapability.audioInput,
    _ => null,
  };
}

String _canonicalTaskIdForCapability(ModelCapability capability) =>
    switch (capability) {
      ModelCapability.text => AiTaskId.textGeneration.id,
      ModelCapability.vision => AiTaskId.imageTextToText.id,
      ModelCapability.imageGeneration => AiTaskId.textToImage.id,
      ModelCapability.speechRecognition =>
        AiTaskId.automaticSpeechRecognition.id,
      ModelCapability.textToSpeech => AiTaskId.textToSpeech.id,
      ModelCapability.audio => AiTaskId.audioUnderstanding.id,
      ModelCapability.video => AiTaskId.videoTextToText.id,
      ModelCapability.embeddings => AiTaskId.embeddings.id,
    };

String _canonicalSourceId(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty || value == localRuntimeId) {
    return localProviderId;
  }
  return value;
}

String _canonicalRuntimeId(String sourceId, String? raw) {
  final value = raw?.trim();
  if (sourceId == localProviderId) return localRuntimeId;
  final definition = providerDefinitionFor(sourceId);
  if (definition != null) return definition.runtimeId;
  return value == null || value.isEmpty ? sourceId : value;
}

abstract interface class ActiveModelStore {
  Future<Map<ModelCapability, ActiveModelAssignment>> read();

  Future<void> write(Map<ModelCapability, ActiveModelAssignment> assignments);
}

abstract interface class RecentModelStore {
  Future<List<ActiveModelAssignment>> read();

  Future<void> write(List<ActiveModelAssignment> models);
}

class SharedPreferencesRecentModelStore implements RecentModelStore {
  const SharedPreferencesRecentModelStore();

  static const preferenceKey = 'kritha.models.active.recents';

  @override
  Future<List<ActiveModelAssignment>> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(preferenceKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final models = <ActiveModelAssignment>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final capabilityName = item['capability'];
        final capability = ModelCapability.values.where(
          (value) => value.name == capabilityName,
        );
        if (capability.isEmpty) continue;
        try {
          models.add(
            ActiveModelAssignment.fromJson(capability.first, {
              for (final entry in item.entries) '${entry.key}': entry.value,
            }),
          );
        } on FormatException {
          continue;
        }
      }
      return List.unmodifiable(models);
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> write(List<ActiveModelAssignment> models) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      preferenceKey,
      jsonEncode([for (final model in models) model.toJson()]),
    );
  }
}

class SharedPreferencesActiveModelStore implements ActiveModelStore {
  const SharedPreferencesActiveModelStore();

  static const preferenceKey = 'kritha.models.active.assignments';

  @override
  Future<Map<ModelCapability, ActiveModelAssignment>> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(preferenceKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final result = <ModelCapability, ActiveModelAssignment>{};
      final taskAssignments = decoded['tasks'];
      if (taskAssignments is Map) {
        for (final entry in taskAssignments.entries) {
          final taskId = '${entry.key}';
          final capability = _capabilityForTaskId(taskId);
          final value = entry.value;
          if (capability == null || value is! Map) continue;
          try {
            result[capability] = ActiveModelAssignment.fromJson(capability, {
              for (final item in value.entries) '${item.key}': item.value,
              'taskId': taskId,
            });
          } on FormatException {
            continue;
          }
        }
        if (result.isNotEmpty) return Map.unmodifiable(result);
      }
      final legacyAssignments = decoded['assignments'] is Map
          ? decoded['assignments'] as Map
          : decoded;
      for (final capability in ModelCapability.values) {
        final value = legacyAssignments[capability.name];
        if (value is! Map) continue;
        try {
          result[capability] = ActiveModelAssignment.fromJson(capability, {
            for (final entry in value.entries) '${entry.key}': entry.value,
          });
        } on FormatException {
          continue;
        }
      }
      return Map.unmodifiable(result);
    } on FormatException {
      return const {};
    }
  }

  @override
  Future<void> write(
    Map<ModelCapability, ActiveModelAssignment> assignments,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    if (assignments.isEmpty) {
      await preferences.remove(preferenceKey);
      return;
    }
    final tasks = <String, dynamic>{};
    for (final entry in assignments.entries) {
      final assignment = entry.value;
      final taskIds = assignment.enabledTaskIds.isEmpty
          ? [assignment.canonicalTaskId]
          : assignment.enabledTaskIds;
      for (final taskId in taskIds) {
        tasks[taskId] = {...assignment.toJson(), 'taskId': taskId};
      }
    }
    await preferences.setString(
      preferenceKey,
      jsonEncode({
        'version': 2,
        'tasks': tasks,
        'assignments': {
          for (final entry in assignments.entries)
            entry.key.name: entry.value.toJson(),
        },
      }),
    );
  }
}

ModelCapability? _capabilityForTaskId(String taskId) {
  final task = AiTaskId.fromId(taskId);
  return switch (task) {
    AiTaskId.textGeneration => ModelCapability.text,
    AiTaskId.imageTextToText => ModelCapability.vision,
    AiTaskId.videoTextToText => ModelCapability.video,
    AiTaskId.audioUnderstanding => ModelCapability.audio,
    AiTaskId.automaticSpeechRecognition => ModelCapability.speechRecognition,
    AiTaskId.textToSpeech => ModelCapability.textToSpeech,
    AiTaskId.textToImage ||
    AiTaskId.imageEditing => ModelCapability.imageGeneration,
    AiTaskId.audioGeneration => ModelCapability.audio,
    AiTaskId.videoGeneration => ModelCapability.video,
    AiTaskId.embeddings => ModelCapability.embeddings,
    null => null,
  };
}

class ActiveModelException implements Exception {
  const ActiveModelException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ActiveModelsState {
  const ActiveModelsState({
    this.assignments = const {},
    this.configuredModel,
    this.configurationStatus,
    this.configurationMessage,
    this.configurationFileName,
    this.recents = const [],
  });

  final Map<ModelCapability, ActiveModelAssignment> assignments;
  final ModelDescriptor? configuredModel;
  final ModelConfigurationStatus? configurationStatus;
  final String? configurationMessage;
  final String? configurationFileName;
  final List<ActiveModelAssignment> recents;

  ActiveAssignmentStatus statusFor(ModelCapability capability) {
    final assignment = assignments[capability];
    if (assignment == null) {
      return capability == ModelCapability.text && configuredModel != null
          ? ActiveAssignmentStatus.ready
          : ActiveAssignmentStatus.noModel;
    }
    if (assignment.sourceId != localProviderId) {
      return ActiveAssignmentStatus.assigned;
    }
    final model = configuredModel;
    if (capability != ModelCapability.text || model == null) {
      return ActiveAssignmentStatus.stale;
    }
    if (assignment.modelId == model.id &&
        assignment.runtimeId == model.runtimeId) {
      return ActiveAssignmentStatus.active;
    }
    return ActiveAssignmentStatus.stale;
  }

  bool get hasConfiguredModel => configuredModel != null;

  ActiveModelsState copyWith({
    Map<ModelCapability, ActiveModelAssignment>? assignments,
    ModelDescriptor? configuredModel,
    ModelConfigurationStatus? configurationStatus,
    String? configurationMessage,
    String? configurationFileName,
    List<ActiveModelAssignment>? recents,
  }) {
    return ActiveModelsState(
      assignments: assignments ?? this.assignments,
      configuredModel: configuredModel ?? this.configuredModel,
      configurationStatus: configurationStatus ?? this.configurationStatus,
      configurationMessage: configurationMessage ?? this.configurationMessage,
      configurationFileName:
          configurationFileName ?? this.configurationFileName,
      recents: recents ?? this.recents,
    );
  }
}

class ActiveModelsController extends AsyncNotifier<ActiveModelsState> {
  Future<void> _writes = Future<void>.value();

  @override
  Future<ActiveModelsState> build() async {
    final configuration = await ref.watch(modelConfigurationProvider.future);
    final store = ref.watch(activeModelStoreProvider);
    final recentStore = ref.watch(recentModelStoreProvider);
    await _writes;
    final assignments = await store.read();
    final recents = await recentStore.read();
    return ActiveModelsState(
      assignments: assignments,
      configuredModel: configuration.descriptor,
      configurationStatus: configuration.status,
      configurationMessage: configuration.message,
      configurationFileName: configuration.fileName,
      recents: recents,
    );
  }

  Future<void> activate(ModelCapability capability) async {
    if (capability != ModelCapability.text) {
      throw ActiveModelException(
        '${capability.label} has no verified execution path in this build.',
      );
    }
    final configuration = await ref.read(modelConfigurationProvider.future);
    final model = configuration.descriptor;
    if (model == null) {
      throw const ActiveModelException(
        'Choose and validate a local LiteRT-LM file in Models first.',
      );
    }
    final current = state.value;
    if (current == null) return;
    await assignModel(
      capability: capability,
      sourceId: localProviderId,
      modelId: model.id,
      displayName: model.displayName,
      runtimeId: model.runtimeId,
    );
  }

  Future<void> assignModel({
    required ModelCapability capability,
    required String sourceId,
    required String modelId,
    required String displayName,
    required String runtimeId,
    String? taskId,
    List<String> enabledTaskIds = const [],
  }) async {
    final canonicalTaskIds = enabledTaskIds.isEmpty
        ? [taskId ?? _canonicalTaskIdForCapability(capability)]
        : [
            for (final value in enabledTaskIds)
              if (AiTaskId.fromId(value) != null) value,
          ];
    if (canonicalTaskIds.isEmpty) {
      throw const ActiveModelException('Select at least one supported task.');
    }
    final canonicalSourceId = _canonicalSourceId(sourceId);
    final canonicalRuntimeId = _canonicalRuntimeId(
      canonicalSourceId,
      runtimeId,
    );
    if (canonicalSourceId == localProviderId) {
      if (capability != ModelCapability.text) {
        throw ActiveModelException(
          'The local LiteRT-LM runtime does not expose ${capability.label.toLowerCase()} in this build.',
        );
      }
      final model = (await ref.read(modelConfigurationProvider.future))
          .descriptor;
      if (model == null || model.id != modelId) {
        throw const ActiveModelException(
          'This local file is no longer available or valid.',
        );
      }
    } else {
      final provider = await ref.read(providersControllerProvider.future);
      final configuration = provider.configurationFor(canonicalSourceId);
      if (configuration == null || !configuration.configured) {
        throw const ActiveModelException(
          'Connect this provider before assigning its model.',
        );
      }
      final models = await ref.read(
        providerModelsProvider(canonicalSourceId).future,
      );
      final model = models.where((model) => model.id == modelId);
      if (model.isEmpty || !model.first.supports(capability)) {
        throw const ActiveModelException(
          'This model is no longer available for that capability.',
        );
      }
      final discoveredTasks = model.first.tasks;
      if (discoveredTasks.isNotEmpty &&
          canonicalTaskIds.any(
            (taskId) => !discoveredTasks.any((task) => task.task.id == taskId),
          )) {
        throw const ActiveModelException(
          'This model does not explicitly support every selected task.',
        );
      }
    }
    final current = state.value;
    if (current == null) return;
    final assignment = ActiveModelAssignment(
      capability: capability,
      modelId: modelId,
      displayName: displayName,
      runtimeId: canonicalRuntimeId,
      sourceId: canonicalSourceId,
      activatedAt: DateTime.now(),
      taskId: canonicalTaskIds.first,
      enabledTaskIds: List.unmodifiable(canonicalTaskIds),
    );
    final next = Map<ModelCapability, ActiveModelAssignment>.from(
      current.assignments,
    )..[capability] = assignment;
    final recents = [
      assignment,
      ...current.recents.where(
        (item) =>
            !(item.sourceId == canonicalSourceId && item.modelId == modelId),
      ),
    ].take(12).toList(growable: false);
    await _persist(next);
    await ref.read(recentModelStoreProvider).write(recents);
    if (!ref.mounted) return;
    state = AsyncData(
      current.copyWith(
        assignments: Map.unmodifiable(next),
        recents: List.unmodifiable(recents),
      ),
    );
  }

  Future<void> deactivate(ModelCapability capability) async {
    final current = state.value;
    if (current == null || !current.assignments.containsKey(capability)) return;
    final next = Map<ModelCapability, ActiveModelAssignment>.from(
      current.assignments,
    )..remove(capability);
    await _persist(next);
    if (!ref.mounted) return;
    state = AsyncData(current.copyWith(assignments: Map.unmodifiable(next)));
  }

  Future<void> _persist(
    Map<ModelCapability, ActiveModelAssignment> assignments,
  ) {
    final previous = _writes;
    final done = () async {
      await previous;
      await ref.read(activeModelStoreProvider).write(assignments);
    }();
    _writes = done.catchError((Object _) {});
    return done;
  }
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
