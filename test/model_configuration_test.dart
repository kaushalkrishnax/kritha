import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kritha/features/intelligence/model_configuration.dart';
import 'package:kritha/features/intelligence/model_lifecycle.dart';
import 'package:kritha/features/intelligence/models/model_capabilities.dart';
import 'package:kritha/features/intelligence/providers.dart';
import 'package:kritha/features/intelligence/runtimes/litertlm_provider.dart';

import 'support/fake_inference.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('kritha-model-');
  });

  tearDown(() {
    directory.deleteSync(recursive: true);
  });

  File writeModel(String name, {int bytes = 8}) {
    final file = File('${directory.path}/$name');
    file.writeAsBytesSync(List<int>.filled(bytes, 1));
    return file;
  }

  test('an absent selection is not configured', () {
    expect(
      ModelConfiguration.validate(null).status,
      ModelConfigurationStatus.notConfigured,
    );
    expect(
      ModelConfiguration.validate('   ').status,
      ModelConfigurationStatus.notConfigured,
    );
  });

  test('missing and invalid files are reported separately', () {
    final missing = ModelConfiguration.validate(
      '${directory.path}/gone.litertlm',
    );
    expect(missing.status, ModelConfigurationStatus.missingFile);
    expect(missing.descriptor, isNull);

    final notAFile = ModelConfiguration.validate(directory.path);
    expect(notAFile.status, ModelConfigurationStatus.invalidFile);

    final wrongExtension = ModelConfiguration.validate(
      writeModel('model.bin').path,
    );
    expect(wrongExtension.status, ModelConfigurationStatus.invalidFile);
    expect(wrongExtension.message, contains(ModelConfiguration.modelExtension));

    final empty = ModelConfiguration.validate(
      writeModel('empty.litertlm', bytes: 0).path,
    );
    expect(empty.status, ModelConfigurationStatus.invalidFile);
    expect(empty.message, contains('empty'));
  });

  test('a present model file produces a descriptor', () {
    final file = writeModel('gemma-3-1b.litertlm');

    final configuration = ModelConfiguration.validate(file.path);

    expect(configuration.status, ModelConfigurationStatus.ready);
    expect(configuration.isReady, isTrue);
    expect(configuration.fileName, 'gemma-3-1b.litertlm');
    expect(configuration.descriptor!.id, 'local:gemma-3-1b');
    expect(configuration.descriptor!.displayName, 'gemma-3-1b');
    expect(configuration.descriptor!.modelPath, file.path);
    expect(configuration.descriptor!.runtimeId, LiteRtLmProvider.providerId);
    expect(
      configuration.descriptor!.capabilities.supports(
        InferenceCapability.textGeneration,
      ),
      isTrue,
    );
    expect(
      configuration.descriptor!.capabilities.supports(
        InferenceCapability.imageInput,
      ),
      isFalse,
    );
    expect(
      configuration.descriptor!.capabilities.supports(
        InferenceCapability.audioInput,
      ),
      isFalse,
    );
    expect(
      configuration.descriptor!.capabilities.supports(
        InferenceCapability.structuredOutput,
      ),
      isFalse,
    );
  });

  test('the extension check is case-insensitive', () {
    final file = writeModel('MODEL.LITERTLM');

    expect(ModelConfiguration.validate(file.path).isReady, isTrue);
  });

  test('selection persists and feeds the configured model provider', () async {
    final file = writeModel('picked.litertlm');
    final store = InMemoryModelConfigStore();
    final container = ProviderContainer(
      overrides: [modelConfigStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    final initial = await container.read(modelConfigurationProvider.future);
    expect(initial.status, ModelConfigurationStatus.notConfigured);
    expect(container.read(configuredModelProvider), isNull);

    await container
        .read(modelConfigurationProvider.notifier)
        .setPath(file.path);

    expect(store.path, file.path);
    expect(container.read(modelConfigurationProvider).value!.isReady, isTrue);
    expect(container.read(configuredModelProvider)?.modelPath, file.path);

    await container.read(modelConfigurationProvider.notifier).clear();

    expect(store.path, isNull);
    expect(container.read(configuredModelProvider), isNull);
  });

  test('revalidation reports a file removed after selection', () async {
    final file = writeModel('removed.litertlm');
    final store = InMemoryModelConfigStore(file.path);
    final container = ProviderContainer(
      overrides: [modelConfigStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    final initial = await container.read(modelConfigurationProvider.future);
    expect(initial.isReady, isTrue);

    file.deleteSync();
    await container.read(modelConfigurationProvider.notifier).revalidate();

    final next = container.read(modelConfigurationProvider).value!;
    expect(next.status, ModelConfigurationStatus.missingFile);
    expect(container.read(configuredModelProvider), isNull);
  });

  test('a startup read cannot overwrite a newer selection', () async {
    final store = _DelayedModelConfigStore(null);
    store.readGate = Completer<String?>();
    final container = ProviderContainer(
      overrides: [modelConfigStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    final startup = container.read(modelConfigurationProvider.future);
    await pumpEventQueue();
    final file = writeModel('selected.litertlm');
    await container
        .read(modelConfigurationProvider.notifier)
        .setPath(file.path);
    store.readGate!.complete(null);

    final configuration = await startup;
    expect(configuration.isReady, isTrue);
    expect(container.read(modelConfigurationProvider).value!.isReady, isTrue);
    expect(container.read(configuredModelProvider), isNotNull);
  });

  test('a slow revalidation cannot resurrect a cleared selection', () async {
    final file = writeModel('slow.litertlm');
    final store = _DelayedModelConfigStore(file.path);
    final container = ProviderContainer(
      overrides: [modelConfigStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    final initial = await container.read(modelConfigurationProvider.future);
    expect(initial.isReady, isTrue);

    store.readGate = Completer<String?>();
    final revalidate = container
        .read(modelConfigurationProvider.notifier)
        .revalidate();
    await pumpEventQueue();
    await container.read(modelConfigurationProvider.notifier).clear();
    expect(container.read(configuredModelProvider), isNull);

    store.readGate!.complete(file.path);
    await revalidate;

    expect(
      container.read(modelConfigurationProvider).value!.status,
      ModelConfigurationStatus.notConfigured,
    );
    expect(container.read(configuredModelProvider), isNull);
  });

  test('a slow revalidation cannot overwrite a newer selection', () async {
    final oldFile = writeModel('old.litertlm');
    final newFile = writeModel('new.litertlm');
    final store = _DelayedModelConfigStore(oldFile.path);
    final container = ProviderContainer(
      overrides: [modelConfigStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await container.read(modelConfigurationProvider.future);
    store.readGate = Completer<String?>();
    final revalidate = container
        .read(modelConfigurationProvider.notifier)
        .revalidate();
    await pumpEventQueue();

    await container
        .read(modelConfigurationProvider.notifier)
        .setPath(newFile.path);
    store.readGate!.complete(oldFile.path);
    await revalidate;

    expect(
      container.read(modelConfigurationProvider).value!.path,
      newFile.path,
    );
    expect(container.read(configuredModelProvider)?.modelPath, newFile.path);
  });

  test('two selections are written in call order', () async {
    final first = writeModel('first.litertlm');
    final second = writeModel('second.litertlm');
    final store = _DelayedModelConfigStore(null);
    final container = ProviderContainer(
      overrides: [modelConfigStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await container.read(modelConfigurationProvider.future);

    store.writeGate = Completer<void>();
    final firstWrite = container
        .read(modelConfigurationProvider.notifier)
        .setPath(first.path);
    final secondWrite = container
        .read(modelConfigurationProvider.notifier)
        .setPath(second.path);

    store.writeGate!.complete();
    await Future.wait([firstWrite, secondWrite]);

    expect(store.path, second.path);
    expect(container.read(modelConfigurationProvider).value!.path, second.path);
  });

  test(
    'a failed selection during startup cannot restore old readiness',
    () async {
      final oldFile = writeModel('old.litertlm');
      final newFile = writeModel('new.litertlm');
      final store = _DelayedModelConfigStore(oldFile.path);
      store.readGate = Completer<String?>();
      final container = ProviderContainer(
        overrides: [modelConfigStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      final startup = container.read(modelConfigurationProvider.future);
      await pumpEventQueue();
      store.failWrites = true;
      await expectLater(
        container
            .read(modelConfigurationProvider.notifier)
            .setPath(newFile.path),
        throwsA(isA<StateError>()),
      );

      store.readGate!.complete(oldFile.path);
      await expectLater(startup, throwsA(isA<StateError>()));
      expect(container.read(modelConfigurationProvider).hasError, isTrue);
      expect(container.read(configuredModelProvider), isNull);
    },
  );

  test('a persistence failure invalidates readiness', () async {
    final file = writeModel('ready.litertlm');
    final store = _DelayedModelConfigStore(file.path);
    final container = ProviderContainer(
      overrides: [modelConfigStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await container.read(modelConfigurationProvider.future);
    expect(container.read(configuredModelProvider), isNotNull);

    store.failWrites = true;
    await expectLater(
      container
          .read(modelConfigurationProvider.notifier)
          .setPath('${directory.path}/next.litertlm'),
      throwsA(isA<StateError>()),
    );

    expect(container.read(modelConfigurationProvider).hasError, isTrue);
    expect(container.read(configuredModelProvider), isNull);
    expect(
      container.read(modelLifecycleProvider).stage,
      ModelLifecycleStage.configurationUnavailable,
    );
  });

  test('a selection survives a fresh controller instance', () async {
    final file = writeModel('persisted.litertlm');
    final store = InMemoryModelConfigStore();
    final first = ProviderContainer(
      overrides: [modelConfigStoreProvider.overrideWithValue(store)],
    );
    addTearDown(first.dispose);
    await first.read(modelConfigurationProvider.future);
    await first.read(modelConfigurationProvider.notifier).setPath(file.path);
    first.dispose();

    final second = ProviderContainer(
      overrides: [modelConfigStoreProvider.overrideWithValue(store)],
    );
    addTearDown(second.dispose);
    final restored = await second.read(modelConfigurationProvider.future);

    expect(restored.isReady, isTrue);
    expect(restored.path, file.path);
  });

  test('the SharedPreferences store removes missing and blank paths', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesModelConfigStore();

    expect(await store.readPath(), isNull);

    await store.writePath('  /models/model.litertlm  ');
    expect(await store.readPath(), '/models/model.litertlm');

    await store.writePath(null);
    expect(await store.readPath(), isNull);

    await store.writePath('   ');
    expect(await store.readPath(), isNull);
  });
}

class _DelayedModelConfigStore implements ModelConfigStore {
  _DelayedModelConfigStore(this.path);

  String? path;
  Completer<String?>? readGate;
  Completer<void>? writeGate;
  bool failWrites = false;

  @override
  Future<String?> readPath() async {
    final gate = readGate;
    if (gate != null) return gate.future;
    return path;
  }

  @override
  Future<void> writePath(String? path) async {
    final gate = writeGate;
    if (gate != null) {
      writeGate = null;
      await gate.future;
    }
    if (failWrites) throw StateError('write failed');
    this.path = path?.trim();
  }
}
