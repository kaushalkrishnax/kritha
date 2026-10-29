import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/intelligence/model_configuration.dart';
import 'package:kritha/features/intelligence/models/model_capabilities.dart';
import 'package:kritha/features/intelligence/models/model_descriptor.dart';
import 'package:kritha/features/models/active/active_models.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';
import 'package:kritha/features/providers/provider_connection_tester.dart';
import 'package:kritha/features/providers/provider_stores.dart';
import 'package:kritha/features/providers/providers_controller.dart';

import 'support/fake_inference.dart';
import 'support/fake_workspace.dart';

void main() {
  late Directory tempDir;
  late String modelPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kritha-active-models-');
    modelPath = '${tempDir.path}/tiny.litertlm';
    File(modelPath).writeAsBytesSync([1, 2, 3]);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  ProviderContainer buildContainer({
    required ActiveModelStore store,
    InMemoryRecentModelStore? recentStore,
    String? path,
  }) {
    return ProviderContainer(
      overrides: [
        activeModelStoreProvider.overrideWithValue(store),
        recentModelStoreProvider.overrideWithValue(
          recentStore ?? InMemoryRecentModelStore(),
        ),
        modelConfigStoreProvider.overrideWithValue(
          InMemoryModelConfigStore(path),
        ),
      ],
    );
  }

  test('only text generation has an execution path', () async {
    final container = buildContainer(
      store: InMemoryActiveModelStore(),
      path: modelPath,
    );
    addTearDown(container.dispose);

    final state = await container.read(activeModelsProvider.future);

    expect(state.statusFor(ModelCapability.text), ActiveAssignmentStatus.ready);
    expect(
      state.statusFor(ModelCapability.vision),
      ActiveAssignmentStatus.noModel,
    );
    expect(
      state.statusFor(ModelCapability.speechRecognition),
      ActiveAssignmentStatus.noModel,
    );
  });

  test('activates the validated local model and persists it', () async {
    final store = InMemoryActiveModelStore();
    final recentStore = InMemoryRecentModelStore();
    final container = buildContainer(
      store: store,
      recentStore: recentStore,
      path: modelPath,
    );
    addTearDown(container.dispose);
    await container.read(activeModelsProvider.future);

    await container
        .read(activeModelsProvider.notifier)
        .activate(ModelCapability.text);

    expect(store.assignments[ModelCapability.text]!.modelId, 'local:tiny');
    final state = container.read(activeModelsProvider).value!;
    expect(
      state.statusFor(ModelCapability.text),
      ActiveAssignmentStatus.active,
    );
    expect(state.assignments[ModelCapability.text]!.runtimeId, isNotEmpty);
    expect(recentStore.models.single.modelId, 'local:tiny');
    expect(state.recents.single.displayName, 'tiny');
  });

  test('rejects non-text capabilities', () async {
    final container = buildContainer(
      store: InMemoryActiveModelStore(),
      path: modelPath,
    );
    addTearDown(container.dispose);
    await container.read(activeModelsProvider.future);

    await expectLater(
      container
          .read(activeModelsProvider.notifier)
          .activate(ModelCapability.vision),
      throwsA(isA<ActiveModelException>()),
    );
  });

  test('rejects activation without a validated local model', () async {
    final container = buildContainer(store: InMemoryActiveModelStore());
    addTearDown(container.dispose);
    await container.read(activeModelsProvider.future);

    expect(
      container
          .read(activeModelsProvider)
          .value!
          .statusFor(ModelCapability.text),
      ActiveAssignmentStatus.noModel,
    );
    await expectLater(
      container
          .read(activeModelsProvider.notifier)
          .activate(ModelCapability.text),
      throwsA(isA<ActiveModelException>()),
    );
  });

  test('deactivation removes the persisted assignment', () async {
    final store = InMemoryActiveModelStore();
    final container = buildContainer(store: store, path: modelPath);
    addTearDown(container.dispose);
    await container.read(activeModelsProvider.future);
    await container
        .read(activeModelsProvider.notifier)
        .activate(ModelCapability.text);

    await container
        .read(activeModelsProvider.notifier)
        .deactivate(ModelCapability.text);

    expect(store.assignments, isEmpty);
    expect(
      container
          .read(activeModelsProvider)
          .value!
          .statusFor(ModelCapability.text),
      ActiveAssignmentStatus.ready,
    );
  });

  test('a new container reads the persisted assignment', () async {
    final store = InMemoryActiveModelStore();
    final first = buildContainer(store: store, path: modelPath);
    await first.read(activeModelsProvider.future);
    await first
        .read(activeModelsProvider.notifier)
        .activate(ModelCapability.text);
    first.dispose();

    final second = buildContainer(store: store, path: modelPath);
    addTearDown(second.dispose);
    final state = await second.read(activeModelsProvider.future);

    expect(state.assignments, contains(ModelCapability.text));
    expect(
      state.statusFor(ModelCapability.text),
      ActiveAssignmentStatus.active,
    );
  });

  test(
    'reports a stale assignment when the configured model changes',
    () async {
      final container = buildContainer(
        store: InMemoryActiveModelStore(),
        path: modelPath,
      );
      addTearDown(container.dispose);
      await container.read(activeModelsProvider.future);
      await container
          .read(activeModelsProvider.notifier)
          .activate(ModelCapability.text);

      final otherPath = '${tempDir.path}/other.litertlm';
      File(otherPath).writeAsBytesSync([4, 5, 6]);
      await container
          .read(modelConfigurationProvider.notifier)
          .setPath(otherPath);

      final state = await container.read(activeModelsProvider.future);
      expect(
        state.statusFor(ModelCapability.text),
        ActiveAssignmentStatus.stale,
      );
    },
  );

  test('state status is derived from the current descriptor', () {
    final assignment = ActiveModelAssignment(
      capability: ModelCapability.text,
      modelId: 'local:old',
      displayName: 'old',
      runtimeId: 'litertlm',
      activatedAt: DateTime(2026),
    );
    final state = ActiveModelsState(
      assignments: {ModelCapability.text: assignment},
      configuredModel: const ModelDescriptor(
        id: 'local:new',
        displayName: 'new',
        runtimeId: 'litertlm',
        capabilities: ModelCapabilities.textOnly,
      ),
    );

    expect(state.statusFor(ModelCapability.text), ActiveAssignmentStatus.stale);
    expect(
      state.statusFor(ModelCapability.audio),
      ActiveAssignmentStatus.noModel,
    );
  });

  test(
    'provider model assignment does not activate the local runtime',
    () async {
      final activeStore = InMemoryActiveModelStore();
      final recentStore = InMemoryRecentModelStore();
      final credentialStore = InMemoryProviderCredentialStore({
        'openai': 'key',
      });
      final modelTester = FakeProviderConnectionTester()
        ..models['openai'] = const [
          ProviderModelInfo(id: 'gpt-4o', name: 'GPT-4o'),
        ];
      final container = ProviderContainer(
        overrides: [
          activeModelStoreProvider.overrideWithValue(activeStore),
          recentModelStoreProvider.overrideWithValue(recentStore),
          modelConfigStoreProvider.overrideWithValue(
            InMemoryModelConfigStore(modelPath),
          ),
          providerSettingsStoreProvider.overrideWithValue(
            InMemoryProviderSettingsStore({
              'openai': const StoredProviderSettings(
                baseUrl: 'https://api.openai.com/v1',
                configured: true,
              ),
            }),
          ),
          providerCredentialStoreProvider.overrideWithValue(credentialStore),
          providerConnectionTesterProvider.overrideWithValue(modelTester),
        ],
      );
      addTearDown(container.dispose);
      await container.read(providersControllerProvider.future);
      await container.read(activeModelsProvider.future);

      await container
          .read(activeModelsProvider.notifier)
          .assignModel(
            capability: ModelCapability.text,
            sourceId: 'openai',
            modelId: 'gpt-4o',
            displayName: 'GPT-4o',
            runtimeId: 'openai',
          );

      final state = container.read(activeModelsProvider).value!;
      expect(activeStore.assignments[ModelCapability.text]!.sourceId, 'openai');
      expect(
        state.statusFor(ModelCapability.text),
        ActiveAssignmentStatus.assigned,
      );
      expect(state.recents.single.modelId, 'gpt-4o');
      expect(modelTester.testedProviderIds, isEmpty);
    },
  );
}
