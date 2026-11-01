import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/intelligence/models/ai_request.dart';
import 'package:kritha/features/intelligence/models/model_capabilities.dart';
import 'package:kritha/features/intelligence/models/task_registry.dart';
import 'package:kritha/features/intelligence/request_validation.dart';

void main() {
  test('uses stable task IDs and preserves unknown tags as unknown', () {
    expect(AiTaskId.textGeneration.id, 'text_generation');
    expect(taskFromPipelineTag('text-generation'), AiTaskId.textGeneration);
    expect(taskFromPipelineTag('future-task'), isNull);
  });

  test(
    'task metadata drives request requirements without changing chat defaults',
    () {
      final text = AiRequest(messages: [AiMessage.user('hello')]);
      expect(text.requestedTask, AiTaskId.textGeneration);
      expect(text.requiredCapabilities, {InferenceCapability.textGeneration});

      final visual = AiRequest(
        messages: [AiMessage.user('describe')],
        metadata: {'task_id': AiTaskId.imageTextToText.id},
      );
      expect(
        visual.requiredCapabilities,
        containsAll({
          InferenceCapability.textGeneration,
          InferenceCapability.imageInput,
        }),
      );
    },
  );

  test('unknown and non-executable tasks fail explicitly', () {
    const validator = AiRequestValidator();
    expect(
      () => validator.validate(
        AiRequest(
          messages: [AiMessage.user('hello')],
          metadata: {'task_id': 'future_task'},
        ),
      ),
      throwsA(isA<Exception>()),
    );
    expect(
      () => validator.validate(
        AiRequest(
          messages: [AiMessage.user('hello')],
          metadata: {'task_id': AiTaskId.embeddings.id},
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });
}
