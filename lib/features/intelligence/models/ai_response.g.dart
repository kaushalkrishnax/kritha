// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AiResponse _$AiResponseFromJson(Map<String, dynamic> json) => _AiResponse(
  text: json['text'] as String,
  modelId: json['modelId'] as String,
  latency: _latencyFromJson((json['latencyMs'] as num).toInt()),
  metadata:
      (json['metadata'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
);

Map<String, dynamic> _$AiResponseToJson(_AiResponse instance) =>
    <String, dynamic>{
      'text': instance.text,
      'modelId': instance.modelId,
      'latencyMs': _latencyToJson(instance.latency),
      'metadata': instance.metadata,
    };
