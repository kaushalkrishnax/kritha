import 'dart:async';

import '../../../models/model_record.dart';
import 'models/ai_request.dart';
import 'models/ai_response.dart';
import 'models/model_capabilities.dart';
import 'models/task_registry.dart';
import 'request_validation.dart';
import 'inference_provider.dart';
import './providers/provider_registry.dart';
import '../models/model_record_store.dart';
import 'intelligence_exception.dart';
import '../models/setup/model_artifact_storage.dart';

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
    required this.alias,
    required this.modelId,
    required this.modelConfigured,
    required this.lifecycle,
  });

  final String providerId;
  final String alias;
  final String modelId;
  final bool modelConfigured;
  final EngineLifecycle lifecycle;

  bool get modelLoaded => lifecycle.isInitialized;
}

/// Application-facing inference entry point.
///
/// Resolves a model by its internal UUID, reads its provider, and delegates
/// execution to the registered provider implementation. Provider-specific
/// details are never exposed to callers.
class IntelligenceEngine {
  IntelligenceEngine({
    required this.modelRepository,
    required this.registry,
    required this.documentsPath,
    this.validator = const AiRequestValidator(),
    this.activeModelResolver,
  });

  final ModelRepository modelRepository;
  final ProviderRegistry registry;
  final Future<String> documentsPath;
  final AiRequestValidator validator;
  final Future<String?> Function(AiTaskId task)? activeModelResolver;

  final Map<String, InferenceProvider> _instances = {};

  IntelligenceStatus get status => IntelligenceStatus(
    providers: [
      for (final entry in _instances.entries)
        InferenceProviderStatus(
          providerId: entry.key,
          alias: entry.value.alias,
          modelId: '',
          modelConfigured: entry.value.lifecycle.value.isConfigured,
          lifecycle: entry.value.lifecycle.value,
        ),
    ],
  );

  /// Resolves (and caches) the implementation for a provider record.
  Future<InferenceProvider> _providerFor(String providerId) async {
    final config = await modelRepository.providerConfigFor(providerId);
    if (config == null) {
      throw ProviderUnavailableException(
        'The provider for model execution is no longer configured.',
        providerId: providerId,
      );
    }
    final existing = _instances[providerId];
    if (existing != null) return existing;
    final implementation = registry.createProvider(config);
    _instances[providerId] = implementation;
    return implementation;
  }

  Future<AiResponse> generate(AiRequest request) async {
    _validate(request);
    final providerModel = await _resolveProviderModel(request);
    final provider = await _providerFor(providerModel.providerId);
    return provider.generate(request, providerModel);
  }

  /// Streams request through shared validation and routing.
  Stream<AiResponse> stream(AiRequest request) async* {
    _validate(request);
    final providerModel = await _resolveProviderModel(request);
    final provider = await _providerFor(providerModel.providerId);
    await for (final response in provider.stream(request, providerModel)) {
      yield response;
    }
  }

  /// Discovers models exposed by the given provider record.
  Future<List<DiscoveredModel>> discoverModelsForProvider(String providerId) async {
    final provider = await _providerFor(providerId);
    return provider.discoverModels();
  }

  /// Tests the provider configuration or runtime through the common contract.
  Future<ProviderTestResult> testProvider(String providerId) async {
    final provider = await _providerFor(providerId);
    return provider.test();
  }

  Future<ProviderModel> _resolveProviderModel(AiRequest request) async {
    var modelId = request.modelId;
    if (modelId == null || modelId.trim().isEmpty) {
      if (activeModelResolver != null) {
        modelId = await activeModelResolver!(
          request.requestedTask ?? AiTaskId.textGeneration,
        );
      }
    }
    if (modelId == null || modelId.trim().isEmpty) {
      throw const ProviderUnavailableException(
        'No model is selected for inference.',
        providerId: '',
      );
    }
    final model = await modelRepository.findById(modelId);
    if (model == null) {
      throw ProviderUnavailableException(
        'The model "$modelId" is not available.',
        providerId: '',
      );
    }
    final providerId = model.providerId;
    await _providerFor(providerId); // throws if provider unknown

    String? modelPath;
    if (await _isLocalProvider(providerId)) {
      modelPath = await _resolveModelPath(model);
    }

    return ProviderModel(
      id: model.id,
      providerId: providerId,
      externalModelId: model.externalModelId,
      displayName: model.displayName,
      capabilities: _capabilitiesFor(model.tasks),
      tasks: model.tasks,
      modelPath: modelPath,
      artifacts: await modelRepository.artifactsFor(model.id),
      metadata: model.metadata,
    );
  }

  Future<bool> _isLocalProvider(String providerId) async {
    final config = await modelRepository.providerConfigFor(providerId);
    return config?.isLocal ?? false;
  }

  Future<String?> _resolveModelPath(ModelRecord model) async {
    final docPath = await documentsPath;
    if (docPath.trim().isEmpty) return null;
    final artifacts = await modelRepository.artifactsFor(model.id);
    final resolved = ModelArtifactStorageResolver(docPath).resolve(
      artifacts,
    );
    final weights = resolved.where((file) => file.artifact.kind == 'weights');
    final target = weights.isNotEmpty ? weights.first : resolved.firstOrNull;
    return target?.absolutePath;
  }

  Set<InferenceCapability> _capabilitiesFor(List<TaskDeclaration> tasks) {
    final result = <InferenceCapability>{};
    for (final declaration in tasks) {
      result.addAll(capabilitiesForTask(declaration.task));
    }
    return result;
  }

  void _validate(AiRequest request) => validator.validate(request);

  /// Disposes every cached provider instance.
  Future<void> disposeAll() async {
    final instances = [..._instances.values];
    _instances.clear();
    for (final provider in instances) {
      await provider.dispose();
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
