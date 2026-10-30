import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:kritha/app.dart';
import 'package:kritha/core/providers.dart';
import 'package:kritha/core/theme.dart';
import 'package:kritha/data/app_database.dart';
import 'package:kritha/features/intelligence/model_configuration.dart';
import 'package:kritha/features/intelligence/providers.dart';
import 'package:kritha/features/intelligence/runtime_ids.dart';
import 'package:kritha/features/models/active/active_models.dart';
import 'package:kritha/features/models/catalogue/catalogue_failure.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';
import 'package:kritha/features/models/catalogue/catalogue_providers.dart';
import 'package:kritha/features/models/token/hugging_face_token_store.dart';
import 'package:kritha/features/models/widgets/catalogue_widgets.dart';
import 'package:kritha/features/providers/provider_connection_tester.dart';
import 'package:kritha/features/providers/provider_definition.dart';
import 'package:kritha/features/providers/providers_controller.dart';
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
    InMemoryRecentModelStore? recentStore,
    InMemoryProviderSettingsStore? providerSettings,
    InMemoryProviderCredentialStore? providerCredentials,
    InMemoryProviderUsageStore? providerUsage,
    ProviderConnectionTester? tester,
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
        recentModelStoreProvider.overrideWithValue(
          recentStore ?? InMemoryRecentModelStore(),
        ),
        providerSettingsStoreProvider.overrideWithValue(
          providerSettings ?? InMemoryProviderSettingsStore(),
        ),
        providerCredentialStoreProvider.overrideWithValue(
          providerCredentials ?? InMemoryProviderCredentialStore(),
        ),
        providerUsageStoreProvider.overrideWithValue(
          providerUsage ?? InMemoryProviderUsageStore(),
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

  Future<void> openTextModelPicker(WidgetTester tester) async {
    await openSidebarEntry(tester, 'Models');
    await tester.tap(find.byTooltip('Active models'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose model').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  FakeModelCatalogue catalogueWithModels() {
    const alpha = CatalogueModel(
      id: 'acme/alpha',
      pipelineTag: 'text-generation',
      downloads: 1200,
      likes: 40,
      parameterCount: 7000000000,
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

  testWidgets('Models opens on trending repositories', (tester) async {
    final catalogue = catalogueWithModels();
    await pumpApp(tester, buildApp(catalogue: catalogue));
    await openSidebarEntry(tester, 'Models');

    expect(find.text('Models'), findsOneWidget);
    expect(catalogue.calls.single.sort, CatalogueSort.trending);
    expect(find.text('Popular on the Hub'), findsNothing);
    expect(find.text('Recommended'), findsNothing);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('Search Hugging Face models'), findsOneWidget);
    expect(find.text('image-maker'), findsNothing);
    expect(find.text('7B'), findsWidgets);
    expect(find.text('•'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is KrithaIcon &&
            widget.icon == HugeIcons.strokeRoundedChartScatter,
      ),
      findsOneWidget,
    );
  });

  testWidgets('All tab uses the search result list layout vertically', (
    tester,
  ) async {
    await pumpApp(tester, buildApp(catalogue: catalogueWithModels()));
    await openSidebarEntry(tester, 'Models');

    expect(find.byType(ModelCard), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ListView && widget.scrollDirection == Axis.horizontal,
        ),
      ),
      findsNothing,
    );

    final first = find.byType(ModelCard).at(0);
    final second = find.byType(ModelCard).at(1);
    expect(tester.getTopLeft(first).dx, tester.getTopLeft(second).dx);
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
    expect(tester.widget<ModelCard>(first).width, isNull);
  });

  testWidgets('nested workspaces return through the navigation stack', (
    tester,
  ) async {
    await pumpApp(tester, buildApp(catalogue: catalogueWithModels()));
    await openSidebarEntry(tester, 'Models');

    await tester.tap(find.byTooltip('Active models'));
    await tester.pumpAndSettle();
    expect(find.text('Active models'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('alpha'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Start a new chat'), findsOneWidget);
  });

  testWidgets('Escape returns to the previous workspace', (tester) async {
    await pumpApp(tester, buildApp(catalogue: catalogueWithModels()));
    await openSidebarEntry(tester, 'Models');

    await tester.tap(find.byTooltip('Active models'));
    await tester.pumpAndSettle();
    expect(find.text('Active models'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('alpha'), findsOneWidget);
  });

  testWidgets('system back returns to the previous workspace', (tester) async {
    await pumpApp(tester, buildApp(catalogue: catalogueWithModels()));
    await openSidebarEntry(tester, 'Models');

    await tester.tap(find.byTooltip('Active models'));
    await tester.pumpAndSettle();
    expect(find.text('Active models'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('alpha'), findsOneWidget);
  });

  testWidgets('Escape dismisses a menu before leaving the workspace', (
    tester,
  ) async {
    await pumpApp(tester, buildApp(catalogue: catalogueWithModels()));
    await openSidebarEntry(tester, 'Models');

    await tester.tap(find.byTooltip('Sort models'));
    await tester.pumpAndSettle();
    expect(find.text('Most likes'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Most likes'), findsNothing);
    expect(find.text('alpha'), findsOneWidget);
  });

  testWidgets('sorting the All tab requests the selected ranking', (
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
    expect(catalogue.calls.last.query, isEmpty);
    expect(catalogue.calls.last.capability, isNull);
    expect(find.text('Popular on the Hub'), findsNothing);
    expect(find.text('Recommended'), findsNothing);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
  });

  testWidgets('category filters keep the trending ranking', (tester) async {
    final catalogue = catalogueWithModels();
    await pumpApp(tester, buildApp(catalogue: catalogue));
    await openSidebarEntry(tester, 'Models');

    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();

    expect(catalogue.calls.last.capability, ModelCapability.text);
    expect(catalogue.calls.last.sort, CatalogueSort.trending);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(catalogue.calls.last.capability, isNull);
    expect(catalogue.calls.last.sort, CatalogueSort.trending);
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

    expect(find.text('alpha'), findsOneWidget);
    expect(catalogue.calls.where((call) => call.query == 'acme'), isEmpty);
    expect(catalogue.calls.last.sort, CatalogueSort.trending);
    expect(catalogue.calls.last.query, isEmpty);
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
    expect(find.text('Model Overview'), findsOneWidget);
    expect(find.text('Model Setup'), findsOneWidget);
    expect(find.text('Model Card'), findsOneWidget);
    expect(find.text('Model Files'), findsOneWidget);
    expect(find.text('Setup Now'), findsOneWidget);
    expect(find.text('View more'), findsOneWidget);
    expect(find.text('model.litertlm'), findsOneWidget);
    expect(find.textContaining('Alpha model card'), findsOneWidget);
  });

  testWidgets('repository details render honest empty states', (tester) async {
    const empty = CatalogueModel(id: 'acme/empty');
    final catalogue = FakeModelCatalogue(
      pages: const {
        null: ModelPage(models: [empty]),
      },
      detailsById: const {'acme/empty': ModelDetails(model: empty)},
    );
    await pumpApp(tester, buildApp(catalogue: catalogue));
    await openSidebarEntry(tester, 'Models');

    await tester.tap(find.text('empty'));
    await tester.pumpAndSettle();

    expect(find.text('No model card'), findsOneWidget);
    expect(find.text('No files'), findsOneWidget);
    expect(
      find.text('No technical metadata was declared for this repository.'),
      findsOneWidget,
    );
    expect(
      find.text('No metadata tags were returned for this repository.'),
      findsOneWidget,
    );
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

  testWidgets('model picker formats Gemini names and publisher labels', (
    tester,
  ) async {
    final recentStore = InMemoryRecentModelStore()
      ..models = [
        ActiveModelAssignment(
          capability: ModelCapability.text,
          modelId: 'models/gemini-2.5-flash',
          displayName: 'models/gemini-2.5-flash',
          runtimeId: geminiRuntimeId,
          sourceId: 'google',
          activatedAt: DateTime(2026),
        ),
      ];
    final connectionTester = FakeProviderConnectionTester()
      ..models['google'] = const [
        ProviderModelInfo(
          id: 'models/gemini-2.5-flash',
          name: 'models/gemini-2.5-flash',
        ),
        ProviderModelInfo(
          id: 'models/gemini-2.5-pro',
          name: 'models/gemini-2.5-pro',
        ),
      ];
    final activeStore = InMemoryActiveModelStore();
    await pumpApp(
      tester,
      buildApp(
        catalogue: catalogueWithModels(),
        activeStore: activeStore,
        recentStore: recentStore,
        providerSettings: InMemoryProviderSettingsStore({
          'google': const StoredProviderSettings(
            baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
            configured: true,
          ),
        }),
        providerCredentials: InMemoryProviderCredentialStore({
          'google': 'gemini-key',
        }),
        tester: connectionTester,
      ),
    );
    await openSidebarEntry(tester, 'Models');
    await tester.tap(find.byTooltip('Active models'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose model').first);
    await tester.pumpAndSettle();

    expect(find.text('models/gemini-2.5-flash'), findsNothing);
    expect(find.text('models/gemini-2.5-pro'), findsNothing);
    expect(find.text('gemini-2.5-flash'), findsWidgets);
    expect(find.text('gemini-2.5-pro'), findsWidgets);
    expect(find.text('Google'), findsWidgets);
    expect(find.text('google'), findsNothing);

    await tester.tap(find.text('gemini-2.5-pro'));
    await tester.pumpAndSettle();
    expect(
      activeStore.assignments[ModelCapability.text]?.modelId,
      'models/gemini-2.5-pro',
    );

    final message = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.textSpan?.toPlainText() ==
                'gemini-2.5-pro is assigned through Google.',
      ),
    );
    final spans = (message.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans[0].text, 'gemini-2.5-pro');
    expect(spans[0].style?.fontWeight, FontWeight.w700);
    expect(spans[2].text, 'Google');
    expect(spans[2].style?.fontWeight, FontWeight.w700);
  });

  testWidgets('provider models show loading then success and empty', (
    tester,
  ) async {
    final controlled = _ControlledProviderConnectionTester();
    await pumpApp(
      tester,
      buildApp(
        catalogue: catalogueWithModels(),
        providerSettings: InMemoryProviderSettingsStore({
          'openai': const StoredProviderSettings(
            baseUrl: 'https://api.openai.com/v1',
            configured: true,
          ),
        }),
        providerCredentials: InMemoryProviderCredentialStore({
          'openai': 'sk-test',
        }),
        tester: controlled,
      ),
    );
    await openTextModelPicker(tester);

    expect(find.text('Loading provider models…'), findsOneWidget);
    expect(
      find.text('Could not load models. Check the provider configuration.'),
      findsNothing,
    );

    controlled.completeModels(0, const [
      ProviderModelInfo(id: 'gpt-4o', name: 'GPT-4o'),
    ]);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('GPT-4o'), findsOneWidget);
    expect(find.text('Loading provider models…'), findsNothing);
    expect(
      find.text('Could not load models. Check the provider configuration.'),
      findsNothing,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CreatePopup)),
    );
    container.invalidate(providerModelsProvider('openai'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Loading provider models…'), findsOneWidget);
    expect(
      find.text('Could not load models. Check the provider configuration.'),
      findsNothing,
    );

    controlled.completeModels(1, const []);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('GPT-4o'), findsNothing);
    expect(find.text('Loading provider models…'), findsNothing);
    expect(
      find.text('Could not load models. Check the provider configuration.'),
      findsNothing,
    );
  });

  testWidgets('custom provider error clears when the request is retried', (
    tester,
  ) async {
    final controlled = _ControlledProviderConnectionTester();
    const providerId = 'custom-retry';
    await pumpApp(
      tester,
      buildApp(
        catalogue: catalogueWithModels(),
        providerSettings: InMemoryProviderSettingsStore({
          providerId: const StoredProviderSettings(
            baseUrl: 'https://api.example.com/v1',
            configured: true,
            alias: 'my-api',
          ),
        }),
        tester: controlled,
      ),
    );
    await openTextModelPicker(tester);

    controlled.failModels(0, StateError('provider failed'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Could not load models. Check the provider configuration.'),
      findsOneWidget,
    );
    expect(find.text('Loading provider models…'), findsNothing);
    expect(find.text('Manage providers'), findsOneWidget);
    expect(find.text('Manage provider'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CreatePopup)),
    );
    container.invalidate(providerModelsProvider(providerId));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Loading provider models…'), findsOneWidget);
    expect(
      find.text('Could not load models. Check the provider configuration.'),
      findsNothing,
    );

    controlled.completeModels(1, const [
      ProviderModelInfo(id: 'shared:model', name: 'Shared'),
    ]);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Shared'), findsOneWidget);
    expect(find.text('Loading provider models…'), findsNothing);
    expect(
      find.text('Could not load models. Check the provider configuration.'),
      findsNothing,
    );
  });

  testWidgets('provider model error action opens the Providers workspace', (
    tester,
  ) async {
    final controlled = _ControlledProviderConnectionTester();
    await pumpApp(
      tester,
      buildApp(
        catalogue: catalogueWithModels(),
        providerSettings: InMemoryProviderSettingsStore({
          'openai': const StoredProviderSettings(
            baseUrl: 'https://api.openai.com/v1',
            configured: true,
          ),
        }),
        providerCredentials: InMemoryProviderCredentialStore({
          'openai': 'sk-test',
        }),
        tester: controlled,
      ),
    );
    await openTextModelPicker(tester);

    controlled.failModels(0, StateError('provider failed'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Manage providers'));
    await tester.pumpAndSettle();

    expect(find.text('Providers'), findsOneWidget);
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
      expect(find.text('Groq'), findsOneWidget);
      expect(find.text('Mistral AI'), findsOneWidget);
      expect(find.text('Local models'), findsNothing);
      expect(find.text('Available models'), findsNothing);
      expect(find.byTooltip('Provider actions'), findsNothing);
      expect(find.text('Test'), findsNothing);
      expect(find.text('Usage'), findsNothing);
      expect(find.text('Connect'), findsNWidgets(10));
      expect(find.text('Configure'), findsNothing);
      expect(find.byTooltip('Configured'), findsNothing);
      expect(find.byType(OutlinedButton), findsNWidgets(10));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is KrithaIcon &&
              widget.icon == HugeIcons.strokeRoundedPlus,
        ),
        findsNWidgets(10),
      );

      await tester.tap(find.text('Connect').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'sk-secret');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(credentials.credentials['openai'], 'sk-secret');
      expect(find.text('Provider settings saved'), findsOneWidget);
      expect(find.text('sk-secret'), findsNothing);
      expect(find.text('Test'), findsOneWidget);
      expect(find.text('Usage'), findsOneWidget);
      expect(find.text('Configure'), findsOneWidget);
      expect(find.text('Connect'), findsNWidgets(9));
      expect(find.byTooltip('Configured'), findsOneWidget);
      final tick = find.descendant(
        of: find.byTooltip('Configured'),
        matching: find.byType(KrithaIcon),
      );
      expect(tester.widget<KrithaIcon>(tick).color, KrithaColors.success);

      await tester.tap(find.text('Configure').first);
      await tester.pumpAndSettle();
      expect(
        find.text('Leave blank to keep the saved credential'),
        findsOneWidget,
      );
      expect(find.text('sk-secret'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test').first);
      await tester.pumpAndSettle();
      expect(connectionTester.testedProviderIds, ['openai']);
      expect(find.textContaining('Endpoint reachable'), findsOneWidget);
      expect(find.text('Test'), findsOneWidget);

      await tester.tap(find.text('Configure').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(credentials.credentials.containsKey('openai'), isFalse);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('OpenAI'), findsOneWidget);
      expect(find.byTooltip('Configured'), findsNothing);
      expect(find.text('Test'), findsNothing);
      expect(find.text('Usage'), findsNothing);
      expect(find.text('Configure'), findsNothing);
      expect(find.text('Connect'), findsNWidgets(10));
    },
  );

  testWidgets(
    'provider cards sort configured providers first without section headings',
    (tester) async {
      final credentials = InMemoryProviderCredentialStore({
        'openai': 'sk-openai',
        'mistral': 'sk-mistral',
      });
      await pumpApp(
        tester,
        buildApp(
          catalogue: catalogueWithModels(),
          providerCredentials: credentials,
        ),
      );
      await openSidebarEntry(tester, 'Providers');

      double top(String label) => tester.getTopLeft(find.text(label)).dy;

      expect(top('OpenAI'), lessThan(top('Mistral AI')));
      expect(top('Mistral AI'), lessThan(top('Anthropic')));
      expect(top('Anthropic'), lessThan(top('Google Gemini')));
      expect(find.byTooltip('Configured'), findsNWidgets(2));
      expect(find.text('Usage'), findsNWidgets(2));
      expect(find.text('Configure'), findsNWidgets(2));
      expect(find.text('Connect'), findsNWidgets(8));
      expect(find.text('Test'), findsNWidgets(2));
      expect(find.text('Configured'), findsNothing);
      expect(find.text('Not configured'), findsNothing);
    },
  );

  testWidgets('Usage shows locally tracked counts without fabricating values', (
    tester,
  ) async {
    await pumpApp(
      tester,
      buildApp(
        catalogue: catalogueWithModels(),
        providerSettings: InMemoryProviderSettingsStore({
          'openai': const StoredProviderSettings(
            baseUrl: 'https://api.openai.com/v1',
          ),
        }),
        providerCredentials: InMemoryProviderCredentialStore({
          'openai': 'sk-openai',
        }),
        providerUsage: InMemoryProviderUsageStore({
          'openai': const ProviderUsage(requests: 7, successes: 5, failures: 2),
        }),
      ),
    );
    await openSidebarEntry(tester, 'Providers');

    await tester.tap(find.text('Usage'));
    await tester.pumpAndSettle();

    expect(find.text('OpenAI usage'), findsOneWidget);
    expect(find.text('Total API requests'), findsOneWidget);
    expect(find.text('Successful responses'), findsOneWidget);
    expect(find.text('Failed requests'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('No usage has been recorded'), findsNothing);
  });

  testWidgets('Usage starts at zero when no requests have been recorded', (
    tester,
  ) async {
    await pumpApp(
      tester,
      buildApp(
        catalogue: catalogueWithModels(),
        providerSettings: InMemoryProviderSettingsStore({
          'openai': const StoredProviderSettings(
            baseUrl: 'https://api.openai.com/v1',
          ),
        }),
        providerCredentials: InMemoryProviderCredentialStore({
          'openai': 'sk-openai',
        }),
      ),
    );
    await openSidebarEntry(tester, 'Providers');

    await tester.tap(find.text('Usage'));
    await tester.pumpAndSettle();

    expect(find.text('OpenAI usage'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
    expect(
      find.textContaining('No usage has been recorded yet'),
      findsOneWidget,
    );
  });

  testWidgets('custom providers respect optional credentials in sorting', (
    tester,
  ) async {
    final settings = InMemoryProviderSettingsStore({
      'openai': const StoredProviderSettings(
        baseUrl: 'https://api.openai.com/v1',
        configured: true,
      ),
      'custom-sort': const StoredProviderSettings(
        baseUrl: 'https://api.example.com/v1',
        configured: true,
        alias: 'my-api',
      ),
    });
    final credentials = InMemoryProviderCredentialStore({
      'openai': 'sk-openai',
    });
    await pumpApp(
      tester,
      buildApp(
        catalogue: catalogueWithModels(),
        providerSettings: settings,
        providerCredentials: credentials,
      ),
    );
    await openSidebarEntry(tester, 'Providers');

    double top(String label) => tester.getTopLeft(find.text(label)).dy;

    expect(top('OpenAI'), lessThan(top('my-api')));
    expect(top('my-api'), lessThan(top('Anthropic')));
    expect(top('Anthropic'), lessThan(top('Google Gemini')));
    expect(find.byTooltip('Configured'), findsNWidgets(2));
    expect(find.text('Test'), findsNWidgets(2));
    expect(find.text('Usage'), findsNWidgets(2));
    expect(find.text('Configure'), findsNWidgets(2));
    expect(find.text('Connect'), findsNWidgets(9));
  });

  testWidgets('provider actions stay hidden until credentials are configured', (
    tester,
  ) async {
    final connectionTester = FakeProviderConnectionTester();
    await pumpApp(
      tester,
      buildApp(catalogue: catalogueWithModels(), tester: connectionTester),
    );
    await openSidebarEntry(tester, 'Providers');

    expect(find.text('Connect'), findsNWidgets(10));
    expect(find.text('Test'), findsNothing);
    expect(find.text('Usage'), findsNothing);
    expect(find.text('Configure'), findsNothing);
    expect(connectionTester.testedProviderIds, isEmpty);
  });

  testWidgets('removing a custom credential keeps the provider', (
    tester,
  ) async {
    final settings = InMemoryProviderSettingsStore({
      'custom-remove': const StoredProviderSettings(
        baseUrl: 'https://api.example.com/v1',
        configured: true,
        alias: 'my-api',
      ),
    });
    final credentials = InMemoryProviderCredentialStore({
      'custom-remove': 'custom-secret',
    });
    await pumpApp(
      tester,
      buildApp(
        catalogue: catalogueWithModels(),
        providerSettings: settings,
        providerCredentials: credentials,
      ),
    );
    await openSidebarEntry(tester, 'Providers');

    expect(find.text('my-api'), findsOneWidget);
    expect(find.byTooltip('Configured'), findsOneWidget);
    expect(find.text('Configure'), findsOneWidget);

    await tester.tap(find.text('Configure').first);
    await tester.pumpAndSettle();
    expect(
      find.text('An API key is saved and is never displayed.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(credentials.credentials.containsKey('custom-remove'), isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('my-api'), findsOneWidget);
    expect(settings.settings.containsKey('custom-remove'), isTrue);
    expect(find.byTooltip('Configured'), findsOneWidget);
    expect(find.text('Configure'), findsOneWidget);
    expect(find.text('Connect'), findsNWidgets(10));
  });

  testWidgets(
    'custom provider alias stays empty until an incomplete URL is finished',
    (tester) async {
      await pumpApp(tester, buildApp(catalogue: catalogueWithModels()));
      await openSidebarEntry(tester, 'Providers');

      await tester.tap(
        find.byTooltip('Add a custom OpenAI-compatible provider'),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'https://api.');
      await tester.tap(fields.at(1));
      await tester.pump();
      expect(tester.widget<TextField>(fields.at(2)).controller!.text, isEmpty);

      await tester.enterText(fields.at(0), 'https://api.example.co.uk/v1');
      await tester.tap(fields.at(1));
      await tester.pump();
      expect(
        tester.widget<TextField>(fields.at(2)).controller!.text,
        'Example Api',
      );
    },
  );

  testWidgets(
    'custom provider popup derives an editable alias and creates a new provider',
    (tester) async {
      final settings = InMemoryProviderSettingsStore();
      final credentials = InMemoryProviderCredentialStore();
      await pumpApp(
        tester,
        buildApp(
          catalogue: catalogueWithModels(),
          providerSettings: settings,
          providerCredentials: credentials,
        ),
      );
      await openSidebarEntry(tester, 'Providers');

      await tester.tap(
        find.byTooltip('Add a custom OpenAI-compatible provider'),
      );
      await tester.pumpAndSettle();

      expect(find.text('New custom provider'), findsOneWidget);
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));
      expect(
        tester.getTopLeft(find.text('API URL')).dy,
        lessThan(tester.getTopLeft(find.text('API key')).dy),
      );
      expect(
        tester.getTopLeft(find.text('API key')).dy,
        lessThan(tester.getTopLeft(find.text('API Alias')).dy),
      );

      await tester.enterText(fields.at(0), 'https://api.example.co.uk/v1');
      await tester.pump();
      expect(tester.widget<TextField>(fields.at(2)).controller!.text, isEmpty);

      await tester.tap(fields.at(1));
      await tester.pump();
      expect(
        tester.widget<TextField>(fields.at(2)).controller!.text,
        'Example Api',
      );

      await tester.enterText(fields.at(1), 'custom-secret');
      await tester.enterText(fields.at(2), 'My Work API');
      await tester.enterText(fields.at(0), 'https://example.com/v1');
      await tester.tap(fields.at(1));
      await tester.pump();
      expect(
        tester.widget<TextField>(fields.at(2)).controller!.text,
        'My Work API',
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Custom provider created'), findsOneWidget);
      final custom = settings.settings.entries.singleWhere(
        (entry) => entry.value.alias == 'My Work API',
      );
      expect(custom.key, startsWith('custom-'));
      expect(credentials.credentials[custom.key], 'custom-secret');
      expect(find.text('My Work API'), findsOneWidget);
    },
  );
}

class _ControlledProviderConnectionTester implements ProviderConnectionTester {
  final _modelRequests = <Completer<List<ProviderModelInfo>>>[];

  @override
  Future<ProviderConnectionResult> test(
    InferenceProviderDefinition definition, {
    required String baseUrl,
    String? credential,
  }) async {
    return const ProviderConnectionResult(ok: true, message: 'ok');
  }

  @override
  Future<List<ProviderModelInfo>> listModels(
    InferenceProviderDefinition definition, {
    required String baseUrl,
    String? credential,
  }) {
    final completer = Completer<List<ProviderModelInfo>>();
    _modelRequests.add(completer);
    return completer.future;
  }

  void completeModels(int index, List<ProviderModelInfo> models) {
    _modelRequests[index].complete(models);
  }

  void failModels(int index, Object error) {
    _modelRequests[index].completeError(error);
  }
}
