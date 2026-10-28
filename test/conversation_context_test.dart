import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/chat/conversation_context.dart';
import 'package:kritha/features/intelligence/intelligence_exception.dart';
import 'package:kritha/features/intelligence/models/ai_request.dart';
import 'package:kritha/features/intelligence/models/model_capabilities.dart';
import 'package:kritha/models/chat_attachment.dart';
import 'package:kritha/models/chat_message.dart';

void main() {
  const builder = ConversationContextBuilder();
  var sequence = 0;

  ChatMessage message(
    ChatRole role,
    String text, {
    List<ChatAttachment> attachments = const [],
  }) {
    sequence += 1;
    return ChatMessage(
      id: 'message-$sequence',
      role: role,
      text: text,
      createdAt: DateTime(2026, 10, 28, 12, sequence),
      attachments: attachments,
    );
  }

  const attachment = ChatAttachment(
    id: 'attachment',
    name: 'notes.txt',
    path: '/tmp/notes.txt',
    sizeBytes: 12,
    kind: ChatAttachmentKind.file,
  );

  test('maps persisted turns in order without inventing a system message', () {
    final request = builder.build([
      message(ChatRole.user, 'First'),
      message(ChatRole.assistant, 'First answer'),
      message(ChatRole.user, 'Second'),
    ]);

    expect(request.messages.map((item) => item.role), [
      AiRole.user,
      AiRole.assistant,
      AiRole.user,
    ]);
    expect(request.messages.map((item) => item.text), [
      'First',
      'First answer',
      'Second',
    ]);
    expect(request.requiredCapabilities, {InferenceCapability.textGeneration});
    expect(request.modelId, isNull);
  });

  test('omits empty and attachment-only turns while preserving order', () {
    final request = builder.build([
      message(ChatRole.user, 'First'),
      message(ChatRole.user, '', attachments: const [attachment]),
      message(ChatRole.assistant, 'First answer'),
      message(ChatRole.user, 'Second'),
    ]);

    expect(request.messages.map((item) => item.text), [
      'First',
      'First answer',
      'Second',
    ]);
  });

  test('uses only the supplied session history', () {
    final request = builder.build([
      message(ChatRole.user, 'Only this session'),
    ]);

    expect(request.messages.map((item) => item.text), ['Only this session']);
  });

  test('is deterministic for the same persisted history', () {
    final messages = [
      message(ChatRole.user, 'First'),
      message(ChatRole.assistant, 'Answer'),
      message(ChatRole.user, 'Second'),
    ];

    expect(builder.build(messages), builder.build(messages));
  });

  test('rejects history without a final user turn', () {
    expect(
      () => builder.build([message(ChatRole.assistant, 'Only an answer')]),
      throwsA(isA<InvalidRequestException>()),
    );
    expect(
      () => builder.build([
        message(ChatRole.user, 'Prompt'),
        message(ChatRole.assistant, 'Answer'),
      ]),
      throwsA(isA<InvalidRequestException>()),
    );
    expect(
      () => builder.build([
        message(ChatRole.user, '', attachments: const [attachment]),
      ]),
      throwsA(isA<InvalidRequestException>()),
    );
  });
}
