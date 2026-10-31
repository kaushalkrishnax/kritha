import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../widgets/create_popup.dart';
import '../catalogue/catalogue_model.dart';
import 'configured_model_store.dart';
import 'model_artifact_storage.dart';
import 'model_setup_assessor.dart';
import 'model_setup_controller.dart';
import 'steps/model_setup_pre_checks_step.dart';
import 'steps/model_setup_selected_artifacts_step.dart';
import 'steps/model_setup_testing_step.dart';

Future<void> showModelSetupWizard(
  BuildContext context, {
  required ModelDetails details,
}) {
  return createPopup<void>(
    context: context,
    maxWidth: 900,
    builder: (_) => ModelSetupWizard(details: details),
  );
}

class ModelSetupWizard extends ConsumerStatefulWidget {
  const ModelSetupWizard({
    super.key,
    required this.details,
    this.configurationId,
  });

  final ModelDetails details;

  /// Stable identity for the configuration being edited. Omitted when the
  /// wizard creates a new configuration.
  final String? configurationId;

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
      store: ref.read(configuredModelStoreProvider),
      configurationId: widget.configurationId,
    );
    // The first frame renders the neutral pending checklist; the real checks
    // start immediately afterwards instead of completing during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller.runAssessment());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    watchKrithaPalette(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CreatePopup(
          title: 'Model Setup Wizard',
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

class _WizardFooter extends StatelessWidget {
  const _WizardFooter({required this.controller});

  final ModelSetupWizardController controller;

  @override
  Widget build(BuildContext context) {
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
                  ? () => unawaited(_test())
                  : null,
            ),
            SizedBox(width: KrithaSpacing.s8),
            PopupPrimaryButton(
              label: 'Save',
              onPressed: controller.canSaveConfiguration
                  ? () => unawaited(_save(context))
                  : null,
            ),
          ],
          _ => const <Widget>[],
        },
      ],
    );
  }

  Future<void> _test() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!await controller.saveConfiguration()) return;
    controller.nextStep();
  }

  Future<void> _save(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final saved = await controller.saveConfiguration();
    if (!context.mounted || !saved) return;
    Navigator.of(context).pop();
  }
}
