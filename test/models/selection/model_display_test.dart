import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/models/selection/model_display.dart';

void main() {
  group('model display labels', () {
    test('removes the Gemini models prefix without changing other names', () {
      expect(displayModelName('models/gemini-2.5-flash'), 'gemini-2.5-flash');
      expect(displayModelName('gemini-2.5-flash'), 'gemini-2.5-flash');
      expect(displayModelName('gpt-4o'), 'gpt-4o');
      expect(displayModelName('models/'), 'models/');
    });

    test('capitalizes publisher names with their known brand casing', () {
      expect(displayPublisherName('google'), 'Google');
      expect(displayPublisherName('anthropic'), 'Anthropic');
      expect(displayPublisherName('openai'), 'OpenAI');
      expect(displayPublisherName('mistral'), 'Mistral');
      expect(displayPublisherName('custom-provider'), 'Custom-provider');
      expect(displayPublisherName('  google  '), 'Google');
      expect(displayPublisherName(''), '');
    });
  });
}
