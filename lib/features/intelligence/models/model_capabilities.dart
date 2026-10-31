import 'package:freezed_annotation/freezed_annotation.dart';

part 'model_capabilities.freezed.dart';

/// Inference operation supported by a model.
enum InferenceCapability {
  textGeneration,
  imageInput,
  audioInput,
  structuredOutput,
}

/// Declared model capabilities; empty by default to prevent assuming undeclared features.
@freezed
abstract class ModelCapabilities with _$ModelCapabilities {
  const ModelCapabilities._();

  const factory ModelCapabilities({
    @Default(<InferenceCapability>{}) Set<InferenceCapability> supported,
  }) = _ModelCapabilities;

  /// Default conservative capabilities until verified.
  static const textOnly = ModelCapabilities(
    supported: {InferenceCapability.textGeneration},
  );

  bool supports(InferenceCapability capability) =>
      supported.contains(capability);

  bool supportsAll(Set<InferenceCapability> required) =>
      required.every(supported.contains);
}
