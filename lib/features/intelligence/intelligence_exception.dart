import 'models/model_capabilities.dart';

/// Base type for recoverable intelligence-layer failures.
sealed class IntelligenceException implements Exception {
  const IntelligenceException(this.message, {this.cause});

  final String message;

  /// The underlying runtime error, when one exists. Never surfaced verbatim to
  /// widgets.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// No provider, model path or platform runtime is available.
final class ProviderUnavailableException extends IntelligenceException {
  const ProviderUnavailableException(
    super.message, {
    this.providerId,
    super.cause,
  });

  final String? providerId;
}

/// The request asks for something the selected model does not declare.
final class UnsupportedCapabilityException extends IntelligenceException {
  const UnsupportedCapabilityException({
    required this.providerId,
    required this.missing,
  }) : super('The selected model does not support this request.');

  final String providerId;
  final Set<InferenceCapability> missing;

  @override
  String toString() =>
      'UnsupportedCapabilityException: $providerId is missing '
      '${missing.map((capability) => capability.name).join(', ')}';
}

/// The request itself is malformed, before any runtime is touched.
final class InvalidRequestException extends IntelligenceException {
  const InvalidRequestException(super.message);
}

/// The runtime accepted the request but generation failed.
final class InferenceFailedException extends IntelligenceException {
  const InferenceFailedException(
    super.message, {
    required this.providerId,
    super.cause,
  });

  final String providerId;
}
