import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';
import 'package:kritha/features/models/setup/model_setup_assessment.dart';
import 'package:kritha/features/models/setup/model_setup_assessor.dart';
import 'package:kritha/features/models/setup/model_setup_controller.dart';
import 'package:kritha/services/runtime_probe.dart';

void main() {
  late Directory tempDir;
  late RuntimeStatus runtime;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kritha-setup-');
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

  const litertModel = CatalogueModel(
    id: 'acme/litert',
    pipelineTag: 'text-generation',
    libraryName: 'litert-lm',
    tags: ['litertlm'],
    usedStorage: 4096,
  );

  const details = ModelDetails(
    model: litertModel,
    files: [
      ModelFile(path: 'model.litertlm', sizeBytes: 2048),
      ModelFile(path: 'config.json', sizeBytes: 128),
      ModelFile(path: 'tokenizer.model', sizeBytes: 512),
      ModelFile(path: 'README.md', sizeBytes: 100),
      ModelFile(path: 'nested', type: 'directory'),
    ],
    config: {
      'architectures': ['LlamaForCausalLM'],
    },
  );

  test('maps configuration, helper and weight artifacts only', () {
    final artifacts = mapArtifacts(details.files);

    expect(artifacts.map((artifact) => artifact.path), [
      'model.litertlm',
      'config.json',
      'tokenizer.model',
    ]);
    expect(artifacts.map((artifact) => artifact.kind), [
      ModelArtifactKind.weights,
      ModelArtifactKind.configuration,
      ModelArtifactKind.helper,
    ]);
  });

  test(
    'treats format and library identifiers case- and separator-insensitively',
    () {
      final info = ModelSetupModelInfo.fromDetails(details);

      expect(info.formats, contains('LiteRT-LM'));
      expect(info.libraryName, 'litert-lm');
      expect(info.formatMatchesLibrary, isTrue);
      expect(info.matchesFormat('LiteRT-LM'), isTrue);
      expect(info.matchesFormat('litert-lm'), isTrue);
      expect(info.matchesFormat('litertlm'), isTrue);
    },
  );

  test('accepts the litert-lm tag real Gemma repositories publish', () async {
    const gemma = CatalogueModel(
      id: 'litert-community/gemma-4-E2B-it-litert-lm',
      pipelineTag: 'text-generation',
      libraryName: 'litert-lm',
      tags: [
        'litert-lm',
        'base_model:google/gemma-4-E2B-it',
        'base_model:finetune:google/gemma-4-E2B-it',
        'license:apache-2.0',
        'region:us',
      ],
    );
    const source = ModelDetails(
      model: gemma,
      files: [ModelFile(path: 'gemma-4-E2B-it.litertlm', sizeBytes: 2048)],
    );
    final controller = ModelSetupWizardController(
      details: source,
      assessor: ModelSetupAssessor(runtimeStatus: Future.value(runtime)),
    );
    addTearDown(controller.dispose);

    await controller.runAssessment();

    expect(controller.succeeded, isTrue);
    final assessment = controller.assessment!;
    expect(assessment.model.formats, contains('LiteRT-LM'));
    expect(assessment.model.formatMatchesLibrary, isTrue);
    expect(assessment.model.matchesFormat('litertlm'), isTrue);
    expect(assessment.weightFiles.single.path, 'gemma-4-E2B-it.litertlm');
  });

  test('reports a format mismatch only for different identifiers', () {
    const mismatched = ModelDetails(
      model: CatalogueModel(
        id: 'acme/mismatch',
        libraryName: 'safetensors',
        tags: ['gguf'],
      ),
    );
    const unrelated = ModelDetails(
      model: CatalogueModel(
        id: 'acme/unrelated',
        libraryName: 'transformers',
        tags: ['gguf'],
      ),
    );

    expect(
      ModelSetupModelInfo.fromDetails(mismatched).formatMatchesLibrary,
      isFalse,
    );
    expect(
      ModelSetupModelInfo.fromDetails(unrelated).formatMatchesLibrary,
      isTrue,
    );
  });

  test(
    'runs every stage in the fixed order and preserves the assessment',
    () async {
      final started = <ModelSetupStage>[];
      final completed = <ModelSetupStage>[];
      final assessor = ModelSetupAssessor(runtimeStatus: Future.value(runtime));

      await assessor.run(
        details: details,
        onStarted: started.add,
        onCompleted: (stage, assessment) => completed.add(stage),
        onUpdated: (_) {},
      );

      expect(started, ModelSetupStage.values);
      expect(completed, ModelSetupStage.values);
    },
  );

  test(
    'controller exposes assessment data and unlocks Next after success',
    () async {
      final controller = ModelSetupWizardController(
        details: details,
        assessor: ModelSetupAssessor(runtimeStatus: Future.value(runtime)),
      );
      addTearDown(controller.dispose);

      expect(controller.canContinue, isFalse);
      await controller.runAssessment();

      expect(controller.succeeded, isTrue);
      expect(controller.canContinue, isTrue);
      expect(
        controller.stages.every(
          (stage) => stage.state == ModelSetupStageState.completed,
        ),
        isTrue,
      );

      final assessment = controller.assessment;
      expect(assessment, isNotNull);
      expect(assessment!.device, isNotNull);
      expect(assessment.runtime?.liteRtLmReady, isTrue);
      expect(assessment.runtimeConstraints?.storageWritable, isTrue);
      expect(assessment.configurationFiles.single.path, 'config.json');
      expect(assessment.helperFiles.single.path, 'tokenizer.model');
      expect(assessment.weightFiles.single.path, 'model.litertlm');
      expect(assessment.selection?.weightFiles.single.path, 'model.litertlm');
      expect(assessment.selection?.runtimeId, 'litertlm');

      controller.nextStep();
      expect(controller.stepIndex, 1);
      expect(controller.canContinue, isFalse);
      controller.previousStep();
      expect(controller.stepIndex, 0);
      expect(controller.canContinue, isTrue);
    },
  );

  test(
    'fails the runtime stage with the real reason and keeps Next locked',
    () async {
      final controller = ModelSetupWizardController(
        details: details,
        assessor: ModelSetupAssessor(
          runtimeStatus: Future.value(
            RuntimeStatus(
              liteRtLmReady: false,
              sherpaVersion: '',
              onnxRuntimeVersion: '',
              sqliteVersion: '3.51.0',
              secureStorageReady: false,
              preferencesReady: false,
              microphone: 'unavailable',
              recorderReady: false,
              audioPlayerReady: false,
              dioBaseUrl: '',
              documentsPath: tempDir.path,
            ),
          ),
        ),
      );
      addTearDown(controller.dispose);

      await controller.runAssessment();

      expect(controller.succeeded, isFalse);
      expect(controller.canContinue, isFalse);
      expect(
        controller
            .stages[ModelSetupStage.checkingRuntimeConstraints.index]
            .state,
        ModelSetupStageState.failed,
      );
      expect(
        controller
            .stages[ModelSetupStage.checkingRuntimeConstraints.index]
            .error,
        contains('LiteRT-LM native runtime'),
      );
      expect(
        controller.stages[ModelSetupStage.mappingArtifacts.index].state,
        ModelSetupStageState.pending,
      );
    },
  );

  test('rejects weights the installed runtime cannot execute', () async {
    const gguf = ModelDetails(
      model: litertModel,
      files: [ModelFile(path: 'model.gguf', sizeBytes: 2048)],
    );
    final controller = ModelSetupWizardController(
      details: gguf,
      assessor: ModelSetupAssessor(runtimeStatus: Future.value(runtime)),
    );
    addTearDown(controller.dispose);

    await controller.runAssessment();

    expect(controller.succeeded, isFalse);
    expect(
      controller.stages[ModelSetupStage.assessingArtifacts.index].state,
      ModelSetupStageState.failed,
    );
    expect(
      controller.stages[ModelSetupStage.assessingArtifacts.index].error,
      contains('No supported model weights'),
    );
    expect(
      controller
          .stages[ModelSetupStage.checkingDeviceCompatibility.index]
          .state,
      ModelSetupStageState.pending,
    );
  });

  test('leaves an honest error when the storage probe cannot write', () async {
    final missing = RuntimeStatus(
      liteRtLmReady: true,
      sherpaVersion: '',
      onnxRuntimeVersion: '',
      sqliteVersion: '3.51.0',
      secureStorageReady: false,
      preferencesReady: false,
      microphone: 'unavailable',
      recorderReady: false,
      audioPlayerReady: false,
      dioBaseUrl: '',
      documentsPath: '${tempDir.path}/missing-directory',
    );
    final controller = ModelSetupWizardController(
      details: details,
      assessor: ModelSetupAssessor(runtimeStatus: Future.value(missing)),
    );
    addTearDown(controller.dispose);

    await controller.runAssessment();

    expect(controller.succeeded, isFalse);
    expect(
      controller.stages[ModelSetupStage.checkingRuntimeConstraints.index].state,
      ModelSetupStageState.failed,
    );
    expect(
      controller.stages[ModelSetupStage.checkingRuntimeConstraints.index].error,
      isNotNull,
    );
  });
}
