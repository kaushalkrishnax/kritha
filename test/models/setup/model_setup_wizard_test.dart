import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/core/providers.dart';
import 'package:kritha/core/theme.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';
import 'package:kritha/features/models/setup/configured_model_store.dart';
import 'package:kritha/features/models/setup/model_artifact_storage.dart';
import 'package:kritha/features/models/setup/model_setup_assessment.dart';
import 'package:kritha/features/models/setup/model_setup_wizard.dart';
import 'package:kritha/models/model_configuration_record.dart';
import 'package:kritha/services/runtime_probe.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kritha-wizard-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  const details = ModelDetails(
    model: CatalogueModel(
      id: 'acme/litert',
      pipelineTag: 'text-generation',
      tags: ['litertlm'],
    ),
    files: [
      ModelFile(path: 'model.litertlm', sizeBytes: 2048),
      ModelFile(path: 'config.json', sizeBytes: 128),
    ],
    config: {
      'architectures': ['LlamaForCausalLM'],
    },
  );

  RuntimeStatus runtime({bool liteRtLmReady = true}) => RuntimeStatus(
    liteRtLmReady: liteRtLmReady,
    sherpaVersion: '',
    onnxRuntimeVersion: '',
    sqliteVersion: '3.51.0',
    secureStorageReady: true,
    preferencesReady: true,
    microphone: 'granted',
    recorderReady: true,
    audioPlayerReady: true,
    dioBaseUrl: '',
    documentsPath: tempDir.path,
  );

  Widget buildWizard(
    Future<RuntimeStatus> runtimeFuture, {
    ConfiguredModelStore? store,
    String? configurationId,
    ModelArtifactDownloader? downloader,
    double width = 320,
    double height = 680,
  }) {
    return ProviderScope(
      overrides: [
        runtimeStatusProvider.overrideWith((ref) => runtimeFuture),
        if (store != null)
          configuredModelStoreProvider.overrideWithValue(store),
        if (downloader != null)
          modelArtifactDownloaderProvider.overrideWithValue(downloader),
      ],
      child: MaterialApp(
        theme: buildKrithaTheme(),
        home: Scaffold(
          backgroundColor: KrithaColors.bgBase,
          body: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: ModelSetupWizard(
                details: details,
                configurationId: configurationId,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('pre-checks show every stage and unlock Next on success', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final completer = Completer<RuntimeStatus>();
    await tester.pumpWidget(buildWizard(completer.future));
    await tester.pump();

    expect(find.text('Model Setup Wizard'), findsOneWidget);
    for (final stage in ModelSetupStage.values) {
      expect(find.text(stage.label), findsOneWidget);
    }
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator).first,
          )
          .color,
      KrithaColors.warning,
    );
    expect(
      find.text('Verifying the installed runtime and application storage.'),
      findsOneWidget,
    );
    expect(
      find.text('All checks complete. You can proceed now.'),
      findsNothing,
    );
    final nextDuringAssessment = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(nextDuringAssessment.onPressed, isNull);
    expect(find.text('Cancel'), findsOneWidget);

    completer.complete(runtime());
    await tester.pumpAndSettle();

    expect(
      find.text('All checks complete. You can proceed now.'),
      findsOneWidget,
    );
    final next = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(next.onPressed, isNotNull);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Manage Artifacts'), findsOneWidget);
    expect(
      find.text(
        'Review, select and download the files required for this model.',
      ),
      findsOneWidget,
    );
    for (final title in ['Config Files', 'Helper Files', 'Model Weights']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('File name'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsNothing,
    );
    expect(
      find.text('No rows added yet. Add a row to get started.'),
      findsOneWidget,
    );
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Test'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('wide layout renders rows without horizontal scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildWizard(Future.value(runtime()), width: 900, height: 760),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('File name'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsNothing,
    );
  });

  testWidgets('failed stage shows the actual reason and keeps Next disabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildWizard(Future.value(runtime(liteRtLmReady: false))),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The LiteRT-LM native runtime is not available on this device.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'))
          .onPressed,
      isNull,
    );
    expect(
      find.text('All checks complete. You can proceed now.'),
      findsNothing,
    );
  });

  testWidgets('selected artifacts gate Test while Save stays available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _FakeStore();
    await tester.pumpWidget(
      buildWizard(
        Future.value(runtime()),
        store: store,
        configurationId: 'wizard-incomplete',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Manage Artifacts'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Test'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Download All'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('section checkboxes stay reactive with row selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildWizard(
        Future.value(runtime()),
        store: _FakeStore(),
        configurationId: 'wizard-sections',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    Checkbox checkboxFor(String key) {
      return tester.widget<Checkbox>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Checkbox),
        ),
      );
    }

    const sectionKey = 'artifact-section-check-configuration';
    const rowKey = 'artifact-check-artifact-1';
    expect(checkboxFor(sectionKey).value, isTrue);
    expect(checkboxFor(rowKey).value, isTrue);

    await tester.tap(find.byKey(const ValueKey(rowKey)));
    await tester.pumpAndSettle();
    expect(checkboxFor(rowKey).value, isFalse);
    expect(checkboxFor(sectionKey).value, isFalse);
    final rowFinder = find.byKey(const ValueKey('artifact-row-artifact-1'));
    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: rowFinder,
              matching: find.widgetWithText(TextButton, 'Download'),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('artifact-target-artifact-1')),
          )
          .enabled,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey(sectionKey)));
    await tester.pumpAndSettle();
    expect(checkboxFor(rowKey).value, isTrue);
    expect(checkboxFor(sectionKey).value, isTrue);
    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: rowFinder,
              matching: find.widgetWithText(TextButton, 'Download'),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('download progress can be paused and resumed', (tester) async {
    tester.view.physicalSize = const Size(320, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final downloader = _HeldDownloader();
    await tester.pumpWidget(
      buildWizard(Future.value(runtime()), downloader: downloader),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('artifact-row-artifact-1'));
    await tester.tap(
      find.descendant(
        of: row,
        matching: find.widgetWithText(TextButton, 'Download'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('50 B of 100 B'), findsOneWidget);
    await tester.pump(KrithaMotion.fast);
    final workingBar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(workingBar.value, 0.5);
    expect(
      (workingBar.valueColor as AlwaysStoppedAnimation<Color>).value,
      KrithaColors.success,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.widgetWithText(TextButton, 'Pause'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: row,
        matching: find.widgetWithText(TextButton, 'Pause'),
      ),
    );
    await tester.pumpAndSettle();
    final pausedBar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(
      (pausedBar.valueColor as AlwaysStoppedAnimation<Color>).value,
      KrithaColors.warning,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.widgetWithText(TextButton, 'Resume'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: row,
        matching: find.widgetWithText(TextButton, 'Resume'),
      ),
    );
    await tester.pump();
    await tester.pump(KrithaMotion.fast);

    final resumedBar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(resumedBar.value, 0.5);
    expect(
      (resumedBar.valueColor as AlwaysStoppedAnimation<Color>).value,
      KrithaColors.success,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.widgetWithText(TextButton, 'Pause'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('downloaded artifacts unlock Test and save before testing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _FakeStore();
    const configurationId = 'wizard-ready';
    final root = FileModelArtifactStorage.rootFor(
      documentsPath: tempDir.path,
      repositoryId: details.model.id,
      configurationId: configurationId,
    );
    for (final name in ['config.json', 'model.litertlm']) {
      File('$root/$name')
        ..createSync(recursive: true)
        ..writeAsStringSync('downloaded');
    }

    await tester.pumpWidget(
      buildWizard(
        Future.value(runtime()),
        store: store,
        configurationId: configurationId,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Manage Artifacts'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Download All'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Test'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Test'));
    await tester.pumpAndSettle();
    expect(
      find.text('Model testing is not available in this phase.'),
      findsOneWidget,
    );
    expect(find.text('Test'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Back'), findsOneWidget);

    expect(store.saved, hasLength(1));
    final record = store.saved.single;
    expect(record.id, configurationId);
    expect(record.repositoryId, 'acme/litert');
    expect(record.artifacts, hasLength(2));
    expect(record.artifacts.every((artifact) => artifact.downloaded), isTrue);
  });
}

class _FakeStore implements ConfiguredModelStore {
  final List<ConfiguredModel> saved = [];

  @override
  Future<void> save(ConfiguredModel model) async {
    saved.removeWhere((item) => item.id == model.id);
    saved.add(model);
  }

  @override
  Future<List<ConfiguredModel>> all() async => List.unmodifiable(saved);

  @override
  Future<ConfiguredModel?> find(String id) async {
    for (final model in saved) {
      if (model.id == id) return model;
    }
    return null;
  }

  @override
  Future<void> delete(String id) async {
    saved.removeWhere((model) => model.id == id);
  }
}

class _HeldDownloader implements ModelArtifactDownloader {
  final List<_HeldDownload> downloads = [];

  @override
  ModelArtifactDownload start({
    required String repositoryId,
    required String revision,
    required String path,
    required String destinationPath,
    required void Function(int received, int total) onProgress,
  }) {
    final download = _HeldDownload(
      path: path,
      destinationPath: destinationPath,
      onProgress: onProgress,
    );
    downloads.add(download);
    return download;
  }
}

class _HeldDownload implements ModelArtifactDownload {
  _HeldDownload({
    required this.path,
    required this.destinationPath,
    required this.onProgress,
  }) {
    _done = _run();
  }

  final String path;
  final String destinationPath;
  final void Function(int received, int total) onProgress;

  late final Future<void> _done;
  final Completer<void> _gate = Completer();
  bool _paused = false;

  @override
  Future<void> get done => _done;

  @override
  bool get isPaused => _paused;

  @override
  void pause() => _paused = true;

  @override
  void resume() => _paused = false;

  Future<void> _run() async {
    onProgress(0, 100);
    onProgress(50, 100);
    await _gate.future;
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsString('downloaded:$path');
    onProgress(100, 100);
  }
}
