import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../models/model_configuration_record.dart';
import '../catalogue/catalogue_model.dart';
import 'configured_model_store.dart';
import 'model_artifact.dart';
import 'model_artifact_storage.dart';
import 'model_setup_assessment.dart';
import 'model_setup_assessor.dart';

enum ModelSetupStageState { pending, running, completed, failed }

enum ModelArtifactSectionSelection { none, partial, all }

class ModelSetupStageProgress {
  const ModelSetupStageProgress({
    required this.stage,
    this.state = ModelSetupStageState.pending,
    this.error,
  });

  final ModelSetupStage stage;
  final ModelSetupStageState state;
  final String? error;

  ModelSetupStageProgress copyWith({
    ModelSetupStageState? state,
    String? error,
  }) {
    return ModelSetupStageProgress(
      stage: stage,
      state: state ?? this.state,
      error: error,
    );
  }
}

typedef ModelArtifactStorageFactory = ModelArtifactStorage Function(
  String rootPath,
);

/// Shared state for all three wizard steps.
///
/// Step 2 owns the configuration-specific artifact rows. Step 3 reads the same
/// controller so navigating backwards never drops a selection or download.
class ModelSetupWizardController extends ChangeNotifier {
  ModelSetupWizardController({
    required this.details,
    required this.assessor,
    this.downloader,
    this.store,
    ModelArtifactStorageFactory? storageFactory,
    String? configurationId,
  }) : _storageFactory =
           storageFactory ?? ((rootPath) => FileModelArtifactStorage(rootPath)),
       configurationId = configurationId ?? _newConfigurationId(details),
       _stages = [
         for (final stage in ModelSetupStage.values)
           ModelSetupStageProgress(stage: stage),
       ];

  final ModelDetails details;
  final ModelSetupAssessor assessor;
  final ModelArtifactDownloader? downloader;
  final ConfiguredModelStore? store;
  final String configurationId;
  final ModelArtifactStorageFactory _storageFactory;

  static String _newConfigurationId(ModelDetails details) {
    final base = (details.commitSha ?? details.branch).trim();
    final suffix = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return base.isEmpty ? 'configuration-$suffix' : '$base-$suffix';
  }

  List<ModelSetupStageProgress> _stages;
  ModelSetupAssessment? _assessment;
  int _currentStageIndex = -1;
  int _stepIndex = 0;
  bool _running = false;
  bool _succeeded = false;
  bool _disposed = false;

  List<ModelArtifactRow> _artifacts = const [];
  final Set<ModelArtifactKind> _collapsedSections = {};
  bool _artifactsPrepared = false;
  int _nextRowNumber = 1;
  int _nextTargetNumber = 1;
  bool _downloadAllRunning = false;
  final Map<String, ModelArtifactDownload> _activeDownloads = {};
  String? _artifactRootPath;
  ModelArtifactStorage? _storage;
  bool _saving = false;
  String? _saveError;
  String? _savedConfigurationId;
  DateTime? _createdAt;

  List<ModelSetupStageProgress> get stages => List.unmodifiable(_stages);
  ModelSetupAssessment? get assessment => _assessment;
  ModelSetupSelection? get selection => _assessment?.selection;
  int get stepIndex => _stepIndex;
  int get stepCount => 3;
  bool get isRunning => _running;
  bool get succeeded => _succeeded;
  bool get downloadAllRunning => _downloadAllRunning;

  bool get canContinue {
    if (_running) return false;
    return switch (_stepIndex) {
      0 => _succeeded,
      1 => artifactsComplete,
      _ => false,
    };
  }

  List<ModelArtifactRow> get artifacts => List.unmodifiable(_artifacts);

  String get artifactRootPath => _artifactRootPath ?? '';

  List<ModelArtifactRow> artifactsFor(ModelArtifactKind kind) =>
      List.unmodifiable(_artifacts.where((row) => row.kind == kind));

  bool isSectionExpanded(ModelArtifactKind kind) =>
      !_collapsedSections.contains(kind);

  ModelArtifactSectionSelection sectionSelection(ModelArtifactKind kind) {
    final rows = _artifacts
        .where((row) => row.kind == kind)
        .toList(growable: false);
    if (rows.isEmpty || rows.every((row) => !row.selected)) {
      return ModelArtifactSectionSelection.none;
    }
    if (rows.every((row) => row.selected)) {
      return ModelArtifactSectionSelection.all;
    }
    return ModelArtifactSectionSelection.partial;
  }

