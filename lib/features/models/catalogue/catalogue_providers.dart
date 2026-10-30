import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../token/hugging_face_token_store.dart';
import 'hugging_face_hub_client.dart';
import 'model_catalogue_repository.dart';

/// Dedicated Hub transport. It deliberately has no `LogInterceptor` so a
/// Hugging Face token can never be written to the console.
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

/// Publisher avatars are not part of the model list payload, so each unique
/// publisher is resolved once and kept for the session.
final publisherAvatarProvider = FutureProvider.family<String?, String>((
  ref,
  publisher,
) async {
  final name = publisher.trim();
  if (name.isEmpty) return null;
  return ref.watch(huggingFaceHubClientProvider).fetchPublisherAvatar(name);
});
