import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/active/active_models.dart';
import '../models/catalogue/catalogue_model.dart';
import '../providers/provider_stores.dart';
import '../providers/provider_usage.dart';
import '../providers/providers_controller.dart';
import 'capability_mapping.dart';
import 'inference_provider.dart';
import 'intelligence_engine.dart';
import 'intelligence_exception.dart';
import 'model_configuration.dart';
import 'model_lifecycle.dart';
import 'models/model_capabilities.dart';
import 'models/model_descriptor.dart';
import 'remote/anthropic_provider.dart';
import 'remote/openai_compatible_provider.dart';
import 'request_router.dart';
import 'runtime_ids.dart';
import 'runtimes/litertlm_provider.dart';
import 'runtimes/unavailable_provider.dart';
import 'usage_tracking_provider.dart';

/// The validated local model, retained for Settings and migration.
///
/// Active inference uses the assignment graph below; this provider is not an
/// independent source of model selection once an assignment exists.
final configuredModelProvider = Provider<ModelDescriptor?>((ref) {
  final configuration = ref.watch(modelConfigurationProvider);
  if (configuration.hasError) return null;
  return configuration.value?.descriptor;
});

/// Builds the native engine for a descriptor. Tests override this with a fake
/// so the provider graph never touches a model or native library.
final liteRtLmEngineFactoryProvider =
    Provider<LiteRtLmEngine Function(ModelDescriptor)>((ref) {
      return (model) {
        final path = model.modelPath;
        if (path == null || path.trim().isEmpty) {
          throw ProviderUnavailableException(
            'No model file is configured for ${model.id}.',
            providerId: LiteRtLmProvider.sourceId,
          );
        }
        final validated = ModelConfiguration.validate(path);
        if (!validated.isReady) {
          throw ProviderUnavailableException(
            validated.message ?? 'The selected local model is not available.',
            providerId: LiteRtLmProvider.sourceId,
          );
        }
        return NativeLiteRtLmEngine(modelPath: path);
      };
    });

/// Transport factory for remote adapters. Tests inject mocked HTTP clients.
final inferenceHttpClientFactoryProvider = Provider<http.Client Function()>(
  (ref) => http.Client.new,
);

/// Persisted assignments, normalized so loading and an empty store are the
/// same dependency value.
final activeAssignmentsProvider =
    Provider<Map<ModelCapability, ActiveModelAssignment>>((ref) {
      final assignments = ref.watch(
        activeModelsProvider.select(
          (value) => value.value?.assignments ?? const {},
        ),
      );
      return assignments.isEmpty ? const {} : assignments;
    });

/// Active model/provider pairs keyed by the inference capability they serve.
///
/// A validated local model is exposed as a legacy text assignment when no text
/// assignment exists. This is an explicit migration policy, not a fallback for
/// a stale or broken assignment.
final activeInferenceTargetsProvider =
    Provider<Map<InferenceCapability, ActiveInferenceTarget>>((ref) {
      final assignments = ref.watch(activeAssignmentsProvider);
      final legacyLocal = ref.watch(configuredModelProvider);

      final result = <InferenceCapability, ActiveInferenceTarget>{};
      for (final entry in assignments.entries) {
        for (final capability in inferenceCapabilitiesFor(entry.key)) {
          result[capability] = ActiveInferenceTarget(
            providerId: entry.value.sourceId,
            modelId: entry.value.modelId,
          );
        }
      }
      if (!assignments.containsKey(ModelCapability.text) &&
          legacyLocal != null) {
        result[InferenceCapability.textGeneration] = ActiveInferenceTarget(
          providerId: localProviderId,
          modelId: legacyLocal.id,
        );
      }
      return Map.unmodifiable(result);
    });

