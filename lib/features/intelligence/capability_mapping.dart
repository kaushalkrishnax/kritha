import '../models/catalogue/catalogue_model.dart';
import 'models/model_capabilities.dart';

/// Maps catalogue capabilities to inference operations.
///
/// Catalogue vocabulary describes what a repository advertises. Inference
/// vocabulary describes operations Kritha can actually route. Keeping the
/// mapping explicit prevents an advertised task from being treated as a
/// working execution path.
Set<InferenceCapability> inferenceCapabilitiesFor(ModelCapability capability) {
  return switch (capability) {
    ModelCapability.text => const {InferenceCapability.textGeneration},
    ModelCapability.vision => const {InferenceCapability.imageInput},
    ModelCapability.speechRecognition => const {InferenceCapability.audioInput},
    ModelCapability.audio => const {InferenceCapability.audioInput},
    ModelCapability.imageGeneration ||
    ModelCapability.textToSpeech ||
    ModelCapability.video ||
    ModelCapability.embeddings => const {},
  };
}

ModelCapabilities modelCapabilitiesFor(ModelCapability capability) =>
    ModelCapabilities(supported: inferenceCapabilitiesFor(capability));