  void toggleSectionSelection(ModelArtifactKind kind) {
    final rows = _artifacts
        .where((row) => row.kind == kind)
        .toList(growable: false);
    if (rows.isEmpty) return;
    final selected = !rows.every((row) => row.selected);
    _artifacts = List.unmodifiable([
      for (final row in _artifacts)
        row.kind == kind ? row.copyWith(selected: selected) : row,
    ]);
    _saveError = null;
    _notify();
  }

  int get selectedArtifactCount =>
      _artifacts.where((row) => row.selected).length;

  int get missingArtifactCount =>
      _artifacts.where((row) => row.selected && !row.isReady).length;

  int get readyArtifactCount =>
      _artifacts.where((row) => row.selected && row.isReady).length;

  bool get hasSelectedWeights => _artifacts.any(
    (row) => row.selected && row.kind == ModelArtifactKind.weights,
  );

  bool get needsWeightSuggestion =>
      _artifacts.any((row) => row.kind == ModelArtifactKind.weights) &&
      !hasSelectedWeights;

  bool get artifactsComplete =>
      selectedArtifactCount > 0 &&
      hasSelectedWeights &&
      missingArtifactCount == 0;

  bool get hasDownloadableSelection =>
      _artifacts.any((row) => row.selected && row.canDownload);

  String get runtimeId =>
      selection?.runtimeId ?? _assessment?.runtimeConstraints?.runtimeId ?? '';

  String? get savedConfigurationId => _savedConfigurationId;

  bool get isSaving => _saving;

  String? get saveError => _saveError;

  /// The first structural problem blocking persistence, or `null` when every
  /// selected row has a source and a valid configuration-relative target.
  String? get saveIssue {
    for (final row in _artifacts) {
      if (!row.selected) continue;
      if (normalizeArtifactTarget(row.targetPath) == null) {
        return 'Every selected row needs a target path.';
      }
      if (row.isTransferring) {
        return 'Wait for the current transfer to finish before saving.';
      }
      final missingSource = switch (row.sourceType) {
        ModelArtifactSourceType.unassigned => true,
        ModelArtifactSourceType.repository => row.repositoryFile == null,
        ModelArtifactSourceType.device =>
          row.deviceSourcePath?.trim().isEmpty ?? true,
      };
      if (missingSource) return 'Every selected row needs a source file.';
    }
    return null;
  }

  /// Saving is independent of downloads; only incomplete rows block it.
  bool get canSaveConfiguration => !_saving && !_running && saveIssue == null;

  /// Testing needs the artifacts on disk, not just a saved configuration.
  bool get canTestArtifacts => !_saving && artifactsComplete;

  Future<void> runAssessment() async {
    if (_running) return;
    _running = true;
    _succeeded = false;
    _assessment = null;
    _currentStageIndex = -1;
    _artifacts = const [];
    _artifactsPrepared = false;
    _artifactRootPath = null;
    _storage = null;
    _collapsedSections.clear();
    _saving = false;
    _saveError = null;
    _savedConfigurationId = null;
    _createdAt = null;
    _stages = [
      for (final stage in ModelSetupStage.values)
        ModelSetupStageProgress(stage: stage),
    ];
    _notify();

    try {
      await assessor.run(
        details: details,
        onStarted: (stage) {
          _currentStageIndex = stage.index;
          _setStage(stage, ModelSetupStageState.running);
        },
        onCompleted: (stage, assessment) {
          _assessment = assessment;
          _setStage(stage, ModelSetupStageState.completed);
        },
        onUpdated: (assessment) {
          _assessment = assessment;
          _notify();
        },
      );
      _succeeded = true;
    } on Object catch (error) {
      final index = _currentStageIndex < 0 ? 0 : _currentStageIndex;
      _stages[index] = _stages[index].copyWith(
        state: ModelSetupStageState.failed,
        error: _errorText(error),
      );
    } finally {
      _running = false;
      _notify();
    }
  }

  void updateAssessment(ModelSetupAssessment assessment) {
    _assessment = assessment;
    _notify();
  }

