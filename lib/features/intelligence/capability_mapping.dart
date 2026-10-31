import '../models/catalogue/catalogue_model.dart';
import 'models/model_capabilities.dart';

/// Maps advertised catalogue capabilities to routable Kritha operations.
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
