import 'inference_provider.dart';
import 'intelligence_exception.dart';
import 'models/ai_request.dart';

/// Selects the first configured provider that can serve a request.
///
/// There is deliberately no fallback, retry or load balancing yet: one local
/// provider is the only case Phase 1 needs.
class RequestRouter {
  const RequestRouter({required this.providers});

  final List<InferenceProvider> providers;

  InferenceProvider resolve(AiRequest request) {
    if (providers.isEmpty) {
      throw const ProviderUnavailableException(
        'No inference provider is configured.',
      );
    }

    final requestedModel = request.modelId;
    final candidates = requestedModel == null
        ? providers
        : providers
              .where((provider) => provider.descriptor.id == requestedModel)
              .toList(growable: false);

    if (candidates.isEmpty) {
      throw ProviderUnavailableException(
        'No configured provider serves model "$requestedModel".',
      );
    }

    final required = request.requiredCapabilities;
    for (final provider in candidates) {
      if (provider.descriptor.capabilities.supportsAll(required)) {
        return provider;
      }
    }

    final provider = candidates.first;
    throw UnsupportedCapabilityException(
      providerId: provider.id,
      missing: required
          .where(
            (capability) =>
                !provider.descriptor.capabilities.supports(capability),
          )
          .toSet(),
    );
  }
}
