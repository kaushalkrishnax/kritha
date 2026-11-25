import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import 'usage_tracking_provider.dart';

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
    if (existing != null) {
      final sameConfig =
          existing.config.alias == config.alias &&
          existing.config.baseUrl == config.baseUrl &&
          existing.config.apiKey == config.apiKey;
      if (sameConfig) return existing;
      _instances.remove(providerId);
      unawaited(existing.dispose());
    }
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

  Future<GeneratedImage> generateImage({
    required String prompt,
    required String modelId,
  }) async {
    final providerModel = await _resolveModelById(modelId);
    final media = await _mediaProviderFor(providerModel.providerId);
    return media.generateImage(prompt, providerModel);
  }

  Future<String> transcribeAudio({
    required Uint8List bytes,
    required String mimeType,
    required String modelId,
  }) async {
    final providerModel = await _resolveModelById(modelId);
    final media = await _mediaProviderFor(providerModel.providerId);
    return media.transcribeAudio(bytes, mimeType, providerModel);
  }

  Future<SynthesizedSpeech> synthesizeSpeech({
    required String text,
    required String modelId,
  }) async {
    final providerModel = await _resolveModelById(modelId);
    final media = await _mediaProviderFor(providerModel.providerId);
    return media.synthesizeSpeech(text, providerModel);
  }

  /// Identity of a synthesis request. Provider, model and model metadata are
  /// included because any of them can change the generated voice or audio.
  Future<String> synthesizeSpeechCacheKey({
    required String text,
    required String modelId,
  }) async {
    final providerModel = await _resolveModelById(modelId);
    final config = await modelRepository.providerConfigFor(
      providerModel.providerId,
    );
    final signature = [
      providerModel.providerId,
      config?.alias ?? '',
      config?.baseUrl ?? '',
      providerModel.externalModelId,
      jsonEncode(providerModel.metadata),
    ].join('|');
    return '$signature|$text';
  }

  Future<MediaCapableProvider> _mediaProviderFor(String providerId) async {
    var provider = await _providerFor(providerId);
    if (provider is UsageTrackingInferenceProvider) {
      provider = provider.inner;
    }
    if (provider is MediaCapableProvider) {
      return provider as MediaCapableProvider;
    }
    throw ProviderUnavailableException(
      'This provider does not support media operations.',
      providerId: providerId,
    );
  }

  Future<ProviderModel> _resolveModelById(String modelId) async {
    final model = await modelRepository.findById(modelId);
    if (model == null) {
      throw ProviderUnavailableException(
        'The model "$modelId" is not available.',
        providerId: '',
      );
    }
    return ProviderModel(
      id: model.id,
      providerId: model.providerId,
      externalModelId: model.externalModelId,
      displayName: model.displayName,
      capabilities: _capabilitiesFor(model.tasks),
      tasks: model.tasks,
      artifacts: await modelRepository.artifactsFor(model.id),
      metadata: model.metadata,
    );
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
    final readySelectedWeights = resolved.where(
      (file) =>
          file.selected && file.exists && file.artifact.kind == 'weights',
    );
    if (readySelectedWeights.isNotEmpty) {
      return readySelectedWeights.first.absolutePath;
    }
    final readyWeights = resolved.where(
      (file) => file.exists && file.artifact.kind == 'weights',
    );
    if (readyWeights.isNotEmpty) return readyWeights.first.absolutePath;
    final readyAny = resolved.where((file) => file.selected && file.exists);
    if (readyAny.isNotEmpty) return readyAny.first.absolutePath;
    final weights = resolved.where((file) => file.artifact.kind == 'weights');
    final target = weights.isNotEmpty ? weights.first : resolved.firstOrNull;
    return target?.absolutePath;
  }

  Set<InferenceCapability> _capabilitiesFor(List<TaskDeclaration> tasks) {
    if (tasks.isEmpty) return const {InferenceCapability.textGeneration};
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
