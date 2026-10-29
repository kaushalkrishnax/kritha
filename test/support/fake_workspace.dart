import 'package:dio/dio.dart';
import 'package:kritha/core/storage/secure_storage_service.dart';
import 'package:kritha/features/models/active/active_models.dart';
import 'package:kritha/features/models/catalogue/catalogue_failure.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';
import 'package:kritha/features/models/catalogue/model_catalogue_repository.dart';
import 'package:kritha/features/models/token/hugging_face_token_store.dart';
import 'package:kritha/features/providers/provider_connection_tester.dart';
import 'package:kritha/features/providers/provider_definition.dart';
import 'package:kritha/features/providers/provider_stores.dart';

class InMemorySecureStorageService implements SecureStorageService {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class InMemoryHuggingFaceTokenStore implements HuggingFaceTokenStore {
  InMemoryHuggingFaceTokenStore([this.token]);

  String? token;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async {
    token = value.trim();
  }

  @override
  Future<void> deleteToken() async {
    token = null;
  }
}

class CatalogueSearchCall {
  const CatalogueSearchCall({
    this.query,
    this.capability,
    this.sort = CatalogueSort.downloads,
    this.limit = 24,
    this.cursor,
  });

  final String? query;
  final ModelCapability? capability;
  final CatalogueSort sort;
  final int limit;
  final String? cursor;
}

class FakeModelCatalogue implements ModelCatalogue {
  FakeModelCatalogue({
    this.pages = const {null: ModelPage(models: [])},
    this.detailsById = const {},
    this.account = const HubAccount(name: 'tester'),
    this.searchFailure,
    this.detailsFailure,
    this.tokenFailure,
  });

  final Map<String?, ModelPage> pages;
  final Map<String, ModelDetails> detailsById;
  final HubAccount account;
  final CatalogueFailure? searchFailure;
  final CatalogueFailure? detailsFailure;
  final CatalogueFailure? tokenFailure;
  final List<CatalogueSearchCall> calls = [];

  @override
  Future<ModelPage> search({
    String? query,
    ModelCapability? capability,
    CatalogueSort sort = CatalogueSort.downloads,
    int limit = 24,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    calls.add(
      CatalogueSearchCall(
        query: query,
        capability: capability,
        sort: sort,
        limit: limit,
        cursor: cursor,
      ),
    );
    if (searchFailure != null) throw searchFailure!;
    return pages[cursor] ?? const ModelPage(models: []);
  }

  @override
  Future<ModelDetails> details(String id, {CancelToken? cancelToken}) async {
    if (detailsFailure != null) throw detailsFailure!;
    final details = detailsById[id];
    if (details == null) {
      throw const CatalogueFailure(
        kind: CatalogueFailureKind.notFound,
        message: 'Repository not found.',
        statusCode: 404,
      );
    }
    return details;
  }

  @override
  Future<HubAccount> validateToken(String token) async {
    if (tokenFailure != null) throw tokenFailure!;
    return account;
  }
}

class InMemoryActiveModelStore implements ActiveModelStore {
  InMemoryActiveModelStore([
    Map<ModelCapability, ActiveModelAssignment>? assignments,
  ]) : assignments = assignments ?? {};

  Map<ModelCapability, ActiveModelAssignment> assignments;

  @override
  Future<Map<ModelCapability, ActiveModelAssignment>> read() async =>
      Map.unmodifiable(assignments);

  @override
  Future<void> write(Map<ModelCapability, ActiveModelAssignment> value) async {
    assignments = Map.of(value);
  }
}

class InMemoryRecentModelStore implements RecentModelStore {
  List<ActiveModelAssignment> models = [];

  @override
  Future<List<ActiveModelAssignment>> read() async => List.unmodifiable(models);

  @override
  Future<void> write(List<ActiveModelAssignment> value) async {
    models = List.of(value);
  }
}

class InMemoryProviderSettingsStore implements ProviderSettingsStore {
  InMemoryProviderSettingsStore([Map<String, StoredProviderSettings>? settings])
    : settings = settings ?? {};

  Map<String, StoredProviderSettings> settings;

  @override
  Future<Map<String, StoredProviderSettings>> read() async =>
      Map.unmodifiable(settings);

  @override
  Future<void> write(Map<String, StoredProviderSettings> value) async {
    settings = Map.of(value);
  }
}

class InMemoryProviderCredentialStore implements ProviderCredentialStore {
  InMemoryProviderCredentialStore([Map<String, String>? credentials])
    : credentials = credentials ?? {};

  Map<String, String> credentials;

  @override
  Future<String?> read(String providerId) async => credentials[providerId];

  @override
  Future<void> write(String providerId, String credential) async {
    credentials[providerId] = credential.trim();
  }

  @override
  Future<void> delete(String providerId) async {
    credentials.remove(providerId);
  }
}

class InMemoryProviderUsageStore implements ProviderUsageStore {
  InMemoryProviderUsageStore([Map<String, ProviderUsage>? usage])
    : usage = usage ?? {};

  Map<String, ProviderUsage> usage;

  @override
  Future<Map<String, ProviderUsage>> read() async => Map.unmodifiable(usage);

  @override
  Future<void> write(Map<String, ProviderUsage> value) async {
    usage = Map.of(value);
  }
}

class FakeProviderConnectionTester implements ProviderConnectionTester {
  FakeProviderConnectionTester({
    this.result = const ProviderConnectionResult(
      ok: true,
      message: 'Endpoint reachable — returned 1 model.',
      statusCode: 200,
      modelCount: 1,
    ),
    this.error,
  });

  ProviderConnectionResult result;
  Object? error;
  final List<String> testedProviderIds = [];
  final Map<String, List<ProviderModelInfo>> models = {};

  @override
  Future<ProviderConnectionResult> test(
    InferenceProviderDefinition definition, {
    required String baseUrl,
    String? credential,
  }) async {
    testedProviderIds.add(definition.id);
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<List<ProviderModelInfo>> listModels(
    InferenceProviderDefinition definition, {
    required String baseUrl,
    String? credential,
  }) async => models[definition.id] ?? const [];
}
