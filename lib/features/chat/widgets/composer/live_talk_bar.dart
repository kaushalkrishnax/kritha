import 'package:material_ui/material_ui.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme.dart';
import 'composer_controller.dart';
import 'composer_controls.dart';
import 'live_talk_pill.dart';

/// Dedicated Live Talk capsule with glowing pill, mic and close controls.
class LiveTalkBar extends StatelessWidget {
  const LiveTalkBar({
    super.key,
    required this.phase,
    this.audioLevel = 0.0,
    required this.onTogglePause,
    required this.onStop,
  });

  final LiveTalkPhase phase;
  final double audioLevel;
  final VoidCallback onTogglePause;
  final VoidCallback onStop;

  void _unavailable(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is not available in this build.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paused = phase.isPaused;
    final ttsPlaying = phase == LiveTalkPhase.speaking;
    final micActive = !paused && !ttsPlaying;
    final interrupting =
        phase == LiveTalkPhase.speaking ||
        phase == LiveTalkPhase.thinking ||
        phase == LiveTalkPhase.processing;
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
                      audioLevel: audioLevel,
                    ),
                  ),
                ),
                SizedBox(width: gap),
                LiveTalkCircleButton(
                  icon: micActive
                      ? HugeIcons.strokeRoundedMic01
                      : HugeIcons.strokeRoundedMicOff01,
                  iconColor: micActive
                      ? KrithaColors.textPrimary
                      : KrithaColors.textMuted,
                  tooltip: paused
                      ? 'Resume Live Talk'
                      : interrupting
                      ? 'Interrupt and listen'
                      : 'Pause Live Talk',
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
