import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/intelligence/intelligence_exception.dart';
import 'package:kritha/features/intelligence/models/ai_request.dart';
import 'package:kritha/features/intelligence/request_validation.dart';

void main() {
  const validator = AiRequestValidator();

  AiRequest request({
    List<AiMessage>? messages,
    AiGenerationOptions options = const AiGenerationOptions(),
    String? modelId,
  }) {
    return AiRequest(
      messages: messages ?? [AiMessage.user('Hello')],
      options: options,
      modelId: modelId,
    );
  }

  Matcher invalidRequest() => throwsA(isA<InvalidRequestException>());

  test('accepts a system prompt followed by conversation ending in user', () {
    expect(
      () => validator.validate(
        request(
          messages: [
            AiMessage.system('Be concise.'),
            AiMessage.user('First'),
            AiMessage.assistant('First answer'),
            AiMessage.user('Second'),
          ],
        ),
      ),
      returnsNormally,
    );
  });

  test('rejects an empty message list', () {
    expect(() => validator.validate(request(messages: [])), invalidRequest());
  });

  test('rejects empty text in any message', () {
    expect(
      () => validator.validate(
        request(messages: [AiMessage.system('  '), AiMessage.user('Hello')]),
      ),
      invalidRequest(),
    );
    expect(
      () => validator.validate(
        request(
          messages: [
            AiMessage.user('Hello'),
            AiMessage.assistant(''),
            AiMessage.user('Again'),
          ],
        ),
      ),
      invalidRequest(),
    );
    expect(
      () => validator.validate(request(messages: [AiMessage.user('   ')])),
      invalidRequest(),
    );
  });

  test('rejects system messages after conversation turns begin', () {
    expect(
      () => validator.validate(
        request(
          messages: [
            AiMessage.user('Hello'),
            AiMessage.system('Late instruction'),
            AiMessage.user('Again'),
          ],
        ),
      ),
      invalidRequest(),
    );
  });

  test('requires the final message to be a user turn', () {
    expect(
      () => validator.validate(
        request(messages: [AiMessage.assistant('Not a prompt')]),
      ),
      invalidRequest(),
    );
    expect(
      () => validator.validate(
        request(
          messages: [AiMessage.user('Hello'), AiMessage.assistant('Answer')],
        ),
      ),
      invalidRequest(),
    );
  });

  test('rejects a blank requested model id', () {
    expect(() => validator.validate(request(modelId: '  ')), invalidRequest());
  });

  test('rejects invalid sampler options', () {
    final invalid = <AiGenerationOptions>[
      const AiGenerationOptions(temperature: -1),
      const AiGenerationOptions(temperature: double.nan),
      const AiGenerationOptions(temperature: double.infinity),
      const AiGenerationOptions(topP: 0),
      const AiGenerationOptions(topP: 1.01),
      const AiGenerationOptions(topP: double.nan),
      const AiGenerationOptions(topK: 0),
      const AiGenerationOptions(topK: -1),
      const AiGenerationOptions(seed: -1),
      const AiGenerationOptions(maxOutputTokens: 0),
      const AiGenerationOptions(maxOutputTokens: -1),
    ];

    for (final options in invalid) {
      expect(
        () => validator.validate(request(options: options)),
        invalidRequest(),
        reason: '$options should be invalid',
      );
    }
  });

  test('accepts boundary sampler options', () {
    expect(
      () => validator.validate(
        request(
          options: const AiGenerationOptions(
            temperature: 0,
            topP: 1,
            topK: 1,
            seed: 0,
            maxOutputTokens: 1,
          ),
        ),
      ),
      returnsNormally,
    );
  });
}
