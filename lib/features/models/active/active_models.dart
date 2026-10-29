import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../intelligence/model_configuration.dart';
import '../../intelligence/models/model_descriptor.dart';
import '../../providers/providers_controller.dart';
import '../catalogue/catalogue_model.dart';

enum ActiveAssignmentStatus {
  noRuntime,
  noModel,
  ready,
  active,
  assigned,
  stale,
}

class ActiveModelAssignment {
  const ActiveModelAssignment({
    required this.capability,
    required this.modelId,
    required this.displayName,
    required this.runtimeId,
    required this.activatedAt,
    this.sourceId = 'local-litertlm',
  });

  final ModelCapability capability;
  final String modelId;
  final String displayName;
  final String runtimeId;
  final DateTime activatedAt;
  final String sourceId;

  Map<String, dynamic> toJson() => {
    'capability': capability.name,
    'modelId': modelId,
    'displayName': displayName,
    'runtimeId': runtimeId,
    'activatedAt': activatedAt.toIso8601String(),
    'sourceId': sourceId,
  };

  factory ActiveModelAssignment.fromJson(
    ModelCapability capability,
    Map<String, dynamic> json,
  ) {
    final modelId = json['modelId'];
    if (modelId is! String || modelId.trim().isEmpty) {
      throw const FormatException('Missing model id');
    }
    return ActiveModelAssignment(
      capability: capability,
      modelId: modelId,
      displayName: json['displayName'] is String
          ? json['displayName'] as String
          : modelId,
      runtimeId: json['runtimeId'] is String
          ? json['runtimeId'] as String
          : 'unknown',
      activatedAt:
          DateTime.tryParse('${json['activatedAt']}') ?? DateTime.now(),
      sourceId: json['sourceId'] is String
          ? json['sourceId'] as String
          : 'local-litertlm',
    );
  }
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
      for (final capability in ModelCapability.values) {
        final value = decoded[capability.name];
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
    await preferences.setString(
      preferenceKey,
      jsonEncode({
        for (final entry in assignments.entries)
          entry.key.name: entry.value.toJson(),
      }),
    );
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
    if (assignment != null && assignment.sourceId != 'local-litertlm') {
      return ActiveAssignmentStatus.assigned;
    }
    if (capability != ModelCapability.text) {
      return assignment == null
          ? ActiveAssignmentStatus.noRuntime
          : ActiveAssignmentStatus.stale;
    }
    final model = configuredModel;
    if (model == null) {
      return assignment == null
          ? ActiveAssignmentStatus.noModel
          : ActiveAssignmentStatus.stale;
    }
    if (assignment == null) return ActiveAssignmentStatus.ready;
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
      sourceId: 'local-litertlm',
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
  }) async {
    if (capability != ModelCapability.text) {
      throw ActiveModelException(
        '${capability.label} does not have a usable execution path yet.',
      );
    }
    if (sourceId == 'local-litertlm') {
      final model = (await ref.read(modelConfigurationProvider.future))
          .descriptor;
      if (model == null || model.id != modelId) {
        throw const ActiveModelException(
          'This local file is no longer available or valid.',
        );
      }
    } else {
      final provider = await ref.read(providersControllerProvider.future);
      final configuration = provider.configurationFor(sourceId);
      if (configuration == null ||
          !configuration.enabled ||
          !configuration.configured) {
        throw const ActiveModelException(
          'Configure and enable this provider before assigning its model.',
        );
      }
      final models = await ref.read(providerModelsProvider(sourceId).future);
      if (!models.any((model) => model.id == modelId)) {
        throw const ActiveModelException(
          'This model is no longer available from the provider.',
        );
      }
    }
    final current = state.value;
    if (current == null) return;
    final assignment = ActiveModelAssignment(
      capability: capability,
      modelId: modelId,
      displayName: displayName,
      runtimeId: runtimeId,
      sourceId: sourceId,
      activatedAt: DateTime.now(),
    );
    final next = Map<ModelCapability, ActiveModelAssignment>.from(
      current.assignments,
    )..[capability] = assignment;
    final recents = [
      assignment,
      ...current.recents.where(
        (item) => !(item.sourceId == sourceId && item.modelId == modelId),
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
