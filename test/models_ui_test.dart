import 'dart:io';

import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/app.dart';
import 'package:kritha/core/providers.dart';
import 'package:kritha/data/app_database.dart';
import 'package:kritha/features/intelligence/model_configuration.dart';
import 'package:kritha/features/intelligence/providers.dart';
import 'package:kritha/features/models/active/active_models.dart';
import 'package:kritha/features/models/catalogue/catalogue_failure.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';
import 'package:kritha/features/models/catalogue/catalogue_providers.dart';
import 'package:kritha/features/models/token/hugging_face_token_store.dart';
import 'package:kritha/features/providers/provider_connection_tester.dart';
import 'package:kritha/features/providers/provider_stores.dart';
import 'package:kritha/widgets/create_popup.dart';
import 'package:kritha/services/runtime_probe.dart';

import 'support/fake_inference.dart';
import 'support/fake_workspace.dart';

void main() {
  late AppDatabase database;
  late Directory tempDir;
  late String modelPath;

  const runtime = RuntimeStatus(
    liteRtLmReady: true,
    sherpaVersion: '1.13.8',
    onnxRuntimeVersion: '1.24.1',
    sqliteVersion: '3.51.0',
    secureStorageReady: true,
    preferencesReady: true,
    microphone: 'granted',
    recorderReady: true,
    audioPlayerReady: true,
    dioBaseUrl: 'https://api.kritha.app/v1',
    documentsPath: '/data/user/0/com.kritha.app/app_flutter',
  );

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    tempDir = Directory.systemTemp.createTempSync('kritha-ui-');
    modelPath = '${tempDir.path}/local.litertlm';
    File(modelPath).writeAsBytesSync([1, 2, 3]);
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Widget buildApp({
    required FakeModelCatalogue catalogue,
    InMemoryHuggingFaceTokenStore? tokenStore,
    InMemoryActiveModelStore? activeStore,
    InMemoryProviderSettingsStore? providerSettings,
    InMemoryProviderCredentialStore? providerCredentials,
    FakeProviderConnectionTester? tester,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        runtimeStatusProvider.overrideWith((ref) async => runtime),
        modelConfigStoreProvider.overrideWithValue(
          InMemoryModelConfigStore(modelPath),
        ),
        inferenceProvidersProvider.overrideWithValue([FakeInferenceProvider()]),
        modelCatalogueProvider.overrideWithValue(catalogue),
        huggingFaceTokenStoreProvider.overrideWithValue(
          tokenStore ?? InMemoryHuggingFaceTokenStore(),
        ),
        activeModelStoreProvider.overrideWithValue(
          activeStore ?? InMemoryActiveModelStore(),
        ),
        recentModelStoreProvider.overrideWithValue(InMemoryRecentModelStore()),
        providerSettingsStoreProvider.overrideWithValue(
          providerSettings ?? InMemoryProviderSettingsStore(),
        ),
        providerCredentialStoreProvider.overrideWithValue(
          providerCredentials ?? InMemoryProviderCredentialStore(),
        ),
        providerConnectionTesterProvider.overrideWithValue(
          tester ?? FakeProviderConnectionTester(),
        ),
      ],
      child: const KrithaApp(),
    );
  }

  Future<void> pumpApp(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }

  Future<void> openSidebarEntry(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('Sessions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  FakeModelCatalogue catalogueWithModels() {
    const alpha = CatalogueModel(
      id: 'acme/alpha',
      pipelineTag: 'text-generation',
      downloads: 1200,
      likes: 40,
    );
    const beta = CatalogueModel(
      id: 'acme/beta',
      pipelineTag: 'image-text-to-text',
      downloads: 800,
      likes: 20,
    );
    const filtered = CatalogueModel(
      id: 'acme/image-maker',
      pipelineTag: 'text-to-image',
    );
    return FakeModelCatalogue(
      pages: const {
        null: ModelPage(models: [alpha, beta, filtered]),
      },
      detailsById: const {
        'acme/alpha': ModelDetails(
          model: alpha,
          files: [
            ModelFile(path: 'model.litertlm', sizeBytes: 2048),
            ModelFile(path: 'README.md', sizeBytes: 100),
          ],
          readme: '# Alpha model card',
          config: {
            'architectures': ['LlamaForCausalLM'],
          },
        ),
      },
    );
  }

  testWidgets('Models opens on Explore with featured repositories', (
    tester,
  ) async {
    await pumpApp(tester, buildApp(catalogue: catalogueWithModels()));
    await openSidebarEntry(tester, 'Models');

    expect(find.text('Models'), findsOneWidget);
    expect(find.text('Popular on the Hub'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('alpha'), findsWidgets);
    expect(find.text('beta'), findsWidgets);
    expect(find.text('Search Hugging Face models'), findsOneWidget);
    expect(find.text('image-maker'), findsNothing);
  });

  testWidgets('sorting in Explore replaces featured sections with results', (
    tester,
  ) async {
    final catalogue = catalogueWithModels();
    await pumpApp(tester, buildApp(catalogue: catalogue));
    await openSidebarEntry(tester, 'Models');

    await tester.tap(find.byTooltip('Sort models'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Most likes'));
    await tester.pumpAndSettle();

    expect(catalogue.calls.last.sort, CatalogueSort.likes);
    expect(find.text('Popular on the Hub'), findsNothing);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
  });

  testWidgets('clearing search cancels the pending debounce', (tester) async {
    final catalogue = catalogueWithModels();
    await pumpApp(tester, buildApp(catalogue: catalogue));
    await openSidebarEntry(tester, 'Models');

    await tester.enterText(find.byType(TextField).first, 'acme');
    await tester.pump();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Popular on the Hub'), findsOneWidget);
    expect(catalogue.calls.where((call) => call.query == 'acme'), isEmpty);
  });

  testWidgets('search paginates and opens repository details', (tester) async {
    const alpha = CatalogueModel(
      id: 'acme/alpha',
      pipelineTag: 'text-generation',
      downloads: 1200,
      likes: 40,
    );
    const beta = CatalogueModel(
      id: 'acme/beta',
      pipelineTag: 'image-text-to-text',
      downloads: 800,
      likes: 20,
    );
    const imageGeneration = CatalogueModel(
      id: 'acme/image-generation',
      pipelineTag: 'text-to-image',
    );
    const gamma = CatalogueModel(
      id: 'acme/gamma',
      pipelineTag: 'automatic-speech-recognition',
    );
    final catalogue = FakeModelCatalogue(
      pages: const {
        null: ModelPage(
          models: [alpha, beta, imageGeneration],
          nextCursor: 'c1',
        ),
        'c1': ModelPage(models: [gamma, imageGeneration]),
      },
      detailsById: const {
        'acme/alpha': ModelDetails(
          model: alpha,
          files: [ModelFile(path: 'model.litertlm', sizeBytes: 2048)],
          readme: '# Alpha model card',
          config: {
            'architectures': ['LlamaForCausalLM'],
          },
        ),
      },
    );
    await pumpApp(tester, buildApp(catalogue: catalogue));
    await openSidebarEntry(tester, 'Models');

    await tester.enterText(
      find.widgetWithText(TextField, 'Search Hugging Face models'),
      'acme',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('Load more'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('gamma'), findsOneWidget);
    expect(find.text('image-generation'), findsNothing);
    expect(catalogue.calls.last.cursor, 'c1');

    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();
    expect(find.text('Runtime compatibility is not verified'), findsOneWidget);
    expect(find.text('model.litertlm'), findsOneWidget);
    expect(find.textContaining('Alpha model card'), findsOneWidget);
  });

  testWidgets('catalogue failures show an offline state with retry', (
    tester,
  ) async {
    final catalogue = FakeModelCatalogue(
      searchFailure: const CatalogueFailure(
        kind: CatalogueFailureKind.offline,
        message: 'Could not reach huggingface.co. Check your connection.',
      ),
    );
    await pumpApp(tester, buildApp(catalogue: catalogue));
    await openSidebarEntry(tester, 'Models');

    expect(find.text('You appear to be offline'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('rate limits and empty searches render honest states', (
    tester,
  ) async {
    final limited = FakeModelCatalogue(
      searchFailure: const CatalogueFailure(
        kind: CatalogueFailureKind.rateLimited,
        message: 'The Hub rate limit was reached. Wait a moment and retry.',
      ),
    );
    await pumpApp(tester, buildApp(catalogue: limited));
    await openSidebarEntry(tester, 'Models');
    expect(find.text('Hugging Face is rate-limiting requests'), findsOneWidget);
    expect(
      find.textContaining('token raises the authenticated rate limit'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    final empty = FakeModelCatalogue(
      pages: const {null: ModelPage(models: [])},
    );
    await pumpApp(tester, buildApp(catalogue: empty));
    await openSidebarEntry(tester, 'Models');
    await tester.enterText(find.byType(TextField).first, 'no-such-repo');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('No models found'), findsOneWidget);
  });

  testWidgets('token dialog saves without displaying the secret again', (
    tester,
  ) async {
    final tokenStore = InMemoryHuggingFaceTokenStore();
    await pumpApp(
      tester,
      buildApp(catalogue: catalogueWithModels(), tokenStore: tokenStore),
    );
    await openSidebarEntry(tester, 'Models');

    await tester.tap(find.byTooltip('Catalogue options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hugging Face token'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Public model discovery works'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(CreatePopup),
        matching: find.byType(TextField),
      ),
      'hf_secret_value',
    );
    await tester.pump();
    await tester.tap(find.text('Save token'));
    await tester.pumpAndSettle();

    expect(find.text('Signed in as tester.'), findsOneWidget);
    expect(find.text('hf_secret_value'), findsNothing);
    expect(tokenStore.token, 'hf_secret_value');

    await tester.tap(find.text('Remove token'));
    await tester.pumpAndSettle();
    expect(find.text('Add a token'), findsOneWidget);
    expect(tokenStore.token, isNull);
  });

  testWidgets('Active models picker assigns the validated local text model', (
    tester,
  ) async {
    await pumpApp(tester, buildApp(catalogue: catalogueWithModels()));
    await openSidebarEntry(tester, 'Models');
    await tester.tap(find.byTooltip('Active models'));
    await tester.pumpAndSettle();

    expect(find.text('Active models'), findsOneWidget);
    expect(find.text('Choose model'), findsWidgets);

    await tester.tap(find.text('Choose model').first);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('local'));
    await tester.pumpAndSettle();
    expect(find.text('Assigned'), findsOneWidget);
    expect(find.text('Remove assignment'), findsOneWidget);
  });

  testWidgets(
    'Providers connects a hosted provider and keeps keys out of view',
    (tester) async {
      final credentials = InMemoryProviderCredentialStore();
      final connectionTester = FakeProviderConnectionTester()
        ..models['openai'] = const [
          ProviderModelInfo(id: 'gpt-4o', name: 'GPT-4o'),
        ];
      await pumpApp(
        tester,
        buildApp(
          catalogue: catalogueWithModels(),
          providerCredentials: credentials,
          tester: connectionTester,
        ),
      );
      await openSidebarEntry(tester, 'Providers');

      expect(find.text('OpenAI'), findsOneWidget);
      expect(find.text('Anthropic'), findsOneWidget);
      expect(find.text('Google Gemini'), findsOneWidget);
      expect(find.text('Mistral AI'), findsOneWidget);
      expect(find.text('Local models'), findsNothing);

      await tester.tap(find.text('Connect').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'sk-secret');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(credentials.credentials['openai'], 'sk-secret');
      expect(find.text('Provider settings saved'), findsOneWidget);
      expect(find.text('sk-secret'), findsNothing);

      await tester.tap(find.text('Connect').first);
      await tester.pumpAndSettle();
      expect(
        find.text('Leave blank to keep the saved credential'),
        findsOneWidget,
      );
      expect(find.text('sk-secret'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Provider actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test connection'));
      await tester.pumpAndSettle();
      expect(connectionTester.testedProviderIds, ['openai']);
      expect(find.textContaining('Endpoint reachable'), findsOneWidget);

      await tester.tap(find.text('Available models').first);
      await tester.pumpAndSettle();
      expect(find.text('Active models'), findsOneWidget);
    },
  );
}
