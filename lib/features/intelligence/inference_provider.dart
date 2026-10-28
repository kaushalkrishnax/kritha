import 'package:flutter/foundation.dart';

import 'models/ai_request.dart';
import 'models/ai_response.dart';
import 'models/model_descriptor.dart';

/// Where an inference provider is in its native lifecycle.
///
/// [fileReady] only means configuration points at a validated file. It never
/// means the runtime loaded the weights, and none of these states imply that a
/// generation succeeded.
enum EngineLifecycleStage {
  fileReady,
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

  final EngineLifecycleStage stage;

  /// A short, user-safe explanation for a failed state.
  final String? message;

  bool get isInitialized => stage == EngineLifecycleStage.initialized;

  bool get isInitializing => stage == EngineLifecycleStage.initializing;

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

/// A runtime that can execute inference for one model.
///
/// Implementations own native resources. [initialize] loads the runtime and
/// model; [generate] and [stream] must be safe to call afterwards, and
/// [dispose] must be idempotent. Errors surface as [IntelligenceException]
/// subtypes.
abstract interface class InferenceProvider {
  String get id;

  ModelDescriptor get descriptor;

  /// Observable lifecycle. It is safe to inspect without loading the model.
  ValueListenable<EngineLifecycle> get lifecycle;

  /// Whether the runtime and model are loaded in this process. This says
  /// nothing about whether a generation has succeeded.
  bool get isInitialized;

  Future<void> initialize();

  /// Runs one request to completion.
  Future<AiResponse> generate(AiRequest request);

  /// Runs one request and emits output as it is produced.
  ///
  /// Each event is a cumulative partial snapshot, not a completed response.
  /// Completion is signalled only by the stream closing normally. Cancelling
  /// the subscription must stop native generation; the runtime may keep the
  /// loaded model for later requests.
  Stream<AiResponse> stream(AiRequest request);

  Future<void> dispose();
}
