import 'package:freezed_annotation/freezed_annotation.dart';

part 'model_capabilities.freezed.dart';

/// An operation a local model can be asked to perform.
enum InferenceCapability {
  textGeneration,
  imageInput,
  audioInput,
  structuredOutput,
}

/// What a model is declared to support.
///
/// LiteRT-LM 0.0.14 cannot inspect a model file beyond speculative-decoding
/// support, so these flags come from the descriptor rather than a probe. The
/// default is empty on purpose: an undeclared capability must never be treated
/// as available.
@freezed
abstract class ModelCapabilities with _$ModelCapabilities {
  const ModelCapabilities._();

  const factory ModelCapabilities({
    @Default(<InferenceCapability>{}) Set<InferenceCapability> supported,
  }) = _ModelCapabilities;

  /// The conservative declaration used until a model is verified otherwise.
  static const textOnly = ModelCapabilities(
    supported: {InferenceCapability.textGeneration},
  );

  bool supports(InferenceCapability capability) =>
      supported.contains(capability);

  bool supportsAll(Set<InferenceCapability> required) =>
      required.every(supported.contains);
}
