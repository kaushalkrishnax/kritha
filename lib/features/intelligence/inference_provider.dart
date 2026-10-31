import 'package:flutter/foundation.dart';

import 'models/ai_request.dart';
import 'models/ai_response.dart';
import 'models/model_descriptor.dart';

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

/// Runtime executing inference for one model with managed native resources.
abstract interface class InferenceProvider {
  String get id;

  ModelDescriptor get descriptor;

  /// Observable lifecycle; safe to inspect without loading model.
  ValueListenable<EngineLifecycle> get lifecycle;

  /// Whether runtime and model are loaded in memory.
  bool get isInitialized;

  Future<void> initialize();

  Future<AiResponse> generate(AiRequest request);

  /// Streams cumulative partial snapshots; cancelling subscription stops native generation.
  Stream<AiResponse> stream(AiRequest request);

  Future<void> dispose();
}
