import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalogue/catalogue_failure.dart';
import '../catalogue/catalogue_providers.dart';
import 'hugging_face_token_store.dart';

class HuggingFaceTokenState {
  const HuggingFaceTokenState({
    this.hasToken = false,
    this.accountName,
    this.validating = false,
    this.error,
    this.notice,
  });

  final bool hasToken;
  final String? accountName;
  final bool validating;
  final String? error;
  final String? notice;

  HuggingFaceTokenState copyWith({
    bool? hasToken,
    String? accountName,
    bool? validating,
    String? error,
    String? notice,
    bool clearAccount = false,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return HuggingFaceTokenState(
      hasToken: hasToken ?? this.hasToken,
      accountName: clearAccount ? null : (accountName ?? this.accountName),
      validating: validating ?? this.validating,
      error: clearError ? null : (error ?? this.error),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

class HuggingFaceTokenController extends AsyncNotifier<HuggingFaceTokenState> {
  int _revision = 0;

  @override
  Future<HuggingFaceTokenState> build() async {
    final store = ref.watch(huggingFaceTokenStoreProvider);
    final token = await store.readToken();
    return HuggingFaceTokenState(hasToken: token != null);
  }

  /// Validates first, then persists. An explicitly rejected token is never
  /// stored. A network failure stores it with an honest "unverified" notice.
  Future<bool> save(String rawToken) async {
    final token = rawToken.trim();
    if (token.isEmpty) return false;
    final revision = ++_revision;
    final current = state.value ?? const HuggingFaceTokenState();
    state = AsyncData(
      current.copyWith(validating: true, clearError: true, clearNotice: true),
    );
    try {
      final account = await ref
          .read(modelCatalogueProvider)
          .validateToken(token);
      await ref.read(huggingFaceTokenStoreProvider).writeToken(token);
      if (!ref.mounted || revision != _revision) return false;
      state = AsyncData(
        HuggingFaceTokenState(hasToken: true, accountName: account.name),
      );
      return true;
    } on CatalogueFailure catch (failure) {
      if (failure.kind == CatalogueFailureKind.unauthorized) {
        if (ref.mounted && revision == _revision) {
          state = AsyncData(
            current.copyWith(
              validating: false,
              error: 'Hugging Face rejected this token. It was not saved.',
            ),
          );
        }
        return false;
      }
      await ref.read(huggingFaceTokenStoreProvider).writeToken(token);
      if (!ref.mounted || revision != _revision) return false;
      state = AsyncData(
        HuggingFaceTokenState(
          hasToken: true,
          notice:
              'Token saved, but it could not be verified: ${failure.message}',
        ),
      );
      return true;
    } on Object {
      if (ref.mounted && revision == _revision) {
        state = AsyncData(
          current.copyWith(
            validating: false,
            error: 'The token could not be saved.',
          ),
        );
      }
      return false;
    }
  }

  Future<void> validate() async {
    final revision = ++_revision;
    final store = ref.read(huggingFaceTokenStoreProvider);
    final token = await store.readToken();
    if (!ref.mounted || revision != _revision) return;
    if (token == null) {
      state = AsyncData(const HuggingFaceTokenState());
      return;
    }
    final current = state.value ?? HuggingFaceTokenState(hasToken: true);
    state = AsyncData(
      current.copyWith(validating: true, clearError: true, clearNotice: true),
    );
    try {
      final account = await ref
          .read(modelCatalogueProvider)
          .validateToken(token);
      if (!ref.mounted || revision != _revision) return;
      state = AsyncData(
        HuggingFaceTokenState(hasToken: true, accountName: account.name),
      );
    } on CatalogueFailure catch (failure) {
      if (!ref.mounted || revision != _revision) return;
      if (failure.kind == CatalogueFailureKind.unauthorized) {
        state = AsyncData(
          current.copyWith(
            validating: false,
            error: 'The saved token was rejected. Replace or remove it before using gated repositories.',
          ),
        );
        return;
      }
      state = AsyncData(
        current.copyWith(
          validating: false,
          notice: 'Could not verify the token: ${failure.message}',
        ),
      );
    }
  }

  Future<void> remove() async {
    final revision = ++_revision;
    await ref.read(huggingFaceTokenStoreProvider).deleteToken();
    if (!ref.mounted || revision != _revision) return;
    state = const AsyncData(HuggingFaceTokenState());
  }
}

final huggingFaceTokenProvider =
    AsyncNotifierProvider<HuggingFaceTokenController, HuggingFaceTokenState>(
      HuggingFaceTokenController.new,
    );
