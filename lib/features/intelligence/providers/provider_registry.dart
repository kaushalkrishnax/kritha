import '../intelligence_exception.dart';

import 'provider.dart';

/// Creates provider implementations keyed by their logical alias.
///
/// Known implementations are registered in code. Providers without a
/// dedicated implementation use [fallback], which the app wires to the shared
/// OpenAI-compatible implementation for custom endpoints.
class ProviderRegistry {
  ProviderRegistry({
    Map<String, InferenceProvider Function(ProviderConfig)> factories =
        const {},
    this.fallback,
  }) : _factories = Map.unmodifiable(factories);

  final Map<String, InferenceProvider Function(ProviderConfig)> _factories;
  final InferenceProvider Function(ProviderConfig)? fallback;

  /// Whether a dedicated implementation is registered for [alias].
  bool isRegistered(String alias) => _factories.containsKey(alias);

  /// Creates (or returns) the implementation for [config].
  ///
  /// Throws [ProviderUnavailableException] when no dedicated implementation
  /// or fallback factory is available.
  InferenceProvider createProvider(ProviderConfig config) {
    final factory = _factories[config.alias] ?? fallback;
    if (factory == null) {
      throw ProviderUnavailableException(
        'No provider implementation registered for alias "${config.alias}".',
        providerId: config.alias,
      );
    }
    return factory(config);
  }

  /// Aliases of every registered default implementation.
  Iterable<String> get aliases => _factories.keys;
}