  /// Builds the initial rows once from the assessment's final selection.
  ///
  /// Discovery never implies a download: rows start idle and the status stays
  /// incomplete until every selected file exists in this configuration.
  void prepareArtifacts() {
    if (_artifactsPrepared) return;
    _artifactsPrepared = true;
    _artifactRootPath = FileModelArtifactStorage.rootFor(
      documentsPath:
          _assessment?.runtimeConstraints?.storagePath ??
          _assessment?.runtime?.documentsPath ??
          '',
      repositoryId: details.model.id,
      configurationId: configurationId,
    );
    _storage = null;

    final selection = _assessment?.selection;
    if (selection == null) return;
    final rows = <ModelArtifactRow>[];
    void addAll(
      ModelArtifactKind kind,
      List<ModelFile> files, {
      Set<String>? selectedPaths,
    }) {
      for (final file in files) {
        if (file.isDirectory || file.path.trim().isEmpty) continue;
        rows.add(
          ModelArtifactRow(
            id: 'artifact-${_nextRowNumber++}',
            kind: kind,
            sourceType: ModelArtifactSourceType.repository,
            repositoryFile: file,
            targetPath: _defaultTarget(kind, file, rows),
            selected: selectedPaths?.contains(file.path) ?? true,
            sizeBytes: file.sizeBytes,
          ),
        );
      }
    }

    final defaultWeight = _defaultWeightFile(selection.weightFiles);
    addAll(ModelArtifactKind.configuration, selection.configurationFiles);
    addAll(ModelArtifactKind.helper, selection.helperFiles);
    addAll(
      ModelArtifactKind.weights,
      selection.weightFiles,
      selectedPaths: defaultWeight == null ? const {} : {defaultWeight.path},
    );

    final storage = _storageFor(rootPath: _artifactRootPath ?? '');
    _artifacts = List.unmodifiable([
      for (final row in rows) _restoreExistingCopy(row, storage),
    ]);
  }

  ModelArtifactRow _restoreExistingCopy(
    ModelArtifactRow row,
    ModelArtifactStorage? storage,
  ) {
    if (storage == null) return row;
    final path = storage.resolve(row.targetPath);
    if (path.isEmpty) return row;
    final file = File(path);
    try {
      if (!file.existsSync()) return row;
      return row.copyWith(
        status: ModelArtifactStatus.ready,
        progress: 1.0,
        localPath: path,
        sizeBytes: file.lengthSync(),
      );
    } on FileSystemException {
      return row;
    }
  }

  String _defaultTarget(
    ModelArtifactKind kind,
    ModelFile file,
    List<ModelArtifactRow> existing,
  ) {
    final name = file.name;
    final collision = existing.any(
      (row) => row.kind == kind && row.targetPath == name,
    );
    if (!collision) return name;
    final path = file.path.trim();
    return path.isEmpty ? name : path;
  }

  /// Picks at most one weight row during setup. Every weight remains selectable
  /// afterwards, but the initial selection must not include every quantisation.
  ModelFile? _defaultWeightFile(List<ModelFile> weights) {
    if (weights.isEmpty) return null;

    final hintedPath = _configuredWeightPath();
    if (hintedPath != null) {
      for (final file in weights) {
        if (file.path == hintedPath || file.name == hintedPath) return file;
      }
    }
    if (weights.length == 1) return weights.single;

    final repositoryName = details.model.name.toLowerCase();
    for (final file in weights) {
      final name = file.name.toLowerCase();
      final stem = name.contains('.')
          ? name.substring(0, name.lastIndexOf('.'))
          : name;
      if (name == 'model.litertlm' ||
          stem == repositoryName ||
          stem == 'model') {
        return file;
      }
    }

    final fourBit = weights
        .where((file) {
          final name = file.name.toLowerCase();
          return name.contains('fp4') || name.contains('int4');
        })
        .toList(growable: false);
    if (fourBit.isNotEmpty) return _smallestWeight(fourBit);

    final sized = weights
        .where((file) => (file.sizeBytes ?? 0) > 0)
        .toList(growable: false);
    return sized.isEmpty ? null : _smallestWeight(sized);
  }

