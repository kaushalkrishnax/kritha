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
import 'local_inference_provider.dart';
import 'model_configuration.dart';
import 'model_lifecycle.dart';
import 'models/model_capabilities.dart';
import 'models/model_descriptor.dart';
import 'models/task_registry.dart';
import 'remote/anthropic_provider.dart';
import 'remote/openai_compatible_provider.dart';
import 'request_router.dart';
import 'runtime_ids.dart';
import 'runtime_registry.dart';
import 'runtimes/litertlm_provider.dart';
import 'runtimes/unavailable_provider.dart';
import 'usage_tracking_provider.dart';

/// Validated local model, retained for Settings and migration.
final configuredModelProvider = Provider<ModelDescriptor?>((ref) {
  final configuration = ref.watch(modelConfigurationProvider);
  if (configuration.hasError) return null;
  return configuration.value?.descriptor;
});

/// Builds native engine for a descriptor; test overrides inject fakes.
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

final localRuntimeRegistryProvider = Provider<RuntimeRegistry>((ref) {
  final createEngine = ref.watch(liteRtLmEngineFactoryProvider);
  return RuntimeRegistry(
    registrations: [liteRtLmRuntimeRegistration(createEngine: createEngine)],
  );
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
final activeInferenceTargetsProvider =
    Provider<Map<InferenceCapability, ActiveInferenceTarget>>((ref) {
      final assignments = ref.watch(activeAssignmentsProvider);
      final legacyLocal = ref.watch(configuredModelProvider);

      final result = <InferenceCapability, ActiveInferenceTarget>{};
      final entries = assignments.entries.toList()
        ..sort(
          (left, right) =>
              (right.value.isMultimodal ? 1 : 0) -
              (left.value.isMultimodal ? 1 : 0),
        );
      for (final entry in entries) {
        final taskIds = entry.value.enabledTaskIds.isEmpty
            ? [entry.value.canonicalTaskId]
            : entry.value.enabledTaskIds;
        final capabilities = <InferenceCapability>{};
        for (final taskId in taskIds) {
          final routingCapability = routingCapabilityForTaskId(taskId);
          if (routingCapability != null) {
            capabilities.add(routingCapability);
          }
        }
        if (capabilities.isEmpty) {
          capabilities.addAll(inferenceCapabilitiesFor(entry.key));
        }
        for (final capability in capabilities) {
          if (!entry.value.isMultimodal && result.containsKey(capability)) {
            continue;
          }
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
    final capabilities = _modelCapabilitiesForAssignment(assignment, entry.key);

    if (assignment.sourceId == localProviderId) {
      final model = legacyLocal;
      if (entry.key != ModelCapability.text ||
          assignment.enabledTaskIds.any(
            (taskId) => taskId != AiTaskId.textGeneration.id,
          ) ||
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
      final registry = ref.watch(localRuntimeRegistryProvider);
      final provider = LocalInferenceProvider(
        descriptor: model,
        providerId: localProviderId,
        registry: registry,
        artifacts: [
          LocalModelArtifact(path: model.modelPath!, format: 'litertlm'),
        ],
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

ModelCapabilities _modelCapabilitiesForAssignment(
  ActiveModelAssignment assignment,
  ModelCapability legacyCapability,
) {
  final taskIds = assignment.enabledTaskIds.isEmpty
      ? [assignment.canonicalTaskId]
      : assignment.enabledTaskIds;
  final capabilities = <InferenceCapability>{};
  for (final taskId in taskIds) {
    capabilities.addAll(inferenceCapabilitiesForTaskId(taskId));
  }
  if (capabilities.isEmpty) {
    capabilities.addAll(inferenceCapabilitiesFor(legacyCapability));
  }
  return ModelCapabilities(supported: capabilities);
}

final requestRouterProvider = Provider<RequestRouter>(
  (ref) => RequestRouter(
    providers: ref.watch(inferenceProvidersProvider),
    activeModels: ref.watch(activeInferenceTargetsProvider),
  ),
);

final intelligenceEngineProvider = Provider<IntelligenceEngine>(
  (ref) => IntelligenceEngine(router: ref.watch(requestRouterProvider)),
);

/// Observable diagnostics for Settings combining config validation and reported lifecycle.
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
        // Disposal runs during Riverpod callbacks while rebuilding provider graph.
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
  ref.watch(modelLifecycleProvider);
  return ref.watch(intelligenceEngineProvider).status;
});
