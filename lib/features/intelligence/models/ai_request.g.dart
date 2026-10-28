// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AiMessage _$AiMessageFromJson(Map<String, dynamic> json) => _AiMessage(
  role: $enumDecode(_$AiRoleEnumMap, json['role']),
  text: json['text'] as String,
);

Map<String, dynamic> _$AiMessageToJson(_AiMessage instance) =>
    <String, dynamic>{
      'role': _$AiRoleEnumMap[instance.role]!,
      'text': instance.text,
    };

const _$AiRoleEnumMap = {
  AiRole.system: 'system',
  AiRole.user: 'user',
  AiRole.assistant: 'assistant',
};

_AiGenerationOptions _$AiGenerationOptionsFromJson(Map<String, dynamic> json) =>
    _AiGenerationOptions(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 1.0,
      topP: (json['topP'] as num?)?.toDouble() ?? 0.95,
      topK: (json['topK'] as num?)?.toInt() ?? 40,
      seed: (json['seed'] as num?)?.toInt() ?? 0,
      maxOutputTokens: (json['maxOutputTokens'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AiGenerationOptionsToJson(
  _AiGenerationOptions instance,
) => <String, dynamic>{
  'temperature': instance.temperature,
  'topP': instance.topP,
  'topK': instance.topK,
  'seed': instance.seed,
  'maxOutputTokens': instance.maxOutputTokens,
};

_AiRequest _$AiRequestFromJson(Map<String, dynamic> json) => _AiRequest(
  messages: (json['messages'] as List<dynamic>)
      .map((e) => AiMessage.fromJson(e as Map<String, dynamic>))
      .toList(),
  options: json['options'] == null
      ? const AiGenerationOptions()
      : AiGenerationOptions.fromJson(json['options'] as Map<String, dynamic>),
  responseSchema: json['responseSchema'] as Map<String, dynamic>?,
  modelId: json['modelId'] as String?,
  metadata:
      (json['metadata'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
);

Map<String, dynamic> _$AiRequestToJson(_AiRequest instance) =>
    <String, dynamic>{
      'messages': instance.messages,
      'options': instance.options,
      'responseSchema': instance.responseSchema,
      'modelId': instance.modelId,
      'metadata': instance.metadata,
    };
