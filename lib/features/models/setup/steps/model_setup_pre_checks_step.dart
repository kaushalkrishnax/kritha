import 'package:material_ui/material_ui.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme.dart';
import '../model_setup_controller.dart';

class ModelSetupPreChecksStep extends StatelessWidget {
  const ModelSetupPreChecksStep({super.key, required this.controller});

  final ModelSetupWizardController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        KrithaSpacing.s20,
        KrithaSpacing.s4,
        KrithaSpacing.s20,
        KrithaSpacing.s20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < controller.stages.length; index++)
                  _StageRow(progress: controller.stages[index]),
              ],
            ),
          ),
          if (controller.succeeded) ...[
            SizedBox(height: KrithaSpacing.s12),
            const _CompletionNotice(),
          ],
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.progress});

  final ModelSetupStageProgress progress;

  @override
  Widget build(BuildContext context) {
    final error = progress.error;
    final running = progress.state == ModelSetupStageState.running;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(child: _StageIndicator(state: progress.state)),
          ),
          SizedBox(width: KrithaSpacing.s12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    progress.stage.label,
                    style: TextStyle(
                      fontSize: KrithaText.sizeSm,
                      fontWeight: running ? FontWeight.w600 : FontWeight.w500,
                      color: _labelColor(progress.state),
                    ),
                  ),
                  if (running) ...[
                    SizedBox(height: KrithaSpacing.s2),
                    Text(
                      progress.stage.activity,
                      style: TextStyle(
                        fontSize: KrithaText.size2xs,
                        color: KrithaColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    SizedBox(height: KrithaSpacing.s4),
                    Text(
                      error,
                      style: TextStyle(
                        fontSize: KrithaText.sizeXs,
                        color: KrithaColors.error,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _labelColor(ModelSetupStageState state) => switch (state) {
    ModelSetupStageState.pending => KrithaColors.textMuted,
    ModelSetupStageState.running => KrithaColors.textPrimary,
    ModelSetupStageState.completed => KrithaColors.textSecondary,
    ModelSetupStageState.failed => KrithaColors.error,
  };
}

class _StageIndicator extends StatelessWidget {
  const _StageIndicator({required this.state});

  final ModelSetupStageState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ModelSetupStageState.completed => Semantics(
        label: 'Completed',
        child: KrithaIcon(
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
          size: 20,
          color: KrithaColors.success,
        ),
      ),
      ModelSetupStageState.running => Semantics(
        label: 'In progress',
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: KrithaColors.warning,
          ),
        ),
      ),
      ModelSetupStageState.failed => Semantics(
        label: 'Failed',
        child: KrithaIcon(
          icon: HugeIcons.strokeRoundedAlert02,
          size: 20,
          color: KrithaColors.error,
        ),
      ),
      ModelSetupStageState.pending => Semantics(
        label: 'Pending',
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: KrithaColors.borderStrong, width: 1.5),
          ),
        ),
      ),
    };
  }
}

class _CompletionNotice extends StatelessWidget {
  const _CompletionNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(KrithaSpacing.s12),
      decoration: BoxDecoration(
        color: KrithaColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(KrithaRadius.base),
        border: Border.all(color: KrithaColors.success.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KrithaIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            size: KrithaIcons.sm,
            color: KrithaColors.success,
          ),
          SizedBox(width: KrithaSpacing.s8),
          Expanded(
            child: Text(
              'All checks complete. You can proceed now.',
              style: TextStyle(
                fontSize: KrithaText.sizeSm,
                fontWeight: FontWeight.w500,
                color: KrithaColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
