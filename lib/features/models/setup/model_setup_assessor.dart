import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../services/device_probe.dart';
import '../../../services/runtime_probe.dart';
import '../../intelligence/runtime_ids.dart';
import '../catalogue/catalogue_model.dart';
import 'model_setup_assessment.dart';

class ModelSetupFailure implements Exception {
  const ModelSetupFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class _AssessmentCollector {
  _AssessmentCollector(this.details)
    : model = ModelSetupModelInfo.fromDetails(details),
      repository = RepositoryInformation.fromDetails(details);

  final ModelDetails details;
  final ModelSetupModelInfo model;
  final RepositoryInformation repository;
  DeviceStatus? device;
  RuntimeStatus? runtime;
  RuntimeConstraints? runtimeConstraints;
  List<SetupArtifact> artifacts = const [];
  List<ArtifactAssessment> artifactAssessments = const [];
  List<CompatibilityCheck> compatibilityChecks = const [];
  ModelSetupSelection? selection;

  ModelSetupAssessment snapshot() {
    return ModelSetupAssessment(
      details: details,
      model: model,
      repository: repository,
      device: device,
      runtime: runtime,
      runtimeConstraints: runtimeConstraints,
      artifacts: artifacts,
      artifactAssessments: artifactAssessments,
      compatibilityChecks: compatibilityChecks,
      selection: selection,
    );
  }
}

class ModelSetupAssessor {
  const ModelSetupAssessor({
    required this.runtimeStatus,
    this.deviceProbe = const DeviceProbe(),
  });

  final Future<RuntimeStatus> runtimeStatus;
  final DeviceProbe deviceProbe;

  Future<void> run({
    required ModelDetails details,
    required void Function(ModelSetupStage stage) onStarted,
    required void Function(
      ModelSetupStage stage,
      ModelSetupAssessment assessment,
    )
    onCompleted,
    required void Function(ModelSetupAssessment assessment) onUpdated,
  }) async {
    final collector = _AssessmentCollector(details);

    void complete(ModelSetupStage stage) {
      final assessment = collector.snapshot();
      onUpdated(assessment);
      onCompleted(stage, assessment);
    }

    onStarted(ModelSetupStage.checkingDeviceStatus);
    final device = deviceProbe.run();
    collector.device = device;
    if (!device.isSupported) {
      onUpdated(collector.snapshot());
      throw ModelSetupFailure(
        '${device.platformLabel} is not a supported platform for this build.',
      );
    }
    complete(ModelSetupStage.checkingDeviceStatus);

    onStarted(ModelSetupStage.checkingRuntimeConstraints);
    final runtime = await runtimeStatus;
    collector.runtime = runtime;
    final constraints = _checkRuntime(runtime);
    collector.runtimeConstraints = constraints;
    onUpdated(collector.snapshot());
    if (!constraints.runtimeAvailable) {
      throw const ModelSetupFailure(
        'The LiteRT-LM native runtime is not available on this device.',
      );
    }
    if (!constraints.storageWritable) {
      throw ModelSetupFailure(
        constraints.storageError ??
            'The application documents directory is not writable.',
      );
    }
    complete(ModelSetupStage.checkingRuntimeConstraints);

    onStarted(ModelSetupStage.mappingArtifacts);
    final artifacts = mapArtifacts(details.files);
    collector.artifacts = artifacts;
    if (artifacts.isEmpty) {
      onUpdated(collector.snapshot());
      throw const ModelSetupFailure(
        'The repository returned no files to inspect.',
      );
    }
    complete(ModelSetupStage.mappingArtifacts);

    onStarted(ModelSetupStage.assessingArtifacts);
    final assessments = assessArtifacts(artifacts);
    collector.artifactAssessments = assessments;
    final supportedWeights = assessments
        .where(
          (assessment) =>
              assessment.supported &&
              assessment.artifact.kind == ModelArtifactKind.weights,
        )
        .toList(growable: false);
    if (supportedWeights.isEmpty) {
      onUpdated(collector.snapshot());
      throw ModelSetupFailure(
        _unsupportedArtifactsMessage(artifacts, assessments),
      );
    }
    complete(ModelSetupStage.assessingArtifacts);

    onStarted(ModelSetupStage.checkingDeviceCompatibility);
    final checks = _compatibilityChecks(
      model: collector.model,
      device: device,
      runtime: runtime,
      constraints: constraints,
      supportedWeights: supportedWeights,
    );
    collector.compatibilityChecks = checks;
    onUpdated(collector.snapshot());
    final failed = checks
        .where((check) => !check.passed)
        .toList(growable: false);
    if (failed.isNotEmpty) {
      throw ModelSetupFailure(failed.map((check) => check.detail).join(' '));
    }
    complete(ModelSetupStage.checkingDeviceCompatibility);

    onStarted(ModelSetupStage.finalizingArtifacts);
    collector.selection = _finalize(artifacts, supportedWeights);
    onUpdated(collector.snapshot());
    final selection = collector.selection;
    if (selection == null || selection.weightFiles.isEmpty) {
      throw const ModelSetupFailure('No model weights could be finalized.');
    }
    complete(ModelSetupStage.finalizingArtifacts);

    onStarted(ModelSetupStage.done);
    complete(ModelSetupStage.done);
  }

