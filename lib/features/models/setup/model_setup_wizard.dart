import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../models/model_record.dart';
import '../../../widgets/create_popup.dart';
import '../catalogue/catalogue_model.dart';
import '../active/active_models.dart';
import 'action_preferences.dart';
import '../model_record_store.dart';
import 'notifying_artifact_downloader.dart';
import 'model_setup_assessor.dart';
import 'model_setup_controller.dart';
import 'steps/model_setup_pre_checks_step.dart';
import 'steps/model_setup_selected_artifacts_step.dart';
import 'steps/model_setup_testing_step.dart';

Future<void> showModelSetupWizard(
  BuildContext context, {
  required ModelDetails details,
  ModelRecord? managedModel,
}) {
  return createPopup<void>(
    context: context,
    maxWidth: 900,
    builder: (_) =>
        ModelSetupWizard(details: details, managedModel: managedModel),
  );
}

class ModelSetupWizard extends ConsumerStatefulWidget {
  const ModelSetupWizard({
    super.key,
    required this.details,
    this.configurationId,
    this.managedModel,
  });

  final ModelDetails details;

  /// Stable identity for configuration being edited; null when creating.
  final String? configurationId;

  /// Existing local model edited through Manage Setup; null when creating.
  final ModelRecord? managedModel;

  @override
  ConsumerState<ModelSetupWizard> createState() => _ModelSetupWizardState();
}

class _ModelSetupWizardState extends ConsumerState<ModelSetupWizard> {
  late final ModelSetupWizardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ModelSetupWizardController(
      details: widget.details,
      assessor: ref.read(modelSetupAssessorProvider),
      downloader: ref.read(modelArtifactDownloaderProvider),
      store: ref.read(modelRepositoryProvider),
      actionPreferences: ref.read(actionPreferenceStoreProvider),
      configurationId: widget.configurationId,
      managedModel: widget.managedModel,
    );
    // Render neutral checklist on first frame before initiating pre-checks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller.runAssessment());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _title => switch (_controller.stepIndex) {
    1 => 'Manage Artifacts',
    _ => 'Model Setup Wizard',
  };

  String? get _subtitle => switch (_controller.stepIndex) {
    0 => 'Checking the device, runtime and artifacts required for this model.',
    1 => 'Review, select and download the files required for this model.',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    watchKrithaPalette(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CreatePopup(
          title: _title,
          subtitle: _subtitle,
          footer: _WizardFooter(controller: _controller),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: AnimatedSwitcher(
                  duration: KrithaMotion.fast,
                  child: switch (_controller.stepIndex) {
                    0 => ModelSetupPreChecksStep(
                      key: const ValueKey('model-setup-pre-checks'),
                      controller: _controller,
                    ),
                    1 => ModelSetupSelectedArtifactsStep(
                      key: const ValueKey('model-setup-selected-artifacts'),
                      controller: _controller,
                    ),
                    _ => ModelSetupTestingStep(
                      key: const ValueKey('model-setup-testing'),
                      controller: _controller,
                    ),
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WizardFooter extends ConsumerWidget {
  const _WizardFooter({required this.controller});

  final ModelSetupWizardController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = controller.stepIndex;
    final leading = step == 0
        ? PopupSecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          )
        : PopupSecondaryButton(
            label: 'Back',
            onPressed: controller.previousStep,
          );
    return Row(
      children: [
        leading,
        const Spacer(),
        ...switch (step) {
          0 => [
            PopupPrimaryButton(
              label: 'Next',
              onPressed: controller.canContinue ? controller.nextStep : null,
            ),
          ],
          1 => [
            PopupSecondaryButton(
              label: 'Test',
              onPressed: controller.canTestArtifacts
                  ? () => unawaited(_test(ref))
                  : null,
            ),
            SizedBox(width: KrithaSpacing.s8),
            PopupPrimaryButton(
              label: 'Save',
              onPressed: controller.canSaveConfiguration
                  ? () => unawaited(_save(context, ref))
                  : null,
            ),
          ],
          _ => const <Widget>[],
        },
      ],
    );
  }

  Future<void> _test(WidgetRef ref) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!await controller.saveConfiguration()) return;
    ref.invalidate(activeModelsProvider);
    controller.nextStep();
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final saved = await controller.saveConfiguration();
    if (!context.mounted || !saved) return;
    ref.invalidate(activeModelsProvider);
    Navigator.of(context).pop();
  }
}
