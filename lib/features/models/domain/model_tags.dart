import 'dart:io';

import '../../intelligence/models/model_capabilities.dart';
import '../../intelligence/models/task_registry.dart';
import '../../../models/model_record.dart';

/// Runtime facts used to derive executable task and portability tags.
class ModelRuntimeSignature {
  const ModelRuntimeSignature({
    required this.id,
    required this.capabilities,
    this.platforms = const {},
    this.formats = const {},
    this.available = true,
  });

  final String id;
  final Set<InferenceCapability> capabilities;
  final Set<String> platforms;
  final Set<String> formats;
  final bool available;
}

/// Deterministic tag derivation from model records, task registry and runtimes.
class ModelTags {
  const ModelTags({
    this.supportedTasks = const [],
    this.executableTasks = const [],
    this.modalities = const {},
    this.supportedModalities = const {},
    this.portability = const {},
    this.runtimeId,
  });

  /// Declared by the model, regardless of current execution support.
  final List<AiTaskId> supportedTasks;

  /// Declared tasks the current runtime/provider can actually execute.
  final List<AiTaskId> executableTasks;

  /// Modalities of [executableTasks].
  final Set<AiModality> modalities;

  /// Modalities of every declared task.
  final Set<AiModality> supportedModalities;

  /// Non-speculative portability tags, e.g. `local`, `remote`, `android`.
  final Set<String> portability;

  final String? runtimeId;

  bool get hasLocalRuntime => runtimeId != null;

  bool get hasRemoteRoute => portability.contains('remote');

  bool supportsTask(AiTaskId task) => supportedTasks.contains(task);

  bool canExecuteTask(AiTaskId task) => executableTasks.contains(task);

  bool get isMultimodal =>
      executableTasks.length > 1 &&
      modalities.any((modality) => modality != AiModality.text);

  bool get isExecutable => executableTasks.isNotEmpty;

  ModelTags copyWith({
    List<AiTaskId>? supportedTasks,
    List<AiTaskId>? executableTasks,
    Set<AiModality>? modalities,
    Set<AiModality>? supportedModalities,
    Set<String>? portability,
    String? runtimeId,
    bool clearRuntime = false,
  }) {
    return ModelTags(
      supportedTasks: supportedTasks ?? this.supportedTasks,
      executableTasks: executableTasks ?? this.executableTasks,
      modalities: modalities ?? this.modalities,
      supportedModalities: supportedModalities ?? this.supportedModalities,
      portability: portability ?? this.portability,
      runtimeId: clearRuntime ? null : (runtimeId ?? this.runtimeId),
    );
  }
}

/// Current desktop or mobile platform identifier used for runtime matching.
String currentRuntimePlatform() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}

/// Repository-visible derivation context.
class ModelTagDerivation {
  const ModelTagDerivation({
    this.runtimes = const {},
    this.localRuntimeProviderId,
    this.remoteAliases = const {},
    this.platform,
  });

  /// Provider UUID -> runtime signature for locally executed models.
  final Map<String, ModelRuntimeSignature> runtimes;

  /// Provider UUID of the local runtime, e.g. LiteRT-LM.
  final String? localRuntimeProviderId;

  /// Provider aliases that execute through a remote provider adapter.
  final Set<String> remoteAliases;
  final String? platform;

  ModelTags derive(ModelRecord model, {bool artifactsReady = true}) {
    final supported = <AiTaskId>{
      for (final declaration in model.tasks) declaration.task,
    };
    final runtime = runtimes[model.providerId];
    final isLocal = model.providerId == localRuntimeProviderId;
    final isRemote = !isLocal;
    final platformSupported =
        runtime == null ||
        platform == null ||
        runtime.platforms.contains(platform);

    final executable = <AiTaskId>[];
    for (final task in supported) {
      if (!task.executable) continue;
      final required = capabilitiesForTask(task);
      if (required.isEmpty) continue;
      if (isLocal) {
        if (runtime != null &&
            runtime.available &&
            platformSupported &&
            artifactsReady &&
            runtime.capabilities.containsAll(required)) {
          executable.add(task);
        }
      } else if (isRemote) {
        executable.add(task);
      }
    }
    executable.sort((left, right) => left.index.compareTo(right.index));

    final executableSet = executable.toSet();
    final modalities = <AiModality>{
      for (final task in executableSet) ...{
        ...task.inputModalities,
        ...task.outputModalities,
      },
    };
    final supportedModalities = <AiModality>{
      for (final task in supported) ...{
        ...task.inputModalities,
        ...task.outputModalities,
      },
    };

    final portability = <String>{};
    if (isLocal) {
      portability.add('local');
      portability.addAll(
        runtime?.platforms.isEmpty == true
            ? const ['android', 'ios', 'macos', 'windows', 'linux']
            : runtime?.platforms ?? const <String>{},
      );
    } else {
      portability.add('remote');
    }

    return ModelTags(
      supportedTasks: List.unmodifiable(supported.toList()),
      executableTasks: List.unmodifiable(executable),
      modalities: Set.unmodifiable(modalities),
      supportedModalities: Set.unmodifiable(supportedModalities),
      portability: Set.unmodifiable(portability),
      runtimeId: isLocal ? model.providerId : null,
    );
  }
}