  String? _configuredWeightPath() {
    const keys = [
      'weight_file',
      'weights_file',
      'model_file',
      'model_filename',
      'litertlm_file',
    ];
    for (final key in keys) {
      final value = details.config[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  ModelFile? _smallestWeight(List<ModelFile> weights) {
    final sized = weights
        .where((file) => (file.sizeBytes ?? 0) > 0)
        .toList(growable: false);
    final candidates = sized.isEmpty ? weights : sized;
    ModelFile? smallest;
    for (final file in candidates) {
      if (smallest == null ||
          (file.sizeBytes ?? 0) < (smallest.sizeBytes ?? 0)) {
        smallest = file;
      }
    }
    return smallest;
  }

  void toggleSection(ModelArtifactKind kind) {
    if (!_collapsedSections.remove(kind)) _collapsedSections.add(kind);
    _notify();
  }

  void toggleArtifactSelected(String id) {
    final row = _rowById(id);
    if (row == null) return;
    _replaceRow(row.copyWith(selected: !row.selected));
    _notify();
  }

  ModelArtifactRow? addArtifactRow(ModelArtifactKind kind) {
    prepareArtifacts();
    final number = _nextTargetNumber++;
    final row = ModelArtifactRow(
      id: 'artifact-${_nextRowNumber++}',
      kind: kind,
      targetPath: kind.newTargetPath(number),
    );
    _artifacts = List.unmodifiable([..._artifacts, row]);
    _saveError = null;
    _notify();
    return row;
  }

  Future<void> removeArtifactRow(String id) async {
    final row = _rowById(id);
    if (row == null) return;
    if (row.hasLocalCopy) {
      await _deleteQuietly(row.localPath!);
    }
    _artifacts = List.unmodifiable(_artifacts.where((item) => item.id != id));
    _saveError = null;
    _notify();
  }

  Future<void> updateArtifactTarget(String id, String targetPath) async {
    final row = _rowById(id);
    if (row == null) return;
    final normalized = normalizeArtifactTarget(targetPath);
    final next = row.copyWith(
      targetPath: targetPath.trim(),
      targetEdited: true,
    );
    if (row.localPath == null || normalized == null) {
      _replaceRow(next);
      _notify();
      return;
    }
    final destination = _storage?.resolve(targetPath) ?? '';
    if (destination.isEmpty || destination == row.localPath) {
      _replaceRow(next);
      _notify();
      return;
    }
    // Apply the edit before moving the file so Save never reads a stale path.
    _replaceRow(next);
    _notify();
    try {
      await _storage!.moveFile(row.localPath!, targetPath);
      _replaceRowById(
        id,
        (current) => current.copyWith(localPath: destination),
      );
    } on FileSystemException catch (error) {
      _replaceRowById(
        id,
        (current) => current.copyWith(
          targetPath: row.targetPath,
          localPath: row.localPath,
          error: _errorText(error),
        ),
      );
    }
    _notify();
  }

  Future<void> assignRepositoryArtifact(String id, ModelFile file) async {
    final row = _rowById(id);
    if (row == null) return;
    await _clearLocalCopy(row);
    final next = row.copyWith(
      sourceType: ModelArtifactSourceType.repository,
      repositoryFile: file,
      deviceSourcePath: null,
      targetPath: row.targetEdited
          ? row.targetPath
          : artifactFileName(file.path),
      selected: true,
      status: ModelArtifactStatus.idle,
      progress: null,
      receivedBytes: null,
      localPath: null,
      error: null,
      sizeBytes: file.sizeBytes,
    );
    _replaceRow(next);
    _notify();
  }

  Future<void> assignDeviceArtifact(String id, String sourcePath) async {
    final row = _rowById(id);
    if (row == null) return;
    final path = sourcePath.trim();
    if (path.isEmpty) return;
    await _clearLocalCopy(row);
    final target = row.targetEdited ? row.targetPath : artifactFileName(path);
    int? size;
    try {
      size = await File(path).length();
    } on FileSystemException {
      size = null;
    }
    _replaceRow(
      row.copyWith(
        sourceType: ModelArtifactSourceType.device,
        repositoryFile: null,
        deviceSourcePath: path,
        targetPath: target,
        selected: true,
        status: ModelArtifactStatus.working,
        progress: null,
        receivedBytes: null,
        localPath: null,
        error: null,
        sizeBytes: size,
      ),
    );
    _notify();

    final storage = _storageFor(rootPath: _artifactRootPath ?? '');
    if (storage == null) {
      _failRow(id, 'This configuration has no writable artifact directory.');
      return;
    }
    try {
      await storage.copyFile(path, target);
      final destination = storage.resolve(target);
      _replaceRowById(
        id,
        (current) => current.copyWith(
          status: ModelArtifactStatus.ready,
          progress: 1.0,
          localPath: destination,
          sizeBytes: size ?? 0,
          error: null,
        ),
      );
    } on FileSystemException catch (error) {
      _failRow(id, error.message);
    } on Object catch (error) {
      _failRow(id, _errorText(error));
    }
    _notify();
  }

  Future<void> downloadArtifact(String id) async {
    final row = _rowById(id);
    if (row == null || !row.canDownload || _activeDownloads.containsKey(id)) {
      return;
    }
    final file = row.repositoryFile;
    if (file == null) return;
    final storage = _storageFor(rootPath: _artifactRootPath ?? '');
    if (storage == null) {
      _failRow(id, 'This configuration has no writable artifact directory.');
      _notify();
      return;
    }
    final destination = storage.resolve(row.targetPath);
    if (destination.isEmpty) {
      _failRow(id, 'Enter a valid target path before downloading.');
      _notify();
      return;
    }
    final activeDownloader = downloader;
    if (activeDownloader == null) {
      _failRow(id, 'Downloads are unavailable in this build.');
      _notify();
      return;
    }

    await _deleteQuietly(row.localPath);
    _replaceRowById(
      id,
      (current) => current.copyWith(
        status: ModelArtifactStatus.working,
        progress: 0,
        receivedBytes: 0,
        localPath: null,
        error: null,
      ),
    );
    _notify();

    final download = activeDownloader.start(
      repositoryId: details.model.id,
      revision: details.branch,
      path: file.path,
      destinationPath: destination,
      onProgress: (received, total) {
        _replaceRowById(id, (current) {
          if (!current.isTransferring) return current;
          return current.copyWith(
            progress: total > 0 ? received / total : null,
            receivedBytes: received,
            sizeBytes: total > 0 ? total : current.sizeBytes,
          );
        });
        _notify();
      },
    );
    _activeDownloads[id] = download;
    try {
      await download.done;
      final downloaded = File(destination);
      if (!await downloaded.exists()) {
        throw const FileSystemException(
          'The downloaded file was not written to disk.',
        );
      }
      final downloadedSize = await _fileSize(destination);
      _replaceRowById(
        id,
        (current) => current.copyWith(
          status: ModelArtifactStatus.ready,
          progress: 1.0,
          receivedBytes: downloadedSize ?? current.receivedBytes,
          localPath: destination,
          sizeBytes: downloadedSize ?? current.sizeBytes,
          error: null,
        ),
      );
    } on Object catch (error) {
      await _deleteQuietly(destination);
      _failRow(id, _errorText(error));
    } finally {
      _activeDownloads.remove(id);
    }
    _notify();
  }

  void pauseArtifactDownload(String id) {
    final download = _activeDownloads[id];
    final row = _rowById(id);
    if (download == null || row == null || !row.isWorking) return;
    download.pause();
    _replaceRowById(
      id,
      (current) => current.copyWith(status: ModelArtifactStatus.paused),
    );
    _notify();
  }

  void resumeArtifactDownload(String id) {
    final download = _activeDownloads[id];
    final row = _rowById(id);
    if (download == null || row == null || !row.isPaused) return;
    _replaceRowById(
      id,
      (current) => current.copyWith(status: ModelArtifactStatus.working),
    );
    download.resume();
    _notify();
  }

  Future<void> downloadAllArtifacts() async {
    if (_downloadAllRunning) return;
    final pending = _artifacts
        .where((row) => row.canDownload)
        .map((row) => row.id)
        .toList(growable: false);
    if (pending.isEmpty) return;
    _downloadAllRunning = true;
    _notify();
    try {
      for (final id in pending) {
        await downloadArtifact(id);
      }
    } finally {
      _downloadAllRunning = false;
      _notify();
    }
  }

  Future<void> deleteArtifactCopy(String id) async {
    final row = _rowById(id);
    if (row == null || row.isTransferring) return;
    await _deleteQuietly(row.localPath);
    _replaceRow(
      row.copyWith(
        status: ModelArtifactStatus.idle,
        progress: null,
        receivedBytes: null,
        localPath: null,
        error: null,
      ),
    );
    _notify();
  }

  /// Upserts this configuration and its artifact rows.
  ///
  /// Only configuration metadata and artifact rows are written; the pre-check
  /// assessment stays in memory for this wizard session.
  Future<bool> saveConfiguration() async {
    if (!canSaveConfiguration) return false;
    prepareArtifacts();
    final store = this.store;
    if (store == null) {
      _saveError = 'Saved configurations are unavailable in this build.';
      _notify();
      return false;
    }
    _saving = true;
    _saveError = null;
    _notify();
    try {
      final now = DateTime.now();
      final id = _savedConfigurationId ?? configurationId;
      final created = _createdAt ??= now;
      await store.save(
        ConfiguredModel(
          id: id,
          repositoryId: details.model.id,
          displayName: details.model.name,
          runtimeId: runtimeId,
          branch: details.branch,
          commitSha: details.commitSha,
          rootPath: artifactRootPath,
          createdAt: created,
          updatedAt: now,
          artifacts: [
            for (var index = 0; index < _artifacts.length; index++)
              _artifactRecord(_artifacts[index], id, index),
          ],
        ),
      );
      _savedConfigurationId = id;
      return true;
    } on Object catch (error) {
      _saveError = _errorText(error);
      return false;
    } finally {
      _saving = false;
      _notify();
    }
  }

  ConfiguredModelArtifact _artifactRecord(
    ModelArtifactRow row,
    String configurationId,
    int position,
  ) {
    return ConfiguredModelArtifact(
      id: '${configurationId}_${row.id}',
      kind: row.kind.name,
      sourceType: row.sourceType.name,
      repositoryPath: row.repositoryFile?.path,
      deviceSourcePath: row.deviceSourcePath,
      targetPath: row.targetPath.trim(),
      sizeBytes: row.sizeBytes,
      selected: row.selected,
      downloaded: row.isReady,
      position: position,
    );
  }

  void nextStep() {
    if (!canContinue || _stepIndex >= stepCount - 1) return;
    if (_stepIndex == 0) prepareArtifacts();
    _stepIndex += 1;
    _notify();
  }

  void previousStep() {
    if (_stepIndex <= 0) return;
    _stepIndex -= 1;
    _notify();
  }

  ModelArtifactStorage? _storageFor({required String rootPath}) {
    final root = rootPath.trim();
    if (root.isEmpty) return null;
    return _storage ??= _storageFactory(root);
  }

  ModelArtifactRow? _rowById(String id) {
    for (final row in _artifacts) {
      if (row.id == id) return row;
    }
    return null;
  }

  void _replaceRow(ModelArtifactRow row) {
    _saveError = null;
    _artifacts = List.unmodifiable(
      _artifacts.map((item) => item.id == row.id ? row : item),
    );
  }

  void _replaceRowById(
    String id,
    ModelArtifactRow Function(ModelArtifactRow row) update,
  ) {
    final row = _rowById(id);
    if (row == null) return;
    _replaceRow(update(row));
  }

  void _failRow(String id, String message) {
    _replaceRowById(
      id,
      (row) => row.copyWith(
        status: ModelArtifactStatus.failed,
        progress: null,
        receivedBytes: null,
        localPath: null,
        error: message,
      ),
    );
  }

  Future<void> _clearLocalCopy(ModelArtifactRow row) async {
    if (!row.hasLocalCopy) return;
    await _deleteQuietly(row.localPath!);
  }

  Future<void> _deleteQuietly(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A stale file must not block the row transition; the next write
      // overwrites the same target and the UI surfaces real write failures.
    }
  }

  Future<int?> _fileSize(String path) async {
    try {
      return await File(path).length();
    } on FileSystemException {
      return null;
    }
  }

  void _setStage(ModelSetupStage stage, ModelSetupStageState state) {
    _stages[stage.index] = _stages[stage.index].copyWith(state: state);
    _notify();
  }

  String _errorText(Object error) {
    if (error is ModelSetupFailure) return error.message;
    if (error is FileSystemException) {
      return error.message.isEmpty ? error.toString() : error.message;
    }
    return error.toString();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
