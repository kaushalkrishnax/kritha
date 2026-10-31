import '../../models/chat_message.dart';
import '../intelligence/intelligence_exception.dart';
import '../intelligence/models/ai_request.dart';

/// Builds inference context from persisted session history, omitting empty turns.
class ConversationContextBuilder {
  const ConversationContextBuilder();

  AiRequest build(List<ChatMessage> messages) {
    final turns = <AiMessage>[
      for (final message in messages)
        if (message.text.trim().isNotEmpty)
          switch (message.role) {
            ChatRole.user => AiMessage.user(message.text),
            ChatRole.assistant => AiMessage.assistant(message.text),
          },
    ];
    if (turns.isEmpty || turns.last.role != AiRole.user) {
      throw const InvalidRequestException(
        'A chat request must end with a user turn.',
      );
    }
    return AiRequest(messages: turns);
  }
}
