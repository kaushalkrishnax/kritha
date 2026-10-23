// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => _ChatMessage(
  id: json['id'] as String,
  role: $enumDecode(_$ChatRoleEnumMap, json['role']),
  text: json['text'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  attachments:
      (json['attachments'] as List<dynamic>?)
          ?.map((e) => ChatAttachment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ChatAttachment>[],
);

Map<String, dynamic> _$ChatMessageToJson(_ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'role': _$ChatRoleEnumMap[instance.role]!,
      'text': instance.text,
      'createdAt': instance.createdAt.toIso8601String(),
      'attachments': instance.attachments,
    };

const _$ChatRoleEnumMap = {
  ChatRole.user: 'user',
  ChatRole.assistant: 'assistant',
};