/// Every backend the router may select, built from Active Models.
///
/// Assignments are authoritative. A stale local file, removed provider or
/// unsupported capability produces an unavailable placeholder rather than a
/// different model.
final inferenceProvidersProvider = Provider<List<InferenceProvider>>((ref) {
  final persisted = ref.watch(activeAssignmentsProvider);
  final legacyLocal = ref.watch(configuredModelProvider);
  final hasRemote = persisted.values.any(
    (assignment) => assignment.sourceId != localProviderId,
  );
  final providersAsync = hasRemote
      ? ref.watch(providersControllerProvider)
      : null;
  final providersState = providersAsync?.value;
  final createEngine = ref.watch(liteRtLmEngineFactoryProvider);
  final clientFactory = ref.watch(inferenceHttpClientFactoryProvider);
  final credentials = ref.read(providerCredentialStoreProvider);

  final assignments = <ModelCapability, ActiveModelAssignment>{...persisted};
  if (!assignments.containsKey(ModelCapability.text) && legacyLocal != null) {
    assignments[ModelCapability.text] = ActiveModelAssignment(
      capability: ModelCapability.text,
      modelId: legacyLocal.id,
      displayName: legacyLocal.displayName,
      runtimeId: legacyLocal.runtimeId,
      sourceId: localProviderId,
      activatedAt: DateTime.now(),
    );
  }
  if (assignments.isEmpty) return const [];

  final providers = <InferenceProvider>[];
  for (final entry in assignments.entries) {
    final assignment = entry.value;
    final capabilities = modelCapabilitiesFor(assignment.capability);

    if (assignment.sourceId == localProviderId) {
      final model = legacyLocal;
      if (entry.key != ModelCapability.text ||
          model == null ||
          assignment.modelId != model.id ||
          assignment.runtimeId != model.runtimeId) {
        providers.add(
          UnavailableInferenceProvider(
            id: localProviderId,
            descriptor: ModelDescriptor(
              id: assignment.modelId,
              displayName: assignment.displayName,
              runtimeId: assignment.runtimeId,
              capabilities: capabilities,
            ),
            message:
                'The assigned local model is no longer available. '
                'Choose a validated local model in Active Models.',
          ),
        );
        continue;
      }
      final provider = LiteRtLmProvider(
        descriptor: model,
        createEngine: () => createEngine(model),
      );
      ref.onDispose(provider.dispose);
      providers.add(provider);
      continue;
    }

    final configuration = providersState?.configurationFor(assignment.sourceId);
    final definition = configuration?.definition;
    if (definition == null || configuration == null) {
      providers.add(
        UnavailableInferenceProvider(
          id: assignment.sourceId,
          descriptor: ModelDescriptor(
            id: assignment.modelId,
            displayName: assignment.displayName,
            runtimeId: assignment.runtimeId,
            capabilities: capabilities,
          ),
          message: providersAsync?.isLoading == true
              ? 'Provider configuration is still loading. Try again.'
              : 'The provider for ${assignment.displayName} is no longer '
                    'configured. Reconnect it or choose another model.',
        ),
      );
      continue;
    }
    if (capabilities.supported.isEmpty) {
      providers.add(
        UnavailableInferenceProvider(
          id: assignment.sourceId,
          descriptor: ModelDescriptor(
            id: assignment.modelId,
            displayName: assignment.displayName,
            runtimeId: definition.runtimeId,
            capabilities: capabilities,
          ),
          message: '${entry.key.label} has no inference adapter in this build.',
        ),
      );
      continue;
    }

    final descriptor = ModelDescriptor(
      id: assignment.modelId,
      displayName: assignment.displayName,
      runtimeId: definition.runtimeId,
      capabilities: capabilities,
    );
    Future<String?> readCredential() => credentials.read(assignment.sourceId);
    final adapter = switch (definition.runtimeId) {
      anthropicRuntimeId => AnthropicProvider(
        sourceId: assignment.sourceId,
        descriptor: descriptor,
        baseUrl: configuration.baseUrl,
        readCredential: readCredential,
        requiresCredential: definition.requiresCredential,
        clientFactory: clientFactory,
      ),
      _ => OpenAiCompatibleProvider(
        sourceId: assignment.sourceId,
        descriptor: descriptor,
        baseUrl: configuration.baseUrl,
        readCredential: readCredential,
        requiresCredential: definition.requiresCredential,
        clientFactory: clientFactory,
      ),
    };
    final provider = UsageTrackingInferenceProvider(
      inner: adapter,
      onRequestSettled: (ok) {
        if (!ref.mounted) return;
        ref
            .read(providerUsageProvider.notifier)
            .record(assignment.sourceId, ok: ok);
      },
    );
    ref.onDispose(provider.dispose);
    providers.add(provider);
  }

  return List<InferenceProvider>.unmodifiable(providers);
});

final requestRouterProvider = Provider<RequestRouter>(
  (ref) => RequestRouter(
    providers: ref.watch(inferenceProvidersProvider),
    activeModels: ref.watch(activeInferenceTargetsProvider),
  ),
);

final intelligenceEngineProvider = Provider<IntelligenceEngine>(
  (ref) => IntelligenceEngine(router: ref.watch(requestRouterProvider)),
);

/// Observable diagnostics for Settings.
///
/// Watching this provider never initializes a native engine; it only combines
/// configuration validation with the lifecycle the provider has reported.
final modelLifecycleProvider =
    NotifierProvider<ModelLifecycleNotifier, ModelLifecycle>(
      ModelLifecycleNotifier.new,
    );

class ModelLifecycleNotifier extends Notifier<ModelLifecycle> {
  final List<void Function()> _detach = [];
  int _revision = 0;

  @override
  ModelLifecycle build() {
    final revision = ++_revision;
    final configuration = ref.watch(modelConfigurationProvider);
    final providers = ref.watch(inferenceProvidersProvider);
    final activeTargets = ref.watch(activeInferenceTargetsProvider);
    final activeTarget = activeTargets[InferenceCapability.textGeneration];
    ref.onDispose(_detachListeners);
    _detachListeners();

    ModelLifecycle snapshot() => ModelLifecycle.evaluate(
      configuration: configuration.value,
      configurationLoading: configuration.isLoading,
      configurationFailed: configuration.hasError,
      providers: providers,
      activeProviderId: activeTarget?.providerId,
      activeModelId: activeTarget?.modelId,
    );

    for (final provider in providers) {
      void onChange() {
        // Disposal happens while Riverpod runs provider callbacks; the
        // provider graph is rebuilt without this provider anyway.
        if (provider.lifecycle.value.stage == EngineLifecycleStage.disposed) {
          return;
        }
        if (ref.mounted && revision == _revision) state = snapshot();
      }

      provider.lifecycle.addListener(onChange);
      _detach.add(() => provider.lifecycle.removeListener(onChange));
    }

    return snapshot();
  }

  void _detachListeners() {
    for (final detach in _detach) {
      detach();
    }
    _detach.clear();
  }
}

final intelligenceStatusProvider = Provider<IntelligenceStatus>((ref) {
  // Rebuild when the engine lifecycle changes, not only when configuration
  // changes.
  ref.watch(modelLifecycleProvider);
  return ref.watch(intelligenceEngineProvider).status;
});
