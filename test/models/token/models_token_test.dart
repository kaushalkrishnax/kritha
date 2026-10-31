import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/models/catalogue/catalogue_failure.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';
import 'package:kritha/features/models/catalogue/catalogue_providers.dart';
import 'package:kritha/features/models/token/hugging_face_token.dart';
import 'package:kritha/features/models/token/hugging_face_token_store.dart';

import '../../support/fake_workspace.dart';

void main() {
  ProviderContainer buildContainer({
    required InMemoryHuggingFaceTokenStore store,
    required FakeModelCatalogue catalogue,
  }) {
    return ProviderContainer(
      overrides: [
        huggingFaceTokenStoreProvider.overrideWithValue(store),
        modelCatalogueProvider.overrideWithValue(catalogue),
      ],
    );
  }

  test('starts without a token and never exposes one in state', () async {
    final store = InMemoryHuggingFaceTokenStore();
    final container = buildContainer(
      store: store,
      catalogue: FakeModelCatalogue(),
    );
    addTearDown(container.dispose);

    final state = await container.read(huggingFaceTokenProvider.future);
    expect(state.hasToken, isFalse);
    expect(state.accountName, isNull);
  });

  test('validates, saves and removes a token', () async {
    final store = InMemoryHuggingFaceTokenStore();
    final container = buildContainer(
      store: store,
      catalogue: FakeModelCatalogue(account: const HubAccount(name: 'kaushal')),
    );
    addTearDown(container.dispose);
    await container.read(huggingFaceTokenProvider.future);

    final saved = await container
        .read(huggingFaceTokenProvider.notifier)
        .save('  hf_valid  ');

    expect(saved, isTrue);
    expect(store.token, 'hf_valid');
    final state = container.read(huggingFaceTokenProvider).value!;
    expect(state.hasToken, isTrue);
    expect(state.accountName, 'kaushal');
    expect(state.validating, isFalse);

    await container.read(huggingFaceTokenProvider.notifier).remove();
    expect(store.token, isNull);
    expect(container.read(huggingFaceTokenProvider).value!.hasToken, isFalse);
  });

  test('does not save a token rejected by Hugging Face', () async {
    final store = InMemoryHuggingFaceTokenStore();
    final container = buildContainer(
      store: store,
      catalogue: FakeModelCatalogue(
        tokenFailure: const CatalogueFailure(
          kind: CatalogueFailureKind.unauthorized,
          message: 'Rejected',
          statusCode: 401,
        ),
      ),
    );
    addTearDown(container.dispose);
    await container.read(huggingFaceTokenProvider.future);

    final saved = await container
        .read(huggingFaceTokenProvider.notifier)
        .save('hf_bad');

    expect(saved, isFalse);
    expect(store.token, isNull);
    final state = container.read(huggingFaceTokenProvider).value!;
    expect(state.hasToken, isFalse);
    expect(state.error, contains('rejected'));
  });

  test('saves an unverified token when the network is unavailable', () async {
    final store = InMemoryHuggingFaceTokenStore();
    final container = buildContainer(
      store: store,
      catalogue: FakeModelCatalogue(
        tokenFailure: const CatalogueFailure(
          kind: CatalogueFailureKind.offline,
          message: 'Could not reach huggingface.co.',
        ),
      ),
    );
    addTearDown(container.dispose);
    await container.read(huggingFaceTokenProvider.future);

    final saved = await container
        .read(huggingFaceTokenProvider.notifier)
        .save('hf_offline');

    expect(saved, isTrue);
    expect(store.token, 'hf_offline');
    final state = container.read(huggingFaceTokenProvider).value!;
    expect(state.hasToken, isTrue);
    expect(state.notice, contains('could not be verified'));
  });

  test('validates an already saved token', () async {
    final store = InMemoryHuggingFaceTokenStore('hf_saved');
    final container = buildContainer(
      store: store,
      catalogue: FakeModelCatalogue(
        account: const HubAccount(name: 'saved-user'),
      ),
    );
    addTearDown(container.dispose);
    await container.read(huggingFaceTokenProvider.future);

    await container.read(huggingFaceTokenProvider.notifier).validate();

    final state = container.read(huggingFaceTokenProvider).value!;
    expect(state.hasToken, isTrue);
    expect(state.accountName, 'saved-user');
    expect(state.error, isNull);
  });
}
