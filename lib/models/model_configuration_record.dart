/// A saved model configuration and the artifacts it owns.
///
/// Only user-facing configuration data lives here. Pre-check results (device,
/// runtime probes and compatibility decisions) are deliberately not persisted;
/// they are re-evaluated whenever the wizard opens.
class ConfiguredModel {
  const ConfiguredModel({
    required this.id,
    required this.repositoryId,
    required this.displayName,
    required this.runtimeId,
    required this.branch,
    required this.rootPath,
    required this.createdAt,
    required this.updatedAt,
    this.commitSha,
    this.artifacts = const [],
  });

  final String id;
  final String repositoryId;
  final String displayName;
  final String runtimeId;
  final String branch;
  final String? commitSha;

  /// Root directory owned by this configuration.
  final String rootPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ConfiguredModelArtifact> artifacts;

  List<ConfiguredModelArtifact> get selectedArtifacts =>
      List.unmodifiable(artifacts.where((artifact) => artifact.selected));

  bool get isReady =>
      selectedArtifacts.isNotEmpty &&
      selectedArtifacts.every((artifact) => artifact.downloaded);
}

class ConfiguredModelArtifact {
  const ConfiguredModelArtifact({
    required this.id,
    required this.kind,
    required this.sourceType,
    required this.targetPath,
    required this.selected,
    required this.downloaded,
    required this.position,
    this.repositoryPath,
    this.deviceSourcePath,
    this.sizeBytes,
  });

  final String id;

  /// `configuration`, `helper` or `weights`.
  final String kind;

  /// `repository`, `device` or `unassigned`.
  final String sourceType;
  final String? repositoryPath;
  final String? deviceSourcePath;
  final String targetPath;
  final int? sizeBytes;
  final bool selected;
  final bool downloaded;
  final int position;
}
