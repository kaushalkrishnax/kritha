import '../../../services/device_probe.dart';
import '../../../services/runtime_probe.dart';
import '../catalogue/catalogue_model.dart';
import '../catalogue/model_identifiers.dart';

/// Fixed pre-check sequence. The order is part of the wizard contract.
enum ModelSetupStage {
  checkingDeviceStatus(
    'Checking device status',
    'Reading the platform, architecture and processor details.',
  ),
  checkingRuntimeConstraints(
    'Checking runtime constraints',
    'Verifying the installed runtime and application storage.',
  ),
  mappingArtifacts(
    'Mapping artifacts',
    'Mapping configuration, helper and weight files from the repository.',
  ),
  assessingArtifacts(
    'Assessing artifacts',
    'Checking each artifact against the installed runtime.',
  ),
  checkingDeviceCompatibility(
    'Checking device compatibility',
    'Comparing the device, runtime and artifact requirements.',
  ),
  finalizingArtifacts(
    'Finalizing artifacts',
    'Preparing the artifact selection for the next step.',
  ),
  done('Done', 'Wrapping up the pre-check assessment.');

  const ModelSetupStage(this.label, this.activity);

  final String label;
  final String activity;
}

enum ModelArtifactKind { configuration, helper, weights }

class SetupArtifact {
  const SetupArtifact({required this.file, required this.kind});

  final ModelFile file;
  final ModelArtifactKind kind;

  String get path => file.path;
}

class ArtifactAssessment {
  const ArtifactAssessment({
    required this.artifact,
    required this.supported,
    required this.message,
  });

  final SetupArtifact artifact;
  final bool supported;
  final String message;
}

class CompatibilityCheck {
  const CompatibilityCheck({
    required this.label,
    required this.passed,
    required this.detail,
  });

  final String label;
  final bool passed;
  final String detail;
}

class RuntimeConstraints {
  const RuntimeConstraints({
    required this.runtimeId,
    required this.runtimeAvailable,
    required this.storageWritable,
    required this.storagePath,
    required this.storageError,
    required this.sherpaVersion,
    required this.onnxRuntimeVersion,
  });

  final String runtimeId;
  final bool runtimeAvailable;
  final bool storageWritable;
  final String storagePath;
  final String? storageError;
  final String sherpaVersion;
  final String onnxRuntimeVersion;

  bool get satisfied => runtimeAvailable && storageWritable;
}

class ModelSetupModelInfo {
  const ModelSetupModelInfo({
    required this.repositoryId,
    required this.displayName,
    this.parameterCount,
    this.architecture,
    this.contextLength,
    this.formats = const [],
    this.quantizations = const [],
    this.weightPrecisions = const [],
    this.libraryName,
  });

  factory ModelSetupModelInfo.fromDetails(ModelDetails details) {
    return ModelSetupModelInfo(
      repositoryId: details.model.id,
      displayName: details.model.name,
      parameterCount: details.parameterCount,
      architecture: details.architecture,
      contextLength: details.contextLength,
      formats: details.formats,
      quantizations: details.quantizations,
      weightPrecisions: details.weightPrecisions,
      libraryName: details.libraryName,
    );
  }

  final String repositoryId;
  final String displayName;
  final int? parameterCount;
  final String? architecture;
  final int? contextLength;
  final List<String> formats;
  final List<String> quantizations;
  final List<String> weightPrecisions;
  final String? libraryName;

  /// Whether a declared format and the library are the same identifier.
  bool get formatMatchesLibrary =>
      declaredFormatMatchesLibrary(formats: formats, libraryName: libraryName);

  bool matchesFormat(String identifier) =>
      modelIdentifiersMatch(libraryName, identifier) ||
      formats.any((format) => modelIdentifiersMatch(format, identifier));
}

class RepositoryInformation {
  const RepositoryInformation({
    required this.id,
    required this.url,
    required this.branch,
    this.author,
    this.license,
    this.commitSha,
    this.gated = false,
    this.isPrivate = false,
    this.sizeBytes = 0,
  });

  factory RepositoryInformation.fromDetails(ModelDetails details) {
    return RepositoryInformation(
      id: details.model.id,
      url: details.repositoryUrl,
      branch: details.branch,
      author: details.model.publisher,
      license: details.model.license,
      commitSha: details.commitSha,
      gated: details.model.gated,
      isPrivate: details.model.isPrivate,
      sizeBytes: details.repositorySize,
    );
  }

  final String id;
  final String url;
  final String branch;
  final String? author;
  final String? license;
  final String? commitSha;
  final bool gated;
  final bool isPrivate;
  final int sizeBytes;
}

class ModelSetupSelection {
  const ModelSetupSelection({
    required this.runtimeId,
    required this.configurationFiles,
    required this.helperFiles,
    required this.weightFiles,
  });

  final String runtimeId;
  final List<ModelFile> configurationFiles;
  final List<ModelFile> helperFiles;
  final List<ModelFile> weightFiles;

  int get knownDownloadBytes =>
      weightFiles.fold(0, (total, file) => total + (file.sizeBytes ?? 0));
}

/// Everything discovered and evaluated during the pre-checks.
///
/// The later wizard steps read this same object, so it carries the source
/// model details alongside the derived runtime and compatibility results.
class ModelSetupAssessment {
  const ModelSetupAssessment({
    required this.details,
    required this.model,
    required this.repository,
    this.device,
    this.runtime,
    this.runtimeConstraints,
    this.artifacts = const [],
    this.artifactAssessments = const [],
    this.compatibilityChecks = const [],
    this.selection,
  });

  final ModelDetails details;
  final ModelSetupModelInfo model;
  final RepositoryInformation repository;
  final DeviceStatus? device;
  final RuntimeStatus? runtime;
  final RuntimeConstraints? runtimeConstraints;
  final List<SetupArtifact> artifacts;
  final List<ArtifactAssessment> artifactAssessments;
  final List<CompatibilityCheck> compatibilityChecks;
  final ModelSetupSelection? selection;

  List<SetupArtifact> get configurationFiles => List.unmodifiable(
    artifacts.where(
      (artifact) => artifact.kind == ModelArtifactKind.configuration,
    ),
  );

  List<SetupArtifact> get helperFiles => List.unmodifiable(
    artifacts.where((artifact) => artifact.kind == ModelArtifactKind.helper),
  );

  List<SetupArtifact> get weightFiles => List.unmodifiable(
    artifacts.where((artifact) => artifact.kind == ModelArtifactKind.weights),
  );

  bool get hasUnsupportedArtifacts =>
      artifactAssessments.any((assessment) => !assessment.supported);

  bool get isCompatible => compatibilityChecks.every((check) => check.passed);
}
