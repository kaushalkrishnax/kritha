import '../../models/chat_message.dart';
import '../intelligence/intelligence_exception.dart';
import '../intelligence/models/ai_request.dart';

/// Builds the inference context for one chat session.
///
/// The caller supplies only the active session's persisted history in display
/// order. Empty-text turns, including attachment-only prompts, are omitted
/// because the runtime has no attachment input. No system message is
/// synthesized: chat history has no system role.
///
/// Retry passes the persisted transcript through the same builder, so partial
/// streamed output never enters the context.
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
