import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/models/chat_message.dart';

void main() {
  test('ChatMessage survives a JSON round trip', () {
    final message = ChatMessage(
      id: 'message-1',
      role: ChatRole.assistant,
      text: r'Energy is $E = mc^2$.',
      createdAt: DateTime.utc(2026, 10, 22, 9, 41),
    );

    final restored = ChatMessage.fromJson(message.toJson());

    expect(restored, message);
    expect(restored.role, ChatRole.assistant);
    expect(restored.text, contains(r'$E = mc^2$'));
  });

  test('json_serializable stores the enum by name', () {
    final message = ChatMessage(
      id: 'message-2',
      role: ChatRole.user,
      text: 'Hello',
      createdAt: DateTime.utc(2026, 10, 22),
    );

    expect(message.toJson()['role'], 'user');
  });
}
