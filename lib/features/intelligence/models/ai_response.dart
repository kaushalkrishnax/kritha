import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_response.freezed.dart';
part 'ai_response.g.dart';

Duration _latencyFromJson(int milliseconds) =>
    Duration(milliseconds: milliseconds);

int _latencyToJson(Duration latency) => latency.inMilliseconds;

/// Completed inference result, free of runtime-specific types.
@freezed
abstract class AiResponse with _$AiResponse {
  const factory AiResponse({
    required String text,
    required String modelId,
    @JsonKey(
      name: 'latencyMs',
      fromJson: _latencyFromJson,
      toJson: _latencyToJson,
    )
    required Duration latency,
    @Default(<String, String>{}) Map<String, String> metadata,
  }) = _AiResponse;

  factory AiResponse.fromJson(Map<String, dynamic> json) =>
      _$AiResponseFromJson(json);
}
