import '../intelligence_exception.dart';

import 'provider.dart';

/// Creates provider implementations keyed by their logical alias.
///
/// Known implementations are registered in code. Custom providers resolved
/// from the database are handled by the shared OpenAI specification
/// implementation rather than a dynamically constructed import path.
class ProviderRegistry {
  ProviderRegistry({
    Map<String, InferenceProvider Function(ProviderConfig)> factories = const {},
  }) : _factories = Map.unmodifiable(factories);

  final Map<String, InferenceProvider Function(ProviderConfig)> _factories;

  /// Whether a dedicated implementation is registered for [alias].
  bool isRegistered(String alias) => _factories.containsKey(alias);

  /// Creates (or returns) the implementation for [config].
  ///
  /// Throws [ProviderUnavailableException] when no implementation is
  /// registered for the provider alias.
  InferenceProvider createProvider(ProviderConfig config) {
    final factory = _factories[config.alias];
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
