enum ProviderKind { local, cloud, custom }

enum ProviderAuthStyle { none, bearer, anthropic, queryKey }

class InferenceProviderDefinition {
  const InferenceProviderDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    required this.authStyle,
    this.defaultBaseUrl = '',
    this.credentialLabel = 'API key',
    this.supportsCustomEndpoint = false,
    this.requiresCredential = false,
    this.testPath = '/models',
  });

  final String id;
  final String name;
  final String description;
  final ProviderKind kind;
  final ProviderAuthStyle authStyle;
  final String defaultBaseUrl;
  final String credentialLabel;
  final bool supportsCustomEndpoint;
  final bool requiresCredential;
  final String? testPath;

  bool get isLocal => kind == ProviderKind.local;
  bool get needsEndpoint => supportsCustomEndpoint;
  bool get canTest => !isLocal && testPath != null;
}

const supportedInferenceProviders = <InferenceProviderDefinition>[
  InferenceProviderDefinition(
    id: 'local-litertlm',
    name: 'Local LiteRT-LM',
    description: 'The on-device runtime used by chat. It reads the validated local model selected in Models.',
    kind: ProviderKind.local,
    authStyle: ProviderAuthStyle.none,
    testPath: null,
  ),
  InferenceProviderDefinition(
    id: 'openai',
    name: 'OpenAI',
    description: 'OpenAI platform models through the Responses-compatible API.',
    kind: ProviderKind.cloud,
    authStyle: ProviderAuthStyle.bearer,
    defaultBaseUrl: 'https://api.openai.com/v1',
    requiresCredential: true,
  ),
  InferenceProviderDefinition(
    id: 'anthropic',
    name: 'Anthropic',
    description: 'Claude models through the Anthropic Messages API.',
    kind: ProviderKind.cloud,
    authStyle: ProviderAuthStyle.anthropic,
    defaultBaseUrl: 'https://api.anthropic.com/v1',
    requiresCredential: true,
  ),
  InferenceProviderDefinition(
    id: 'google',
    name: 'Google Gemini',
    description: 'Gemini models through the Google Generative Language API.',
    kind: ProviderKind.cloud,
    authStyle: ProviderAuthStyle.queryKey,
    defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    credentialLabel: 'API key',
    requiresCredential: true,
  ),
  InferenceProviderDefinition(
    id: 'mistral',
    name: 'Mistral AI',
    description: 'Mistral hosted models through an OpenAI-compatible API.',
    kind: ProviderKind.cloud,
    authStyle: ProviderAuthStyle.bearer,
    defaultBaseUrl: 'https://api.mistral.ai/v1',
    requiresCredential: true,
  ),
  InferenceProviderDefinition(
    id: 'custom',
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
