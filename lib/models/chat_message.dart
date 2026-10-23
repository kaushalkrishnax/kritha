import 'package:freezed_annotation/freezed_annotation.dart';

import 'chat_attachment.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

enum ChatRole { user, assistant }

/// A single persisted chat turn.
///
/// Freezed gives value equality, `copyWith` and pattern matching; the JSON
/// serializer is also what the Drift layer uses to prove both generators ship
/// in the measured build.
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
