import 'dart:async';

import 'package:flutter/foundation.dart';

import '../inference_provider.dart';
import '../../../models/model_record.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';
import '../models/model_capabilities.dart';
import '../models/task_registry.dart';

class GeneratedImage {
  const GeneratedImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

class SynthesizedSpeech {
  const SynthesizedSpeech({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

/// Optional media operations for providers supporting image gen, ASR, or TTS.
abstract interface class MediaCapableProvider {
  Future<GeneratedImage> generateImage(String prompt, ProviderModel model);

  Future<String> transcribeAudio(
    Uint8List bytes,
    String mimeType,
    ProviderModel model,
  );

  Future<SynthesizedSpeech> synthesizeSpeech(String text, ProviderModel model);
}

/// Configuration for one provider record resolved from the providers table.
class ProviderConfig {
  const ProviderConfig({
    required this.id,
    required this.alias,
    this.baseUrl,
    this.apiKey,
  });

  /// Internal provider UUID.
  final String id;

  /// Unique logical provider identifier used for implementation resolution.
  final String alias;

  /// Configured endpoint, nullable where not applicable (e.g. local runtimes).
  final String? baseUrl;

  /// Locally stored API key, nullable.
  final String? apiKey;

  bool get isLocal => baseUrl == null;

  ProviderConfig copyWith({
    String? baseUrl,
    String? apiKey,
  }) {
    return ProviderConfig(
      id: id,
      alias: alias,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}

/// A model resolved by the Intelligence Layer and handed to a provider.
class ProviderModel {
  const ProviderModel({
    required this.id,
    required this.providerId,
    required this.externalModelId,
    required this.displayName,
    required this.capabilities,
    required this.tasks,
    this.modelPath,
    required this.artifacts,
    required this.metadata,
  });

  /// Internal model UUID.
  final String id;

  final String providerId;

  /// Identifier used by the provider or runtime executing this model.
  final String externalModelId;
  final String displayName;

  /// Capabilities the model declares for inference.
  final Set<InferenceCapability> capabilities;

  final List<TaskDeclaration> tasks;

  /// Resolved primary artifact path for local runtimes (e.g. the weights
  /// file); null for remote providers.
  final String? modelPath;

  /// Resolved model-owned artifacts (including inherited base artifacts).
  final List<ResolvedModelArtifact> artifacts;

  final Map<String, dynamic> metadata;
}

/// A model discovered through provider model discovery.
class DiscoveredModel {
  const DiscoveredModel({
    required this.externalModelId,
    required this.displayName,
    this.capabilities = const {},
    this.tasks = const [],
    this.metadata = const {},
  });

  final String externalModelId;
  final String displayName;
  final Set<InferenceCapability> capabilities;
  final List<TaskDeclaration> tasks;
  final Map<String, dynamic> metadata;
}

/// Result of a provider connection test.
class ProviderTestResult {
  const ProviderTestResult({
    required this.ok,
    required this.message,
  });

  final bool ok;
  final String message;
}

/// Common contract every inference backend implements.
///
/// Local runtimes (LiteRT-LM) and remote providers (Gemini, Anthropic, xAI,
/// Mistral, OpenAI-compatible) all conform to this interface. The UI and
/// Intelligence Layer never address a runtime or API implementation directly.
abstract interface class InferenceProvider {
  /// Unique logical provider identifier used for registry resolution.
  String get alias;

  /// Configuration resolved from the providers table.
  ProviderConfig get config;

  /// Observable lifecycle; safe to inspect without loading a model.
  ValueListenable<EngineLifecycle> get lifecycle;

  /// Whether a model/engine is loaded and ready in memory.
  bool get isInitialized;

  Future<void> initialize();

  /// Discovers the models this provider exposes.
  Future<List<DiscoveredModel>> discoverModels();

  /// Tests the provider configuration without running inference.
  Future<ProviderTestResult> test();

  Future<AiResponse> generate(AiRequest request, ProviderModel model);

  /// Streams cumulative partial snapshots; cancelling the subscription stops
  /// generation.
  Stream<AiResponse> stream(AiRequest request, ProviderModel model);

  Future<void> dispose();
}
