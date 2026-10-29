const _modelsPrefix = 'models/';

const _publisherNames = {
  'openai': 'OpenAI',
  'anthropic': 'Anthropic',
  'google': 'Google',
  'mistral': 'Mistral',
};

String displayModelName(String value) {
  final trimmed = value.trim();
  if (!trimmed.startsWith(_modelsPrefix)) return trimmed;
  final withoutPrefix = trimmed.substring(_modelsPrefix.length);
  return withoutPrefix.isEmpty ? trimmed : withoutPrefix;
}

String displayPublisherName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  final known = _publisherNames[trimmed.toLowerCase()];
  if (known != null) return known;
  return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
}
