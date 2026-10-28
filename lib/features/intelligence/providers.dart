import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'inference_provider.dart';
import 'intelligence_engine.dart';
import 'intelligence_exception.dart';
import 'model_configuration.dart';
import 'model_lifecycle.dart';
import 'models/model_descriptor.dart';
import 'request_router.dart';
import 'runtimes/litertlm_provider.dart';

/// The validated model the intelligence layer should serve.
///
/// Null until a file is selected in Settings and passes validation. Nothing
/// loads at startup; the runtime is only initialized by a request.
final configuredModelProvider = Provider<ModelDescriptor?>((ref) {
  final configuration = ref.watch(modelConfigurationProvider);
  if (configuration.hasError) return null;
  return configuration.value?.descriptor;
});

/// Builds the native engine for a descriptor. Tests override this with a fake
/// so the provider graph never touches a model or native library.
final liteRtLmEngineFactoryProvider =
    Provider<LiteRtLmEngine Function(ModelDescriptor)>((ref) {
      return (model) {
        final path = model.modelPath;
        if (path == null || path.trim().isEmpty) {
          throw ProviderUnavailableException(
            'No model file is configured for ${model.id}.',
            providerId: LiteRtLmProvider.providerId,
          );
        }
        return NativeLiteRtLmEngine(modelPath: path);
      };
    });

/// Every provider the router may select. Disposed with its scope.
final inferenceProvidersProvider = Provider<List<InferenceProvider>>((ref) {
  final model = ref.watch(configuredModelProvider);
  if (model == null) return const [];

  final createEngine = ref.watch(liteRtLmEngineFactoryProvider);
  final provider = LiteRtLmProvider(
    descriptor: model,
    createEngine: () => createEngine(model),
  );
  ref.onDispose(provider.dispose);
  return List<InferenceProvider>.unmodifiable([provider]);
});

final requestRouterProvider = Provider<RequestRouter>(
  (ref) => RequestRouter(providers: ref.watch(inferenceProvidersProvider)),
);

final intelligenceEngineProvider = Provider<IntelligenceEngine>(
  (ref) => IntelligenceEngine(router: ref.watch(requestRouterProvider)),
);

/// Observable diagnostics for Settings.
///
/// Watching this provider never initializes a native engine; it only combines
/// configuration validation with the lifecycle the provider has reported.
final modelLifecycleProvider =
    NotifierProvider<ModelLifecycleNotifier, ModelLifecycle>(
      ModelLifecycleNotifier.new,
    );

class ModelLifecycleNotifier extends Notifier<ModelLifecycle> {
  final List<void Function()> _detach = [];
  int _revision = 0;

  @override
  ModelLifecycle build() {
    final revision = ++_revision;
    final configuration = ref.watch(modelConfigurationProvider);
    final providers = ref.watch(inferenceProvidersProvider);
    ref.onDispose(_detachListeners);
    _detachListeners();

    ModelLifecycle snapshot() => ModelLifecycle.evaluate(
      configuration: configuration.value,
      configurationLoading: configuration.isLoading,
      configurationFailed: configuration.hasError,
      providers: providers,
    );

    for (final provider in providers) {
      void onChange() {
        if (ref.mounted && revision == _revision) state = snapshot();
      }

      provider.lifecycle.addListener(onChange);
      _detach.add(() => provider.lifecycle.removeListener(onChange));
    }

    return snapshot();
  }

  void _detachListeners() {
    for (final detach in _detach) {
      detach();
    }
    _detach.clear();
  }
}

final intelligenceStatusProvider = Provider<IntelligenceStatus>((ref) {
  // Rebuild when the engine lifecycle changes, not only when configuration
  // changes.
  ref.watch(modelLifecycleProvider);
  return ref.watch(intelligenceEngineProvider).status;
});