  RuntimeConstraints _checkRuntime(RuntimeStatus runtime) {
    final path = runtime.documentsPath.trim();
    var storageWritable = false;
    String? storageError;
    if (path.isEmpty) {
      storageError = 'The runtime reported no application documents path.';
    } else {
      final probeFile = File('$path/.kritha_model_setup_probe');
      try {
        probeFile.writeAsStringSync('ok', flush: true);
        storageWritable = probeFile.readAsStringSync() == 'ok';
        if (!storageWritable) {
          storageError = 'The application documents directory is not writable.';
        }
      } on FileSystemException catch (error) {
        storageError = error.toString();
      } finally {
        try {
          if (probeFile.existsSync()) probeFile.deleteSync();
        } on FileSystemException {
          // The probe is best-effort; a failed cleanup is not a setup failure.
        }
      }
    }
    return RuntimeConstraints(
      runtimeId: localRuntimeId,
      runtimeAvailable: runtime.liteRtLmReady,
      storageWritable: storageWritable,
      storagePath: path,
      storageError: storageError,
      sherpaVersion: runtime.sherpaVersion,
      onnxRuntimeVersion: runtime.onnxRuntimeVersion,
    );
  }

  List<CompatibilityCheck> _compatibilityChecks({
    required ModelSetupModelInfo model,
    required DeviceStatus device,
    required RuntimeStatus runtime,
    required RuntimeConstraints constraints,
    required List<ArtifactAssessment> supportedWeights,
  }) {
    final weightNames = supportedWeights
        .map((assessment) => assessment.artifact.path)
        .join(', ');
    final formatMatchesLibrary = model.formatMatchesLibrary;
    return [
      CompatibilityCheck(
        label: 'Platform',
        passed: device.isSupported,
        detail: device.isSupported
            ? '${device.platformLabel} ${device.architecture}'
            : '${device.platformLabel} is not supported by this build.',
      ),
      CompatibilityCheck(
        label: 'Runtime',
        passed: runtime.liteRtLmReady,
        detail: runtime.liteRtLmReady
            ? 'LiteRT-LM runtime available.'
            : 'The LiteRT-LM runtime did not load.',
      ),
      CompatibilityCheck(
        label: 'Model format',
        passed: supportedWeights.isNotEmpty && formatMatchesLibrary,
        detail: !formatMatchesLibrary
            ? 'Declared format ${model.formats.join(', ')} does not match library ${model.libraryName}.'
            : supportedWeights.isNotEmpty
            ? 'Supported weights: $weightNames'
            : 'No supported weights were found.',
      ),
      CompatibilityCheck(
        label: 'Storage',
        passed: constraints.storageWritable,
        detail: constraints.storageWritable
            ? 'Application storage is writable.'
            : constraints.storageError ?? 'Application storage is unavailable.',
      ),
    ];
  }

  ModelSetupSelection _finalize(
    List<SetupArtifact> artifacts,
    List<ArtifactAssessment> supportedWeights,
  ) {
    List<ModelFile> filesFor(ModelArtifactKind kind) => List.unmodifiable(
      artifacts
          .where((artifact) => artifact.kind == kind)
          .map((artifact) => artifact.file),
    );

    return ModelSetupSelection(
      runtimeId: localRuntimeId,
      configurationFiles: filesFor(ModelArtifactKind.configuration),
      helperFiles: filesFor(ModelArtifactKind.helper),
      weightFiles: List.unmodifiable(
        supportedWeights.map((assessment) => assessment.artifact.file),
      ),
    );
  }

