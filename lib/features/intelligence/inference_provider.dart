import 'package:flutter/foundation.dart';

export 'providers/provider.dart';

/// Native lifecycle state of an inference provider.
enum EngineLifecycleStage {
  fileReady,

  /// Remote provider configured and ready without local engine load.
  ready,
  initializing,
  initialized,
  initializationFailed,
  unavailable,
  disposed,
}

@immutable
class EngineLifecycle {
  const EngineLifecycle(this.stage, {this.message});

  const EngineLifecycle.fileReady() : this(EngineLifecycleStage.fileReady);

  const EngineLifecycle.ready() : this(EngineLifecycleStage.ready);

  final EngineLifecycleStage stage;

  /// User-safe explanation for failed state.
  final String? message;

  bool get isInitialized => stage == EngineLifecycleStage.initialized;

  bool get isInitializing => stage == EngineLifecycleStage.initializing;

  bool get isReady =>
      stage == EngineLifecycleStage.ready ||
      stage == EngineLifecycleStage.fileReady ||
      stage == EngineLifecycleStage.initialized;

  bool get isConfigured =>
      stage != EngineLifecycleStage.unavailable &&
      stage != EngineLifecycleStage.initializationFailed &&
      stage != EngineLifecycleStage.disposed;

  @override
  bool operator ==(Object other) {
    return other is EngineLifecycle &&
        other.stage == stage &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(stage, message);

  @override
  String toString() => 'EngineLifecycle(${stage.name})';
}
