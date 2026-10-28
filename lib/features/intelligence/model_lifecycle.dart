import 'inference_provider.dart';
import 'model_configuration.dart';

/// Combined, user-facing state for the configured model and its engine.
///
/// Configuration validation, native initialization and successful generation
/// stay separate: [initialized] only means the runtime loaded the model.
enum ModelLifecycleStage {
  checkingConfiguration,
  notConfigured,
  configurationUnavailable,
  fileReady,
  initializing,
  initialized,
  initializationFailed,
  unavailable,
  disposed,
}

class ModelLifecycle {
  const ModelLifecycle(this.stage, {this.message, this.fileName, this.modelId});

  final ModelLifecycleStage stage;

  /// A short, user-safe explanation for a failed state.
  final String? message;
  final String? fileName;
  final String? modelId;

  bool? get ok => switch (stage) {
    ModelLifecycleStage.checkingConfiguration => null,
    ModelLifecycleStage.notConfigured => false,
    ModelLifecycleStage.configurationUnavailable => false,
    ModelLifecycleStage.fileReady => null,
    ModelLifecycleStage.initializing => null,
    ModelLifecycleStage.initialized => true,
    ModelLifecycleStage.initializationFailed => false,
    ModelLifecycleStage.unavailable => false,
    ModelLifecycleStage.disposed => null,
  };

  String get label => switch (stage) {
    ModelLifecycleStage.checkingConfiguration => 'checking model…',
    ModelLifecycleStage.notConfigured => 'no model configured',
    ModelLifecycleStage.configurationUnavailable => 'model file unavailable',
    ModelLifecycleStage.fileReady => 'file ready; engine not loaded',
    ModelLifecycleStage.initializing => 'engine loading…',
    ModelLifecycleStage.initialized => 'engine loaded',
    ModelLifecycleStage.initializationFailed => 'engine initialization failed',
    ModelLifecycleStage.unavailable => 'engine unavailable',
    ModelLifecycleStage.disposed => 'engine released',
  };

  static ModelLifecycle evaluate({
    required ModelConfiguration? configuration,
    required bool configurationLoading,
    required bool configurationFailed,
    required List<InferenceProvider> providers,
  }) {
    if (configurationFailed) {
      return const ModelLifecycle(
        ModelLifecycleStage.configurationUnavailable,
        message: 'Model settings could not be loaded.',
      );
    }
    if (configuration == null) {
      return configurationLoading
          ? const ModelLifecycle(ModelLifecycleStage.checkingConfiguration)
          : const ModelLifecycle(ModelLifecycleStage.notConfigured);
    }
    if (configuration.status == ModelConfigurationStatus.notConfigured) {
      return const ModelLifecycle(ModelLifecycleStage.notConfigured);
    }
    if (!configuration.isReady) {
      return ModelLifecycle(
        ModelLifecycleStage.configurationUnavailable,
        fileName: configuration.fileName,
      );
    }
    if (providers.isEmpty) {
      return ModelLifecycle(
        ModelLifecycleStage.fileReady,
        fileName: configuration.fileName,
      );
    }

    final provider = providers.first;
    final engine = provider.lifecycle.value;
    return ModelLifecycle(
      switch (engine.stage) {
        EngineLifecycleStage.fileReady => ModelLifecycleStage.fileReady,
        EngineLifecycleStage.initializing => ModelLifecycleStage.initializing,
        EngineLifecycleStage.initialized => ModelLifecycleStage.initialized,
        EngineLifecycleStage.initializationFailed =>
          ModelLifecycleStage.initializationFailed,
        EngineLifecycleStage.unavailable => ModelLifecycleStage.unavailable,
        EngineLifecycleStage.disposed => ModelLifecycleStage.disposed,
      },
      message: engine.message,
      fileName: configuration.fileName,
      modelId: provider.descriptor.id,
    );
  }
}