  static String _unsupportedArtifactsMessage(
    List<SetupArtifact> artifacts,
    List<ArtifactAssessment> assessments,
  ) {
    final weights = artifacts.where(
      (artifact) => artifact.kind == ModelArtifactKind.weights,
    );
    if (weights.isEmpty) {
      return 'No model weights were found in this repository.';
    }
    final found = assessments
        .where(
          (assessment) => assessment.artifact.kind == ModelArtifactKind.weights,
        )
        .map((assessment) => assessment.artifact.path)
        .join(', ');
    return 'No supported model weights were found. LiteRT-LM reads .litertlm files; found $found.';
  }
}

List<SetupArtifact> mapArtifacts(List<ModelFile> files) {
  final artifacts = <SetupArtifact>[];
  for (final file in files) {
    if (file.isDirectory || file.path.trim().isEmpty) continue;
    final kind = classifyArtifact(file.path);
    if (kind == null) continue;
    artifacts.add(SetupArtifact(file: file, kind: kind));
  }
  return List.unmodifiable(artifacts);
}

ModelArtifactKind? classifyArtifact(String path) {
  final lower = path.toLowerCase();
  final name = lower.split('/').last;
  if (name.startsWith('.') || name == 'readme.md' || name == 'license') {
    return null;
  }
  if (_configurationNames.contains(name) ||
      lower.endsWith('.jinja') ||
      lower.endsWith('.yaml') ||
      lower.endsWith('.yml')) {
    return ModelArtifactKind.configuration;
  }
  if (_weightExtensions.any(lower.endsWith)) {
    return ModelArtifactKind.weights;
  }
  if (_helperNames.contains(name) ||
      const ['.spm', '.tiktoken', '.tmpl', '.txt', '.py'].any(lower.endsWith)) {
    return ModelArtifactKind.helper;
  }
  if (lower.endsWith('.json')) return ModelArtifactKind.helper;
  return null;
}

List<ArtifactAssessment> assessArtifacts(List<SetupArtifact> artifacts) {
  return List.unmodifiable(
    artifacts.map((artifact) {
      return switch (artifact.kind) {
        ModelArtifactKind.configuration => ArtifactAssessment(
          artifact: artifact,
          supported: true,
          message: 'Configuration file detected.',
        ),
        ModelArtifactKind.helper => ArtifactAssessment(
          artifact: artifact,
          supported: true,
          message: 'Helper file detected.',
        ),
        ModelArtifactKind.weights => _assessWeights(artifact),
      };
    }),
  );
}

ArtifactAssessment _assessWeights(SetupArtifact artifact) {
  final lower = artifact.path.toLowerCase();
  if (lower.endsWith('.litertlm')) {
    return ArtifactAssessment(
      artifact: artifact,
      supported: true,
      message: 'LiteRT-LM weights detected.',
    );
  }
  final format = _weightFormat(lower);
  return ArtifactAssessment(
    artifact: artifact,
    supported: false,
    message: '$format weights are not executable by the installed runtime.',
  );
}

String _weightFormat(String path) {
  const labels = {
    '.gguf': 'GGUF',
    '.safetensors': 'Safetensors',
    '.onnx': 'ONNX',
    '.bin': 'Binary',
    '.pt': 'PyTorch',
    '.pth': 'PyTorch',
    '.ckpt': 'Checkpoint',
    '.h5': 'Keras',
    '.tflite': 'TensorFlow Lite',
    '.mlmodel': 'Core ML',
    '.mlpackage': 'Core ML',
  };
  for (final entry in labels.entries) {
    if (path.endsWith(entry.key)) return entry.value;
  }
  return 'Unknown';
}

const _configurationNames = {
  'config.json',
  'generation_config.json',
  'tokenizer_config.json',
  'special_tokens_map.json',
  'preprocessor_config.json',
  'processor_config.json',
  'adapter_config.json',
  'model_index.json',
  'quantize_config.json',
  'chat_template.json',
  'config.yaml',
  'config.yml',
};

const _helperNames = {
  'tokenizer.json',
  'tokenizer.model',
  'vocab.json',
  'merges.txt',
  'added_tokens.json',
  'tokenizer.txt',
};

const _weightExtensions = [
  '.litertlm',
  '.gguf',
  '.safetensors',
  '.onnx',
  '.bin',
  '.pt',
  '.pth',
  '.ckpt',
  '.h5',
  '.tflite',
  '.mlmodel',
  '.mlpackage',
];

final modelSetupAssessorProvider = Provider<ModelSetupAssessor>((ref) {
  return ModelSetupAssessor(
    runtimeStatus: ref.watch(runtimeStatusProvider.future),
  );
});
