import 'inference_provider.dart';
import 'intelligence_exception.dart';
import 'models/ai_request.dart';
import 'models/model_capabilities.dart';

/// Persisted Active Models choice for one inference capability.
class ActiveInferenceTarget {
  const ActiveInferenceTarget({
    required this.providerId,
    required this.modelId,
  });

  final String providerId;
  final String modelId;
}

/// Routes request to provider configured in Active Models without fallback or retry.
class RequestRouter {
  const RequestRouter({required this.providers, this.activeModels = const {}});

  final List<InferenceProvider> providers;

  /// Active model and provider mapped per capability.
  final Map<InferenceCapability, ActiveInferenceTarget> activeModels;

  InferenceProvider resolve(AiRequest request) {
    if (providers.isEmpty) {
      throw const ProviderUnavailableException(
        'No active model is assigned for this request.',
      );
    }

    final requestedModel = request.modelId;
    final active = activeModels[InferenceCapability.textGeneration];
    final List<InferenceProvider> candidates;

    if (requestedModel != null) {
      candidates = active != null && active.modelId == requestedModel
          ? _forTarget(active)
          : providers
                .where((provider) => provider.descriptor.id == requestedModel)
                .toList(growable: false);
      if (candidates.length > 1) {
        throw ProviderUnavailableException(
          'The model "$requestedModel" is provided by more than one provider. '
          'Select it in Active Models so the provider is unambiguous.',
        );
      }
    } else if (active != null) {
      candidates = _forTarget(active);
    } else {
      candidates = providers;
    }

    if (candidates.isEmpty) {
      throw ProviderUnavailableException(
        requestedModel == null && active == null
            ? 'No active model is assigned for this request.'
            : requestedModel != null
            ? 'The requested model "$requestedModel" is no longer available.'
            : 'The active model "${active!.modelId}" is no longer available '
                  'from its provider.',
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

  List<InferenceProvider> _forTarget(ActiveInferenceTarget target) {
    return providers
        .where(
          (provider) =>
              provider.id == target.providerId &&
              provider.descriptor.id == target.modelId,
        )
        .toList(growable: false);
  }
}
