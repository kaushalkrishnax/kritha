import 'inference_provider.dart';
import 'models/ai_request.dart';
import 'models/ai_response.dart';
import 'request_router.dart';
import 'request_validation.dart';

/// Configured intelligence layer snapshot; does not imply successful inference.
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

/// Application-facing inference entry point abstracting model providers and runtimes.
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
          modelConfigured: provider.lifecycle.value.isConfigured,
          lifecycle: provider.lifecycle.value,
        ),
    ],
  );

  Future<AiResponse> generate(AiRequest request) async {
    _validate(request);
    return router.resolve(request).generate(request);
  }

  /// Streams request through shared validation and routing.
  Stream<AiResponse> stream(AiRequest request) {
    _validate(request);
    return router.resolve(request).stream(request);
  }

  void _validate(AiRequest request) => validator.validate(request);
}
