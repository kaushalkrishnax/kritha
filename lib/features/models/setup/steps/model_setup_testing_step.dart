import 'package:material_ui/material_ui.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme.dart';
import '../model_setup_controller.dart';

/// Step 3 entry point. The shared controller already holds the assessment for
/// the testing flow that will replace this placeholder.
class ModelSetupTestingStep extends StatelessWidget {
  const ModelSetupTestingStep({super.key, required this.controller});

  final ModelSetupWizardController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(KrithaSpacing.s20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KrithaIcon(
            icon: HugeIcons.strokeRoundedTestTube01,
            size: KrithaIcons.xl,
            color: KrithaColors.textMuted,
          ),
          SizedBox(height: KrithaSpacing.s12),
          Text(
            'Model testing is not available in this phase.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: KrithaText.sizeSm,
              color: KrithaColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
