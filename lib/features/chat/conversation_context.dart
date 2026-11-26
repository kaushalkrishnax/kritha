import '../../models/chat_message.dart';
import '../intelligence/intelligence_exception.dart';
import '../intelligence/models/ai_input.dart';
import '../intelligence/models/ai_request.dart';

/// Builds inference context from persisted session history, omitting empty turns.
class ConversationContextBuilder {
  const ConversationContextBuilder();

  AiRequest build(
    List<ChatMessage> messages, {
    String? modelId,
    List<AiInput> inputs = const [],
    Map<String, String> metadata = const {},
    String? lastUserTextOverride,
    String? systemPrompt,
  }) {
    final turns = <AiMessage>[];
    final sys = systemPrompt?.trim() ?? '';
    if (sys.isNotEmpty) {
      turns.add(AiMessage.system(sys));
    }
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final isLast = i == messages.length - 1;
      var text = isLast && lastUserTextOverride != null
          ? lastUserTextOverride
          : message.text;
      if (text.trim().isEmpty && isLast && inputs.isNotEmpty) {
        text = 'Describe or analyze the attached content.';
      }
      if (text.trim().isEmpty) continue;
      turns.add(
        switch (message.role) {
          ChatRole.user => AiMessage.user(text),
          ChatRole.assistant => AiMessage.assistant(text),
        },
      );
    }
    if (turns.isEmpty || turns.last.role != AiRole.user) {
      throw const InvalidRequestException(
        'A chat request must end with a user turn.',
      );
    }
    return AiRequest(
      messages: turns,
      modelId: modelId,
      inputs: inputs,
      metadata: metadata,
    );
  }
}
