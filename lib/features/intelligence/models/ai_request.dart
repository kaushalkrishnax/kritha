import 'package:freezed_annotation/freezed_annotation.dart';

import 'ai_input.dart';
import 'model_capabilities.dart';
import 'task_registry.dart';

part 'ai_request.freezed.dart';
part 'ai_request.g.dart';

enum AiRole { system, user, assistant }

@freezed
abstract class AiMessage with _$AiMessage {
  const factory AiMessage({required AiRole role, required String text}) =
      _AiMessage;

  factory AiMessage.fromJson(Map<String, dynamic> json) =>
      _$AiMessageFromJson(json);

  factory AiMessage.system(String text) =>
      AiMessage(role: AiRole.system, text: text);

  factory AiMessage.user(String text) =>
      AiMessage(role: AiRole.user, text: text);

  factory AiMessage.assistant(String text) =>
      AiMessage(role: AiRole.assistant, text: text);
}

@freezed
abstract class AiGenerationOptions with _$AiGenerationOptions {
  const factory AiGenerationOptions({
    @Default(1.0) double temperature,
    @Default(0.95) double topP,
    @Default(40) int topK,
    @Default(0) int seed,
    int? maxOutputTokens,
  }) = _AiGenerationOptions;

  factory AiGenerationOptions.fromJson(Map<String, dynamic> json) =>
      _$AiGenerationOptionsFromJson(json);
}

@freezed
abstract class AiRequest with _$AiRequest {
  const AiRequest._();

  const factory AiRequest({
    required List<AiMessage> messages,
    @Default(AiGenerationOptions()) AiGenerationOptions options,
    Map<String, dynamic>? responseSchema,
    String? modelId,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<AiInput>[])
    List<AiInput> inputs,
    @Default(<String, String>{}) Map<String, String> metadata,
  }) = _AiRequest;

  factory AiRequest.fromJson(Map<String, dynamic> json) =>
      _$AiRequestFromJson(json);

  /// Canonical task carried by the request metadata for backwards-compatible
  /// persistence. Requests without a task remain text-generation requests.
  AiTaskId? get requestedTask {
    final value = metadata['task_id'];
    return value == null ? AiTaskId.textGeneration : AiTaskId.fromId(value);
  }

  /// Capabilities a provider must declare before it may serve this request.
  Set<InferenceCapability> get requiredCapabilities => {
    if (requestedTask != null) ...capabilitiesForTask(requestedTask!),
    if (responseSchema != null) InferenceCapability.structuredOutput,
  };
}
