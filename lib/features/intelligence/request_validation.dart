import 'intelligence_exception.dart';
import 'models/ai_request.dart';

/// Checks request invariants before routing or native execution.
///
/// Capability declarations are deliberately not checked here: the router and
/// provider enforce them after model selection.
class AiRequestValidator {
  const AiRequestValidator();

  void validate(AiRequest request) {
    final messages = request.messages;
    if (messages.isEmpty) {
      throw const InvalidRequestException(
        'An inference request needs at least one message.',
      );
    }

    var seenConversationTurn = false;
    for (var index = 0; index < messages.length; index++) {
      final message = messages[index];
      if (message.text.trim().isEmpty) {
        throw InvalidRequestException(
          'Message ${index + 1} must not be empty.',
        );
      }
      if (message.role == AiRole.system) {
        if (seenConversationTurn) {
          throw const InvalidRequestException(
            'System messages must precede user and assistant turns.',
          );
        }
      } else {
        seenConversationTurn = true;
      }
    }

    final last = messages.last;
    if (last.role != AiRole.user) {
      throw const InvalidRequestException(
        'An inference request must end with a user message.',
      );
    }

    final modelId = request.modelId;
    if (modelId != null && modelId.trim().isEmpty) {
      throw const InvalidRequestException(
        'A requested model id must not be blank.',
      );
    }

    _validateOptions(request.options);
  }

  void _validateOptions(AiGenerationOptions options) {
    if (!options.temperature.isFinite || options.temperature < 0) {
      throw const InvalidRequestException(
        'Temperature must be a finite, non-negative value.',
      );
    }
    if (!options.topP.isFinite || options.topP <= 0 || options.topP > 1) {
      throw const InvalidRequestException('Top-p must be within (0, 1].');
    }
    if (options.topK <= 0) {
      throw const InvalidRequestException('Top-k must be positive.');
    }
    if (options.seed < 0) {
      throw const InvalidRequestException('Seed must not be negative.');
    }
    final maxOutputTokens = options.maxOutputTokens;
    if (maxOutputTokens != null && maxOutputTokens <= 0) {
      throw const InvalidRequestException(
        'Max output tokens must be positive when set.',
      );
    }
  }
}
