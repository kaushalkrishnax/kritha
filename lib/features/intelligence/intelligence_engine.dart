import 'intelligence_exception.dart';
import 'models/ai_request.dart';
import 'models/ai_response.dart';
import 'request_router.dart';

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
    required this.modelLoaded,
  });

  final String providerId;
  final String modelId;
  final bool modelConfigured;
  final bool modelLoaded;
}

/// Application-facing entry point for local inference.
///
/// Widgets depend on this class only; they never see provider or runtime
/// objects.
class IntelligenceEngine {
  const IntelligenceEngine({required this.router});

  final RequestRouter router;

  IntelligenceStatus get status => IntelligenceStatus(
    providers: [
      for (final provider in router.providers)
        InferenceProviderStatus(
          providerId: provider.id,
          modelId: provider.descriptor.id,
          modelConfigured:
              provider.descriptor.modelPath?.trim().isNotEmpty ?? false,
          modelLoaded: provider.isInitialized,
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

  void _validate(AiRequest request) {
    if (request.messages.isEmpty) {
      throw const InvalidRequestException(
        'An inference request needs at least one message.',
      );
    }

    final last = request.messages.last;
    if (last.role != AiRole.user) {
      throw const InvalidRequestException(
        'An inference request must end with a user message.',
      );
    }
    if (last.text.trim().isEmpty) {
      throw const InvalidRequestException(
        'The final user message must not be empty.',
      );
    }

    final options = request.options;
    if (!options.temperature.isFinite || options.temperature < 0) {
      throw const InvalidRequestException(
        'Temperature must be a finite, non-negative value.',
      );
    }
    if (!options.topP.isFinite || options.topP <= 0 || options.topP > 1) {
      throw const InvalidRequestException('Top-p must be within (0, 1].');
    }
    if (options.topK <= 0) {
      throw const InvalidRequestException('Top-k must be positive.');
    }
    if (options.seed < 0) {
      throw const InvalidRequestException('Seed must not be negative.');
    }
    final maxOutputTokens = options.maxOutputTokens;
    if (maxOutputTokens != null && maxOutputTokens <= 0) {
      throw const InvalidRequestException(
        'Max output tokens must be positive when set.',
      );
    }
  }
}
