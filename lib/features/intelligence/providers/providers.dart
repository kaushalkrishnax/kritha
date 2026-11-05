import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../models/model_record_store.dart';
import '../intelligence_engine.dart';
import './local/litertlm_provider.dart';
import './provider_registry.dart';
import './remote/anthropic_provider.dart';
import './remote/google_gemini_provider.dart';
import './remote/mistral_provider.dart';
import './remote/oai_spec_provider.dart';
import './remote/xai_provider.dart';

const _providerDisplayNames = {
  'local-litertlm': 'Local LiteRT-LM',
  'google-gemini': 'Google Gemini',
  'anthropic': 'Anthropic',
  'xai': 'xAI',
  'mistral': 'Mistral',
  'openai': 'OpenAI',
};

String providerDisplayName(String alias) =>
    _providerDisplayNames[alias] ?? alias;

/// Transport factory for remote adapters. Tests inject mocked HTTP clients.
final inferenceHttpClientFactoryProvider = Provider<http.Client Function()>(
  (ref) => http.Client.new,
);

/// Documents directory path, resolved once per session.
final documentsPathProvider = Provider<Future<String>>((ref) async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
});

/// Registry of known provider implementations keyed by logical alias.
final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  final repository = ref.watch(modelRepositoryProvider);
  final clientFactory = ref.watch(inferenceHttpClientFactoryProvider);
  return ProviderRegistry(factories: {
    'local-litertlm': (config) => LiteRtLmLocalProvider(
      config: config,
      createEngine: (path) => NativeLiteRtLmEngine(modelPath: path),
      localModels: () async => repository.modelsForProvider(config.id),
    ),
    'google-gemini': (config) => GoogleGeminiProvider(
      config: config,
      clientFactory: clientFactory,
    ),
    'anthropic': (config) => AnthropicProvider(
      config: config,
      clientFactory: clientFactory,
    ),
    'xai': (config) => XaiProvider(
      config: config,
      clientFactory: clientFactory,
    ),
    'mistral': (config) => MistralProvider(
      config: config,
      clientFactory: clientFactory,
    ),
    'openai': (config) => OaiSpecProvider(
      config: config,
      clientFactory: clientFactory,
    ),
  });
});

/// Intelligence layer that resolves models by internal UUID and delegates to
/// the provider implementation registered for the model's provider.
final intelligenceEngineProvider = Provider<IntelligenceEngine>((ref) {
  final repository = ref.watch(modelRepositoryProvider);
  final registry = ref.watch(providerRegistryProvider);
  final documentsPath = ref.watch(documentsPathProvider);
  return IntelligenceEngine(
    modelRepository: repository,
    registry: registry,
    documentsPath: documentsPath,
  );
});

final intelligenceStatusProvider = Provider<IntelligenceStatus>((ref) {
  final engine = ref.watch(intelligenceEngineProvider);
  return engine.status;
});
