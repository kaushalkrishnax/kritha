import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/providers/provider_alias.dart';

void main() {
  group('provider alias derivation', () {
    test('uses title-cased domain then subdomain labels', () {
      expect(deriveProviderAlias('https://openai.com/v1'), 'Openai');
      expect(deriveProviderAlias('https://api.openai.com/v1'), 'Openai Api');
      expect(
        deriveProviderAlias('https://api.anthropic.com/v1'),
        'Anthropic Api',
      );
      expect(
        deriveProviderAlias('https://generativelanguage.googleapis.com/v1'),
        'Googleapis Generativelanguage',
      );
      expect(deriveProviderAlias('https://example.com/v1'), 'Example');
      expect(
        deriveProviderAlias('https://api.example.co.uk/v1'),
        'Example Api',
      );
      expect(
        deriveProviderAlias('https://api.example.co.jp/v1'),
        'Example Api',
      );
      expect(
        deriveProviderAlias('https://api.example.com.au/v1'),
        'Example Api',
      );
      expect(deriveProviderAlias('https://foo.github.io/v1'), 'Github Foo');
    });

    test('ignores ports, paths, queries and the www label', () {
      expect(
        deriveProviderAlias('https://www.example.com:8443/v1?region=eu'),
        'Example',
      );
    });

    test('leaves ambiguous hosts empty for manual entry', () {
      expect(deriveProviderAlias('http://localhost:8080/v1'), isNull);
      expect(deriveProviderAlias('http://127.0.0.1:8080/v1'), isNull);
      expect(deriveProviderAlias('https://api.'), isNull);
      expect(deriveProviderAlias('https://api'), isNull);
      expect(deriveProviderAlias('not a url'), isNull);
    });

    test('normalizes aliases consistently for comparison', () {
      expect(normalizeProviderAlias('  My API  '), 'my-api');
      expect(normalizeProviderAlias('API_Example'), 'api-example');
      expect(normalizeProviderAlias('---'), isEmpty);
    });

    test('preserves display aliases with spaces and capitals', () {
      expect(cleanProviderAlias('  My Work API  '), 'My Work API');
      expect(cleanProviderAlias('My   Work  API'), 'My Work API');
      expect(isValidProviderAlias('My Work API'), isTrue);
      expect(isValidProviderAlias('My-API 2'), isTrue);
      expect(isValidProviderAlias('my-api'), isTrue);
      expect(isValidProviderAlias(''), isFalse);
      expect(isValidProviderAlias('---'), isFalse);
    });
  });
}
