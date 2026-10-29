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

final modelCatalogueProvider = Provider<ModelCatalogue>((ref) {
  final client = HuggingFaceHubClient(
    ref.watch(huggingFaceDioProvider),
    () => ref.read(huggingFaceTokenStoreProvider).readToken(),
  );
  return ModelCatalogueRepository(client);
});
