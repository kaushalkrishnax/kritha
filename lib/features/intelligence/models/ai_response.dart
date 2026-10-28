import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_response.freezed.dart';
part 'ai_response.g.dart';

Duration _latencyFromJson(int milliseconds) =>
    Duration(milliseconds: milliseconds);

int _latencyToJson(Duration latency) => latency.inMilliseconds;

/// A generated text snapshot, free of runtime-specific types.
///
/// Unary generation returns a completed response. Stream events are cumulative
/// partial snapshots; the stream closing is the only completion signal.
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
