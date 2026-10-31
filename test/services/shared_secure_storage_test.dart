import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/models/token/hugging_face_token_store.dart';
import 'package:kritha/features/providers/provider_stores.dart';

import '../support/fake_workspace.dart';

void main() {
  test(
    'feature secret stores share secure storage and retain isolated keys',
    () async {
      final service = InMemorySecureStorageService();
      final hub = SecureHuggingFaceTokenStore(service);
      final providers = SecureProviderCredentialStore(service);

      await hub.writeToken(' hf_secret ');
      await providers.write('openai', ' api_secret ');

      expect(service.values, {
        'kritha.huggingface.token': 'hf_secret',
        'kritha.providers.openai.credential': 'api_secret',
      });
      expect(await hub.readToken(), 'hf_secret');
      expect(await providers.read('openai'), 'api_secret');

      await hub.deleteToken();

      expect(await hub.readToken(), isNull);
      expect(await providers.read('openai'), 'api_secret');
    },
  );
}
