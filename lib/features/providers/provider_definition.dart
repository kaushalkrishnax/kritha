import '../intelligence/runtime_ids.dart';

enum ProviderKind { local, cloud, custom }

enum ProviderAuthStyle { none, bearer, anthropic }

class InferenceProviderDefinition {
  const InferenceProviderDefinition({
    required this.id,
    required this.runtimeId,
    required this.name,
    required this.description,
    required this.kind,
    required this.authStyle,
    this.alias,
    this.defaultBaseUrl = '',
    this.credentialLabel = 'API key',
    this.supportsCustomEndpoint = false,
    this.requiresCredential = false,
    this.testPath = '/models',
  });

  /// Stable identity used by credentials, assignments and routing.
  final String id;

  /// Editable, human-readable identity. Falls back to [id] for built-ins.
  final String? alias;

  /// The adapter that executes models from this source.
  final String runtimeId;
  final String name;
  final String description;
  final ProviderKind kind;
  final ProviderAuthStyle authStyle;
  final String defaultBaseUrl;
  final String credentialLabel;
  final bool supportsCustomEndpoint;
  final bool requiresCredential;
  final String? testPath;

  String get displayAlias => alias ?? id;

  bool get isLocal => kind == ProviderKind.local;
  bool get isCustom => kind == ProviderKind.custom;
  bool get needsEndpoint => supportsCustomEndpoint;
  bool get canTest => !isLocal && testPath != null;
}

InferenceProviderDefinition customProviderDefinition({
  required String id,
  required String alias,
}) {
  return InferenceProviderDefinition(
    id: id,
    alias: alias,
    runtimeId: openAiRuntimeId,
    name: alias,
    description: 'A custom OpenAI-compatible endpoint.',
    kind: ProviderKind.custom,
    authStyle: ProviderAuthStyle.bearer,
    supportsCustomEndpoint: true,
    credentialLabel: 'API key (optional)',
  );
}

const builtInInferenceProviders = <InferenceProviderDefinition>[
  InferenceProviderDefinition(
    id: localProviderId,
    runtimeId: localRuntimeId,
    name: 'Local LiteRT-LM',
    description: 'The on-device runtime used by chat. It reads the validated local model selected in Models.',
    kind: ProviderKind.local,
    authStyle: ProviderAuthStyle.none,
    testPath: null,
  ),
  InferenceProviderDefinition(
    id: 'openai',
    runtimeId: openAiRuntimeId,
    name: 'OpenAI',
    description: 'GPT models through the OpenAI Chat Completions API.',
    kind: ProviderKind.cloud,
    authStyle: ProviderAuthStyle.bearer,
    defaultBaseUrl: 'https://api.openai.com/v1',
    requiresCredential: true,
  ),
  InferenceProviderDefinition(
    id: 'anthropic',
    runtimeId: anthropicRuntimeId,
    name: 'Anthropic',
    description: 'Claude models through the Anthropic Messages API.',
    kind: ProviderKind.cloud,
    authStyle: ProviderAuthStyle.anthropic,
    defaultBaseUrl: 'https://api.anthropic.com/v1',
    requiresCredential: true,
  ),
  InferenceProviderDefinition(
    id: 'google',
    runtimeId: openAiRuntimeId,
    name: 'Google Gemini',
    description: 'Gemini models through the Google Generative Language API (OpenAI-compatible endpoint).',
    kind: ProviderKind.cloud,
    authStyle: ProviderAuthStyle.bearer,
    defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai/',
    credentialLabel: 'API key',
    requiresCredential: true,
  ),
  InferenceProviderDefinition(
    id: 'xai',
    runtimeId: openAiRuntimeId,
    name: 'xAI',
    description: 'Grok models through the xAI OpenAI-compatible API.',
    kind: ProviderKind.cloud,
    authStyle: ProviderAuthStyle.bearer,
    defaultBaseUrl: 'https://api.x.ai/v1',
    requiresCredential: true,
  ),
  InferenceProviderDefinition(
    id: 'groq',
    runtimeId: openAiRuntimeId,
    name: 'Groq',
    description:
        'Fast hosted inference through the Groq OpenAI-compatible API.',
    kind: ProviderKind.cloud,
    authStyle: ProviderAuthStyle.bearer,
    defaultBaseUrl: 'https://api.groq.com/openai/v1',
    requiresCredential: true,
  ),
  InferenceProviderDefinition(
    id: 'deepseek',
    runtimeId: openAiRuntimeId,
    name: 'DeepSeek',
    description: 'DeepSeek models through the DeepSeek OpenAI-compatible API.',
    kind: ProviderKind.cloud,
    authStyle: ProviderAuthStyle.bearer,
    defaultBaseUrl: 'https://api.deepseek.com/v1',
    requiresCredential: true,
  ),
  InferenceProviderDefinition(
    id: 'perplexity',
    runtimeId: openAiRuntimeId,
    name: 'Perplexity AI',
    description: 'Perplexity models through the OpenAI-compatible API.',
    kind: ProviderKind.cloud,
    authStyle: ProviderAuthStyle.bearer,
    defaultBaseUrl: 'https://api.perplexity.ai',
    requiresCredential: true,
  ),
  InferenceProviderDefinition(
    id: 'qwen',
    runtimeId: openAiRuntimeId,
    name: 'Qwen AI',
    description: 'Qwen models through the Alibaba Cloud OpenAI-compatible API.',
    kind: ProviderKind.cloud,
    authStyle: ProviderAuthStyle.bearer,
    defaultBaseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    requiresCredential: true,
  ),
  InferenceProviderDefinition(
    id: 'huggingface',
    runtimeId: openAiRuntimeId,
    name: 'Hugging Face',
    description: 'Community models through the Hugging Face Inference API (OpenAI-compatible).',
    kind: ProviderKind.cloud,
    authStyle: ProviderAuthStyle.bearer,
    defaultBaseUrl: 'https://router.huggingface.co/v1',
    requiresCredential: true,
  ),
  InferenceProviderDefinition(
    id: 'mistral',
    runtimeId: openAiRuntimeId,
    name: 'Mistral AI',
    description: 'Mistral hosted models through an OpenAI-compatible API.',
    kind: ProviderKind.cloud,
    authStyle: ProviderAuthStyle.bearer,
    defaultBaseUrl: 'https://api.mistral.ai/v1',
    requiresCredential: true,
  ),
];

/// Built-ins plus the legacy custom-provider template.
///
/// The template is retained for compatibility with older saved configuration
/// and connection-test callers. User-created custom providers are resolved from
/// the provider store instead.
const supportedInferenceProviders = <InferenceProviderDefinition>[
  ...builtInInferenceProviders,
  InferenceProviderDefinition(
    id: 'custom',
    runtimeId: openAiRuntimeId,
    name: 'Custom OpenAI-compatible',
    description: 'Any server that implements the OpenAI models and chat-completions shape.',
    kind: ProviderKind.custom,
    authStyle: ProviderAuthStyle.bearer,
    supportsCustomEndpoint: true,
    credentialLabel: 'API key (optional)',
  ),
];

InferenceProviderDefinition? providerDefinitionFor(String id) {
  for (final definition in supportedInferenceProviders) {
    if (definition.id == id) return definition;
  }
  return null;
}

bool isBuiltInProviderId(String id) {
  for (final definition in builtInInferenceProviders) {
    if (definition.id == id) return true;
  }
  return false;
}
