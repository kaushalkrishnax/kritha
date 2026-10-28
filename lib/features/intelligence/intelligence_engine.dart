import 'inference_provider.dart';
import 'models/ai_request.dart';
import 'models/ai_response.dart';
import 'request_router.dart';
import 'request_validation.dart';

/// Snapshot of what the intelligence layer is configured to do.
///
/// It never reports successful inference: that claim requires an actual
/// generation result.
class IntelligenceStatus {
  const IntelligenceStatus({required this.providers});

  final List<InferenceProviderStatus> providers;

  bool get hasProvider => providers.isNotEmpty;

  bool get hasConfiguredModel =>
      providers.any((provider) => provider.modelConfigured);

  bool get hasLoadedModel => providers.any((provider) => provider.modelLoaded);
}

class InferenceProviderStatus {
  const InferenceProviderStatus({
    required this.providerId,
    required this.modelId,
    required this.modelConfigured,
    required this.lifecycle,
  });

  final String providerId;
  final String modelId;
  final bool modelConfigured;
  final EngineLifecycle lifecycle;

  bool get modelLoaded => lifecycle.isInitialized;
}

/// Application-facing entry point for local inference.
///
/// Widgets depend on this class only; they never see provider or runtime
/// objects.
class IntelligenceEngine {
  const IntelligenceEngine({
    required this.router,
    this.validator = const AiRequestValidator(),
  });

  final RequestRouter router;
  final AiRequestValidator validator;

  IntelligenceStatus get status => IntelligenceStatus(
    providers: [
      for (final provider in router.providers)
        InferenceProviderStatus(
          providerId: provider.id,
          modelId: provider.descriptor.id,
          modelConfigured:
              provider.descriptor.modelPath?.trim().isNotEmpty ?? false,
          lifecycle: provider.lifecycle.value,
        ),
    ],
  );

  Future<AiResponse> generate(AiRequest request) async {
    _validate(request);
    return router.resolve(request).generate(request);
  }

  /// Streams a request through the same validation and routing as [generate].
  Stream<AiResponse> stream(AiRequest request) {
    _validate(request);
    return router.resolve(request).stream(request);
  }

  void _validate(AiRequest request) => validator.validate(request);
}
