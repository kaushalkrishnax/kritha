import 'dart:typed_data';

import 'intelligence_exception.dart';
import 'models/ai_input.dart';
import 'models/ai_request.dart';
import 'models/task_registry.dart';

/// Checks request invariants before routing or native execution.
class AiRequestValidator {
  const AiRequestValidator();

  void validate(AiRequest request) {
    if (request.requestedTask == null) {
      throw const UnsupportedTaskException(
        'The requested task is not recognised by Kritha.',
      );
    }
    _validateInputs(request);
    if (!request.requestedTask!.executable) {
      throw UnsupportedTaskException(
        'The ${request.requestedTask!.displayName} task has no executable pipeline yet.',
      );
    }
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

  void _validateInputs(AiRequest request) {
    for (final input in request.inputs) {
      switch (input) {
        case AiTextInput(:final value):
          if (value.trim().isEmpty) {
            throw const InvalidRequestException(
              'Text input must not be empty.',
            );
          }
        case AiImageInput(:final bytes, :final mimeType):
          _validateBinary(bytes, mimeType, 'Image');
        case AiAudioInput(:final bytes, :final mimeType):
          _validateBinary(bytes, mimeType, 'Audio');
        case AiVideoInput(:final bytes, :final reference, :final mimeType):
          if (bytes == null &&
              (reference == null || reference.trim().isEmpty)) {
            throw const InvalidRequestException(
              'Video input needs bytes or a reference.',
            );
          }
          if (bytes != null && (mimeType == null || mimeType.trim().isEmpty)) {
            throw const InvalidRequestException(
              'Video bytes need a MIME type.',
            );
          }
      }
    }
    final inputs = request.inputs;
    switch (request.requestedTask) {
      case AiTaskId.imageTextToText:
        if (!inputs.hasImage) _missingModality('an image');
      case AiTaskId.videoTextToText:
        if (!inputs.hasVideo) _missingModality('a video');
      case AiTaskId.audioUnderstanding || AiTaskId.automaticSpeechRecognition:
        if (!inputs.hasAudio) _missingModality('audio');
      case AiTaskId.textGeneration:
      case AiTaskId.textToSpeech:
      case AiTaskId.audioGeneration:
      case AiTaskId.textToImage:
      case AiTaskId.imageEditing:
      case AiTaskId.videoGeneration:
      case AiTaskId.embeddings:
      case null:
        break;
    }
    if (request.requestedTask == AiTaskId.textGeneration &&
        inputs.any((input) => input is! AiTextInput)) {
      throw const UnsupportedTaskException(
        'The text-generation pipeline does not accept binary media inputs.',
      );
    }
  }

  void _validateBinary(Uint8List bytes, String mimeType, String label) {
    if (bytes.isEmpty) {
      throw InvalidRequestException('$label input must not be empty.');
    }
    if (mimeType.trim().isEmpty) {
      throw InvalidRequestException('$label input needs a MIME type.');
    }
  }

  Never _missingModality(String modality) {
    throw InvalidRequestException('This task requires $modality input.');
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
