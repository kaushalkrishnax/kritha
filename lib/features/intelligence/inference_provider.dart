import 'models/ai_request.dart';
import 'models/ai_response.dart';
import 'models/model_descriptor.dart';

/// A runtime that can execute inference for one model.
///
/// Implementations own native resources. [initialize] loads the runtime and
/// model; [generate] and [stream] must be safe to call afterwards, and
/// [dispose] must be idempotent. Errors surface as [IntelligenceException]
/// subtypes.
abstract interface class InferenceProvider {
  String get id;

  ModelDescriptor get descriptor;

  /// Whether the runtime and model are loaded in this process. This says
  /// nothing about whether a generation has succeeded.
  bool get isInitialized;

  Future<void> initialize();

  /// Runs one request to completion.
  Future<AiResponse> generate(AiRequest request);

  /// Runs one request and emits output as it is produced.
  ///
  /// Each event carries the complete text generated so far, not just the latest
  /// delta. Cancelling the subscription must stop native generation; the
  /// runtime may keep the loaded model for later requests.
  Stream<AiResponse> stream(AiRequest request);

  Future<void> dispose();
}
