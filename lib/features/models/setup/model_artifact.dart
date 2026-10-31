import '../catalogue/catalogue_model.dart';
import 'model_setup_assessment.dart';

enum ModelArtifactSourceType { repository, device, unassigned }

enum ModelArtifactStatus { idle, working, paused, ready, failed }

/// One editable artifact row owned by the open model configuration.
class ModelArtifactRow {
  const ModelArtifactRow({
    required this.id,
    required this.kind,
    required this.targetPath,
    this.sourceType = ModelArtifactSourceType.unassigned,
    this.repositoryFile,
    this.deviceSourcePath,
    this.targetEdited = false,
    this.selected = true,
    this.status = ModelArtifactStatus.idle,
    this.progress,
    this.receivedBytes,
    this.localPath,
    this.error,
    this.sizeBytes,
  });

  final String id;
  final ModelArtifactKind kind;
  final ModelArtifactSourceType sourceType;
  final ModelFile? repositoryFile;
  final String? deviceSourcePath;
  final String targetPath;
  final bool targetEdited;
  final bool selected;
  final ModelArtifactStatus status;
  final double? progress;
  final int? receivedBytes;
  final String? localPath;
  final String? error;
  final int? sizeBytes;

  bool get isRepository =>
      sourceType == ModelArtifactSourceType.repository &&
      repositoryFile != null;

  bool get isDevice =>
      sourceType == ModelArtifactSourceType.device &&
      (deviceSourcePath?.trim().isNotEmpty ?? false);

  bool get isUnassigned => sourceType == ModelArtifactSourceType.unassigned;

  bool get isWorking => status == ModelArtifactStatus.working;

  bool get isPaused => status == ModelArtifactStatus.paused;

  bool get isTransferring => isWorking || isPaused;

  bool get isReady => status == ModelArtifactStatus.ready;

  bool get hasLocalCopy => localPath?.trim().isNotEmpty ?? false;

  bool get canDownload =>
      isRepository && selected && !isTransferring && !isReady;

  bool get canReplace => selected && !isTransferring && !isUnassigned;

  bool get canChoose => selected && !isTransferring;

  String? get viewPath {
    if (!selected || isTransferring || kind == ModelArtifactKind.weights) {
      return null;
    }
    if (hasLocalCopy) return localPath;
    if (isDevice) return deviceSourcePath;
    return null;
  }

  String get displayName => switch (sourceType) {
    ModelArtifactSourceType.repository =>
      repositoryFile?.name ?? 'Repository file',
    ModelArtifactSourceType.device => _fileName(deviceSourcePath ?? ''),
    ModelArtifactSourceType.unassigned => 'No source assigned',
  };

  /// The path shown inside the repository card. Nested files keep their folder
  /// so the source remains distinguishable from a same-named top-level file.
  String get repositoryLabel {
    final file = repositoryFile;
    if (file == null) return '';
    final segments = file.path.split('/').where((part) => part.isNotEmpty);
    if (segments.length <= 1) return file.path;
    return segments.join(' / ');
  }

  String get sourceTooltip => switch (sourceType) {
    ModelArtifactSourceType.repository =>
      '${repositoryFile?.path ?? ''} in this repository',
    ModelArtifactSourceType.device => deviceSourcePath ?? 'Device file',
    ModelArtifactSourceType.unassigned => 'No source assigned',
  };

  ModelArtifactRow copyWith({
    ModelArtifactKind? kind,
    ModelArtifactSourceType? sourceType,
    Object? repositoryFile = _unset,
    Object? deviceSourcePath = _unset,
    String? targetPath,
    bool? targetEdited,
    bool? selected,
    ModelArtifactStatus? status,
    Object? progress = _unset,
    Object? receivedBytes = _unset,
    Object? localPath = _unset,
    Object? error = _unset,
    Object? sizeBytes = _unset,
  }) {
    return ModelArtifactRow(
      id: id,
      kind: kind ?? this.kind,
      sourceType: sourceType ?? this.sourceType,
      repositoryFile: identical(repositoryFile, _unset)
          ? this.repositoryFile
          : repositoryFile as ModelFile?,
      deviceSourcePath: identical(deviceSourcePath, _unset)
          ? this.deviceSourcePath
          : deviceSourcePath as String?,
      targetPath: targetPath ?? this.targetPath,
      targetEdited: targetEdited ?? this.targetEdited,
      selected: selected ?? this.selected,
      status: status ?? this.status,
      progress: identical(progress, _unset)
          ? this.progress
          : (progress as num?)?.toDouble(),
      receivedBytes: identical(receivedBytes, _unset)
          ? this.receivedBytes
          : receivedBytes as int?,
      localPath: identical(localPath, _unset)
          ? this.localPath
          : localPath as String?,
      error: identical(error, _unset) ? this.error : error as String?,
      sizeBytes: identical(sizeBytes, _unset)
          ? this.sizeBytes
          : sizeBytes as int?,
    );
  }
}

const _unset = Object();

extension ModelArtifactKindSection on ModelArtifactKind {
  String get sectionTitle => switch (this) {
    ModelArtifactKind.configuration => 'Config Files',
    ModelArtifactKind.helper => 'Helper Files',
    ModelArtifactKind.weights => 'Model Weights',
  };

  String get kindLabel => switch (this) {
    ModelArtifactKind.configuration => 'Configuration',
    ModelArtifactKind.helper => 'Helper',
    ModelArtifactKind.weights => 'Weights',
  };

  String newTargetPath(int index) => switch (this) {
    ModelArtifactKind.configuration => 'config/config_$index.json',
    ModelArtifactKind.helper => 'helper/helper_$index.bin',
    ModelArtifactKind.weights => 'weights/weights_$index.litertlm',
  };
}

String artifactFileName(String path) => _fileName(path);

String _fileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final clean = normalized.endsWith('/')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
  final slash = clean.lastIndexOf('/');
  return slash < 0 ? clean : clean.substring(slash + 1);
}
