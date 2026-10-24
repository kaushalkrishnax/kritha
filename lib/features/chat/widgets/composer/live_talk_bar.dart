import 'package:material_ui/material_ui.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme.dart';
import 'composer_controller.dart';
import 'composer_controls.dart';
import 'live_talk_pill.dart';

/// The dedicated Live Talk capsule. This is a faithful port of the React
/// Native `LiveTalkBar`: two round utility controls, the glowing centre pill,
/// the pause/resume microphone and the close control.
///
/// The native Live Talk runtime is not bundled in this Flutter foundation, so
/// the bar exposes the real state machine and transitions without starting a
/// microphone session. [LiveTalkPill] renders the listening animation while
/// that runtime is absent.
class LiveTalkBar extends StatelessWidget {
  const LiveTalkBar({
    super.key,
    required this.phase,
    required this.onTogglePause,
    required this.onStop,
  });

  final LiveTalkPhase phase;
  final VoidCallback onTogglePause;
  final VoidCallback onStop;

  void _unavailable(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is not available in this build.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isListening = phase.isListening;
    final paused = phase.isPaused;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom > 0
        ? 0.0
        : MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        KrithaSpacing.s16,
        KrithaSpacing.s6,
        KrithaSpacing.s16,
        KrithaSpacing.s12 + bottomInset,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tight = constraints.maxWidth < 340;
          final circleSize = tight ? 42.0 : KrithaDimensions.liveTalkCircleSize;
          final gap = tight ? KrithaSpacing.s6 : KrithaSpacing.s8;
          return Semantics(
            label: 'Live Talk ${phase.name}',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                LiveTalkCircleButton(
                  icon: HugeIcons.strokeRoundedVideo01,
                  size: circleSize,
                  tooltip: 'Video',
                  onTap: () => _unavailable(context, 'Video'),
                ),
                SizedBox(width: gap),
                LiveTalkCircleButton(
                  icon: HugeIcons.strokeRoundedScreenShare,
                  size: circleSize,
                  tooltip: 'Share screen',
                  onTap: () => _unavailable(context, 'Screen sharing'),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: Center(
                    child: LiveTalkPill(
                      active: phase.isListening || phase.isSpeaking,
                    ),
                  ),
                ),
                SizedBox(width: gap),
                LiveTalkCircleButton(
                  icon: isListening
                      ? HugeIcons.strokeRoundedMic01
                      : HugeIcons.strokeRoundedMicOff01,
                  iconColor: isListening
                      ? KrithaColors.textPrimary
                      : KrithaColors.textMuted,
                  tooltip: paused ? 'Resume Live Talk' : 'Pause Live Talk',
                  size: circleSize,
                  onTap: onTogglePause,
                ),
                SizedBox(width: gap),
                LiveTalkCircleButton(
                  icon: HugeIcons.strokeRoundedX,
                  tooltip: 'End Live Talk',
                  size: circleSize,
                  onTap: onStop,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
