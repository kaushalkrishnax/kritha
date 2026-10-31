import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';
import 'package:kritha/features/models/catalogue/hugging_face_hub_client.dart';
import 'package:kritha/features/models/setup/configured_model_store.dart';
import 'package:kritha/features/models/setup/model_artifact.dart';
import 'package:kritha/features/models/setup/model_artifact_storage.dart';
import 'package:kritha/features/models/setup/model_setup_assessment.dart';
import 'package:kritha/features/models/setup/model_setup_assessor.dart';
import 'package:kritha/features/models/setup/model_setup_controller.dart';
import 'package:kritha/models/model_configuration_record.dart';
import 'package:kritha/services/runtime_probe.dart';

void main() {
  late Directory tempDir;
  late RuntimeStatus runtime;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kritha-artifacts-');
    runtime = RuntimeStatus(
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
      documentsPath: tempDir.path,
    );
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
      ModelFile(path: 'tokenizer.model', sizeBytes: 512),
    ],
    config: {
      'architectures': ['LlamaForCausalLM'],
    },
  );

  Future<ModelSetupWizardController> readyController({
    ModelArtifactDownloader? downloader,
    String? configurationId,
    ConfiguredModelStore? store,
    ModelDetails? source,
  }) async {
    final controller = ModelSetupWizardController(
      details: source ?? details,
      assessor: ModelSetupAssessor(runtimeStatus: Future.value(runtime)),
      downloader: downloader,
      store: store,
      configurationId: configurationId,
    );
    addTearDown(controller.dispose);
    await controller.runAssessment();
    controller.nextStep();
    return controller;
  }

  test('builds selected rows for every section and stays incomplete', () async {
    final controller = await readyController();

    expect(controller.stepIndex, 1);
    expect(controller.artifacts, hasLength(3));
    expect(
      controller
          .artifactsFor(ModelArtifactKind.configuration)
          .single
          .targetPath,
      'config.json',
    );
    expect(
      controller.artifactsFor(ModelArtifactKind.helper).single.targetPath,
      'tokenizer.model',
    );
    expect(
      controller.artifactsFor(ModelArtifactKind.weights).single.targetPath,
      'model.litertlm',
    );
    expect(controller.artifacts.every((row) => row.selected), isTrue);
    expect(controller.artifacts.every((row) => row.isReady), isFalse);
    expect(controller.artifactsComplete, isFalse);
    expect(controller.canContinue, isFalse);
  });

  test('pausing keeps the row until the same transfer resumes', () async {
    final downloader = _FakeDownloader(hold: true);
    final controller = await readyController(downloader: downloader);
    final row = controller.artifactsFor(ModelArtifactKind.configuration).single;

    final future = controller.downloadArtifact(row.id);
    await downloader.started;
    await downloader.downloads.single.halfway;

    ModelArtifactRow current() =>
        controller.artifacts.singleWhere((item) => item.id == row.id);

    expect(current().isWorking, isTrue);
    expect(current().receivedBytes, 50);
    expect(current().sizeBytes, 100);
    expect(current().progress, 0.5);

    controller.pauseArtifactDownload(row.id);
    expect(current().isPaused, isTrue);
    expect(current().progress, 0.5);

    controller.resumeArtifactDownload(row.id);
    expect(current().isWorking, isTrue);

    downloader.downloads.single.release();
    await future;

    expect(current().isReady, isTrue);
    expect(current().progress, 1.0);
    expect(
      File(current().localPath!).readAsStringSync(),
      'downloaded:${row.repositoryFile!.path}',
    );
  });

  test('a paused transfer resumes from the bytes already on disk', () async {
    final payload = Uint8List.fromList(
      List<int>.generate(400, (index) => index % 256),
    );
    final adapter = _RangeAdapter(payload);
    final dio = Dio(BaseOptions(baseUrl: HuggingFaceHubClient.baseUrl))
      ..httpClientAdapter = adapter;
    final downloader = HubArtifactDownloader(
      HuggingFaceHubClient(dio, () async => null),
    );
    final destination = '${tempDir.path}/resumed.bin';
    final progress = <String>[];
    var paused = false;
    late ModelArtifactDownload download;

    download = downloader.start(
      repositoryId: 'acme/litert',
      revision: 'main',
      path: 'model.litertlm',
      destinationPath: destination,
      onProgress: (received, total) {
        progress.add('$received/$total');
        if (!paused && received >= 100) {
          paused = true;
          download.pause();
        }
      },
    );

    final done = download.done;
    for (var attempt = 0; attempt < 200 && !download.isPaused; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(download.isPaused, isTrue);

    download.resume();
    await done;

    expect(File(destination).readAsBytesSync(), payload);
    expect(adapter.ranges, contains('bytes=100-'));
    expect(progress, contains('400/400'));
  });

  test(
    'download all writes each selected file into the configuration root',
    () async {
      final downloader = _FakeDownloader();
      final controller = await readyController(downloader: downloader);

      await controller.downloadAllArtifacts();

      expect(downloader.requests.toSet(), {
        'config.json',
        'tokenizer.model',
        'model.litertlm',
      });
      expect(controller.artifactsComplete, isTrue);
      expect(controller.canContinue, isTrue);
      expect(controller.hasDownloadableSelection, isFalse);
      for (final row in controller.artifacts) {
        expect(row.isReady, isTrue);
        expect(row.localPath, startsWith(controller.artifactRootPath));
        expect(File(row.localPath!).existsSync(), isTrue);
      }

      final config = controller
          .artifactsFor(ModelArtifactKind.configuration)
          .single;
      await controller.deleteArtifactCopy(config.id);
      expect(File(config.localPath!).existsSync(), isFalse);
      expect(controller.artifactsComplete, isFalse);
      expect(controller.canContinue, isFalse);
    },
  );

  test('download all skips unselected, device and unassigned rows', () async {
    final downloader = _FakeDownloader();
    final controller = await readyController(downloader: downloader);

    final config = controller
        .artifactsFor(ModelArtifactKind.configuration)
        .single;
    controller.toggleArtifactSelected(config.id);

    final deviceSource = File('${tempDir.path}/device-helper.bin');
    await deviceSource.writeAsString('device');
    final added = controller.addArtifactRow(ModelArtifactKind.helper)!;
    await controller.assignDeviceArtifact(added.id, deviceSource.path);
    expect(downloader.requests, isEmpty);

    await controller.downloadAllArtifacts();

    expect(downloader.requests, isNot(contains('config.json')));
    expect(downloader.requests, contains('model.litertlm'));
    expect(downloader.requests, contains('tokenizer.model'));
  });

  test(
    'device files are copied into the configuration and removed again',
    () async {
      final controller = await readyController();
      final source = File('${tempDir.path}/external-tokenizer.model');
      await source.writeAsString('device bytes');
      final row = controller.addArtifactRow(ModelArtifactKind.helper)!;

      await controller.assignDeviceArtifact(row.id, source.path);

      final device = controller.artifacts.firstWhere(
        (item) => item.id == row.id,
      );
      expect(device.sourceType, ModelArtifactSourceType.device);
      expect(device.isReady, isTrue);
      expect(device.targetPath, 'external-tokenizer.model');
      expect(device.localPath, startsWith(controller.artifactRootPath));
      expect(File(device.localPath!).readAsStringSync(), 'device bytes');
      expect(source.existsSync(), isTrue);

      await controller.removeArtifactRow(row.id);
      expect(File(device.localPath!).existsSync(), isFalse);
      expect(source.existsSync(), isTrue);
    },
  );

  test(
    'replacing a source deletes the old copy but keeps an edited target',
    () async {
      final downloader = _FakeDownloader();
      final controller = await readyController(downloader: downloader);
      final config = controller
          .artifactsFor(ModelArtifactKind.configuration)
          .single;
      await controller.downloadArtifact(config.id);
      final firstPath = controller.artifacts
          .firstWhere((row) => row.id == config.id)
          .localPath!;

      await controller.updateArtifactTarget(config.id, 'nested/config.json');
      final moved = controller.artifacts.firstWhere(
        (row) => row.id == config.id,
      );
      expect(moved.localPath, isNot(firstPath));
      expect(File(firstPath).existsSync(), isFalse);
      expect(File(moved.localPath!).existsSync(), isTrue);

      const replacement = ModelFile(path: 'other-config.json', sizeBytes: 64);
      await controller.assignRepositoryArtifact(config.id, replacement);
      final replaced = controller.artifacts.firstWhere(
        (row) => row.id == config.id,
      );
      expect(File(moved.localPath!).existsSync(), isFalse);
      expect(replaced.targetPath, 'nested/config.json');
      expect(replaced.repositoryFile?.path, 'other-config.json');
      expect(replaced.isReady, isFalse);
    },
  );

  test('section expansion is retained on the shared controller', () async {
    final controller = await readyController();

    expect(controller.isSectionExpanded(ModelArtifactKind.weights), isTrue);
    controller.toggleSection(ModelArtifactKind.weights);
    expect(controller.isSectionExpanded(ModelArtifactKind.weights), isFalse);
    controller.toggleSection(ModelArtifactKind.weights);
    expect(controller.isSectionExpanded(ModelArtifactKind.weights), isTrue);
  });

  test(
    'section selection reflects row changes and toggles every row',
    () async {
      final controller = await readyController();
      final config = controller
          .artifactsFor(ModelArtifactKind.configuration)
          .single;

      expect(
        controller.sectionSelection(ModelArtifactKind.configuration),
        ModelArtifactSectionSelection.all,
      );

      controller.toggleArtifactSelected(config.id);
      expect(
        controller.sectionSelection(ModelArtifactKind.configuration),
        ModelArtifactSectionSelection.none,
      );

      controller.toggleSectionSelection(ModelArtifactKind.configuration);
      expect(
        controller.sectionSelection(ModelArtifactKind.configuration),
        ModelArtifactSectionSelection.all,
      );
      expect(
        controller
            .artifactsFor(ModelArtifactKind.configuration)
            .single
            .selected,
        isTrue,
      );

      controller.toggleSectionSelection(ModelArtifactKind.configuration);
      expect(
        controller.sectionSelection(ModelArtifactKind.configuration),
        ModelArtifactSectionSelection.none,
      );

      final added = controller.addArtifactRow(ModelArtifactKind.helper)!;
      expect(added.selected, isTrue);
      expect(
        controller.sectionSelection(ModelArtifactKind.helper),
        ModelArtifactSectionSelection.all,
      );

      controller.toggleArtifactSelected(added.id);
      expect(
        controller.sectionSelection(ModelArtifactKind.helper),
        ModelArtifactSectionSelection.partial,
      );

      await controller.removeArtifactRow(added.id);
      expect(
        controller.sectionSelection(ModelArtifactKind.helper),
        ModelArtifactSectionSelection.all,
      );
    },
  );

  test(
    'weight selection prefers fp4 and never selects every variant',
    () async {
      final controller = await readyController(
        source: const ModelDetails(
          model: CatalogueModel(
            id: 'acme/gemma',
            pipelineTag: 'text-generation',
            tags: ['litertlm'],
          ),
          files: [
            ModelFile(path: 'gemma-fp8.litertlm', sizeBytes: 500),
            ModelFile(path: 'gemma-fp4.litertlm', sizeBytes: 900),
            ModelFile(path: 'gemma-q8.litertlm', sizeBytes: 100),
          ],
        ),
      );

      final weights = controller.artifactsFor(ModelArtifactKind.weights);
      expect(weights, hasLength(3));
      expect(weights.where((row) => row.selected), hasLength(1));
      expect(
        weights.singleWhere((row) => row.selected).repositoryFile?.path,
        'gemma-fp4.litertlm',
      );
    },
  );

  test('weight selection falls back to the smallest sized variant', () async {
    final controller = await readyController(
      source: const ModelDetails(
        model: CatalogueModel(
          id: 'acme/gemma',
          pipelineTag: 'text-generation',
          tags: ['litertlm'],
        ),
        files: [
          ModelFile(path: 'gemma-large.litertlm', sizeBytes: 900),
          ModelFile(path: 'gemma-small.litertlm', sizeBytes: 100),
          ModelFile(path: 'gemma-medium.litertlm', sizeBytes: 500),
        ],
      ),
    );

    final selected = controller
        .artifactsFor(ModelArtifactKind.weights)
        .where((row) => row.selected);
    expect(selected, hasLength(1));
    expect(selected.single.repositoryFile?.path, 'gemma-small.litertlm');
  });

  test('leaves weights unselected when no variant can be identified', () async {
    final controller = await readyController(
      source: const ModelDetails(
        model: CatalogueModel(
          id: 'acme/gemma',
          pipelineTag: 'text-generation',
          tags: ['litertlm'],
        ),
        files: [
          ModelFile(path: 'gemma-a.litertlm'),
          ModelFile(path: 'gemma-b.litertlm'),
        ],
      ),
    );

    final weights = controller.artifactsFor(ModelArtifactKind.weights);
    expect(weights.every((row) => !row.selected), isTrue);
    expect(controller.needsWeightSuggestion, isTrue);
    expect(controller.artifactsComplete, isFalse);
  });

  test('each configuration owns a separate artifact root', () async {
    final downloader = _FakeDownloader();
    final first = await readyController(
      downloader: downloader,
      configurationId: 'configuration-a',
    );
    final second = await readyController(
      downloader: downloader,
      configurationId: 'configuration-b',
    );

    expect(first.artifactRootPath, isNot(second.artifactRootPath));
    expect(first.artifactRootPath, startsWith(tempDir.path));
    expect(second.artifactRootPath, startsWith(tempDir.path));

    final firstWeight = first.artifactsFor(ModelArtifactKind.weights).single;
    final secondWeight = second.artifactsFor(ModelArtifactKind.weights).single;
    await first.downloadArtifact(firstWeight.id);
    await second.downloadArtifact(secondWeight.id);
    final firstPath = first.artifacts
        .firstWhere((row) => row.id == firstWeight.id)
        .localPath!;
    final secondPath = second.artifacts
        .firstWhere((row) => row.id == secondWeight.id)
        .localPath!;
    expect(firstPath, isNot(secondPath));

    File(firstPath).writeAsStringSync('first configuration');
    expect(File(secondPath).readAsStringSync(), isNot('first configuration'));
  });

  test('artifact target paths cannot escape the configuration root', () {
    expect(normalizeArtifactTarget('../config.json'), isNull);
    expect(normalizeArtifactTarget('nested/../../config.json'), isNull);
    expect(normalizeArtifactTarget('nested/config.json'), isNotNull);
    final storage = FileModelArtifactStorage(tempDir.path);
    expect(storage.resolve('../config.json'), isEmpty);
  });

  test(
    'saving persists configuration metadata and artifact rows only',
    () async {
      final store = _FakeStore();
      final downloader = _FakeDownloader();
      final controller = await readyController(
        downloader: downloader,
        store: store,
        configurationId: 'configuration-save',
      );
      await controller.downloadAllArtifacts();

      expect(controller.canSaveConfiguration, isTrue);
      expect(await controller.saveConfiguration(), isTrue);

      final saved = store.saved.single;
      expect(saved.id, 'configuration-save');
      expect(saved.repositoryId, 'acme/litert');
      expect(saved.displayName, details.model.name);
      expect(saved.runtimeId, isNotEmpty);
      expect(saved.rootPath, controller.artifactRootPath);
      expect(saved.artifacts, hasLength(3));
      expect(saved.artifacts.every((artifact) => artifact.downloaded), isTrue);
      expect(saved.artifacts.every((artifact) => artifact.selected), isTrue);
      expect(
        saved.artifacts.map((artifact) => artifact.targetPath),
        containsAll(['config.json', 'tokenizer.model', 'model.litertlm']),
      );
      expect(controller.savedConfigurationId, 'configuration-save');
      expect(controller.saveError, isNull);
    },
  );

  test('saving is blocked by a selected row without a source', () async {
    final store = _FakeStore();
    final controller = await readyController(store: store);

    final row = controller.addArtifactRow(ModelArtifactKind.helper)!;
    expect(controller.saveIssue, isNotNull);
    expect(controller.canSaveConfiguration, isFalse);
    expect(await controller.saveConfiguration(), isFalse);
    expect(store.saved, isEmpty);

    controller.toggleArtifactSelected(row.id);
    expect(controller.saveIssue, isNull);
    expect(controller.canSaveConfiguration, isTrue);
  });

  test('saving is blocked when a selected target path is invalid', () async {
    final controller = await readyController(store: _FakeStore());
    final config = controller
        .artifactsFor(ModelArtifactKind.configuration)
        .single;

    await controller.updateArtifactTarget(config.id, '../escape.json');

    expect(controller.saveIssue, 'Every selected row needs a target path.');
    expect(controller.canSaveConfiguration, isFalse);
  });

  test(
    'save republishes the same configuration instead of duplicating it',
    () async {
      final store = _FakeStore();
      final controller = await readyController(
        store: store,
        configurationId: 'configuration-repeat',
      );

      await controller.saveConfiguration();
      await controller.saveConfiguration();

      expect(store.saved, hasLength(1));
      expect(store.saved.single.id, 'configuration-repeat');
    },
  );
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

class _FakeDownloader implements ModelArtifactDownloader {
  _FakeDownloader({this.hold = false});

  final bool hold;
  final List<String> requests = [];
  final List<_FakeDownload> downloads = [];
  final Completer<void> _started = Completer<void>();

  /// Completes once [start] has recorded a download.
  Future<void> get started => _started.future;

  @override
  ModelArtifactDownload start({
    required String repositoryId,
    required String revision,
    required String path,
    required String destinationPath,
    required void Function(int received, int total) onProgress,
  }) {
    requests.add(path);
    final download = _FakeDownload(
      path: path,
      destinationPath: destinationPath,
      onProgress: onProgress,
      hold: hold,
    );
    downloads.add(download);
    if (!_started.isCompleted) _started.complete();
    return download;
  }
}

class _FakeDownload implements ModelArtifactDownload {
  _FakeDownload({
    required this.path,
    required this.destinationPath,
    required this.onProgress,
    required this.hold,
  }) {
    _done = _run();
  }

  final String path;
  final String destinationPath;
  final void Function(int received, int total) onProgress;
  final bool hold;

  late final Future<void> _done;
  final Completer<void> _gate = Completer();
  final Completer<void> _halfway = Completer();
  bool _paused = false;

  @override
  Future<void> get done => _done;

  /// Completes once the fake has reported half of the file.
  Future<void> get halfway => _halfway.future;

  @override
  bool get isPaused => _paused;

  @override
  void pause() => _paused = true;

  @override
  void resume() => _paused = false;

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  Future<void> _run() async {
    onProgress(0, 100);
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsString('partial:$path');
    onProgress(50, 100);
    if (!_halfway.isCompleted) _halfway.complete();
    if (hold) await _gate.future;
    await file.writeAsString('downloaded:$path');
    onProgress(100, 100);
  }
}

class _RangeAdapter implements HttpClientAdapter {
  _RangeAdapter(this.payload);

  final Uint8List payload;
  final List<String> ranges = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    String? range;
    for (final entry in options.headers.entries) {
      if (entry.key.toLowerCase() == 'range') {
        range = entry.value?.toString();
        break;
      }
    }
    if (range != null) ranges.add(range);
    final start =
        int.tryParse(
          RegExp(r'bytes=(\d+)-').firstMatch(range ?? '')?.group(1) ?? '',
        ) ??
        0;
    final remaining = payload.sublist(start);
    const chunkSize = 100;
    final chunks = <Uint8List>[
      for (var index = 0; index < remaining.length; index += chunkSize)
        Uint8List.fromList(
          remaining.sublist(
            index,
            index + chunkSize > remaining.length
                ? remaining.length
                : index + chunkSize,
          ),
        ),
    ];
    return ResponseBody(
      Stream<Uint8List>.fromIterable(chunks),
      206,
      headers: {
        Headers.contentLengthHeader: ['${remaining.length}'],
        'content-range': [
          'bytes $start-${payload.length - 1}/${payload.length}',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
