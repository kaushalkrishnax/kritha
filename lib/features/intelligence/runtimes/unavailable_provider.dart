import 'package:flutter/foundation.dart';

import '../inference_provider.dart';
import '../intelligence_exception.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';
import '../models/model_descriptor.dart';

/// A resolved assignment whose source can no longer execute it.
///
/// Keeping a placeholder in the provider list lets routing stay deterministic:
/// the active model is still the target, and the request fails with a specific
/// reason instead of silently choosing another model.
class UnavailableInferenceProvider implements InferenceProvider {
  UnavailableInferenceProvider({
    required this.id,
    required this.descriptor,
    required this.message,
  }) : _lifecycle = ValueNotifier(
         EngineLifecycle(EngineLifecycleStage.unavailable, message: message),
       );

  @override
  final String id;

  @override
  final ModelDescriptor descriptor;

  final String message;
  final ValueNotifier<EngineLifecycle> _lifecycle;

  @override
  ValueListenable<EngineLifecycle> get lifecycle => _lifecycle;

  @override
  bool get isInitialized => false;

  @override
  Future<void> initialize() =>
      Future.error(ProviderUnavailableException(message, providerId: id));

  @override
  Future<AiResponse> generate(AiRequest request) async {
    throw ProviderUnavailableException(message, providerId: id);
  }

  @override
  Stream<AiResponse> stream(AiRequest request) async* {
    throw ProviderUnavailableException(message, providerId: id);
  }

  @override
  Future<void> dispose() async {
    _lifecycle.value = const EngineLifecycle(EngineLifecycleStage.disposed);
    _lifecycle.dispose();
  }
}
