import 'provider_definition.dart';

/// Authentication headers shared by connection tests and inference adapters.
Map<String, String> providerAuthHeaders(
  InferenceProviderDefinition definition,
  String? credential, {
  String accept = 'application/json',
}) {
  final headers = <String, String>{'accept': accept};
  final secret = credential?.trim();
  switch (definition.authStyle) {
    case ProviderAuthStyle.none:
      break;
    case ProviderAuthStyle.bearer:
      if (secret != null && secret.isNotEmpty) {
        headers['authorization'] = 'Bearer $secret';
      }
    case ProviderAuthStyle.anthropic:
      if (secret != null && secret.isNotEmpty) {
        headers['x-api-key'] = secret;
      }
      headers['anthropic-version'] = '2023-06-01';
  }
  return headers;
}
