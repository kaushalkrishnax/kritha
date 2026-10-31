import 'package:freezed_annotation/freezed_annotation.dart';

import 'chat_attachment.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

enum ChatRole { user, assistant }

/// A single persisted chat turn.
@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required ChatRole role,
    required String text,
    required DateTime createdAt,
    @Default(<ChatAttachment>[]) List<ChatAttachment> attachments,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}
