import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../token/hugging_face_token_store.dart';
import 'hugging_face_hub_client.dart';
import 'model_catalogue_repository.dart';

/// Hub transport without LogInterceptor to prevent leaking tokens.
final huggingFaceDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: HuggingFaceHubClient.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'accept': 'application/json'},
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final huggingFaceHubClientProvider = Provider<HuggingFaceHubClient>((ref) {
  return HuggingFaceHubClient(
    ref.watch(huggingFaceDioProvider),
    () => ref.read(huggingFaceTokenStoreProvider).readToken(),
  );
});

final modelCatalogueProvider = Provider<ModelCatalogue>((ref) {
  return ModelCatalogueRepository(ref.watch(huggingFaceHubClientProvider));
});

/// Caches publisher avatars per session.
final publisherAvatarProvider = FutureProvider.family<String?, String>((
  ref,
  publisher,
) async {
  final name = publisher.trim();
  if (name.isEmpty) return null;
  return ref.watch(huggingFaceHubClientProvider).fetchPublisherAvatar(name);
});
