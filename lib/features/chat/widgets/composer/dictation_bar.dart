import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme.dart';
import '../../../../widgets/glass_surface.dart';
import '../../chat_controller.dart';
import '../../dictation_controller.dart';
import '../composer/composer_controller.dart';
import 'recording_waveform.dart';

/// In-composer audio dictation bar.
class DictationBar extends ConsumerWidget {
  const DictationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dictationProvider);
    final notifier = ref.read(dictationProvider.notifier);
    final transcribing = state.isTranscribing;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom > 0
        ? 0.0
        : MediaQuery.viewPaddingOf(context).bottom;

    Future<void> transcribe({required bool send}) async {
      try {
        final transcript = (await notifier.transcribe()).trim();
        if (transcript.isEmpty || !context.mounted) return;
        ref.read(composerProvider.notifier).setDraftText(transcript);
        if (send) {
          await ref.read(chatControllerProvider.notifier).send(transcript);
        }
      } on DictationException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }

    Future<void> cancel() async {
      try {
        await notifier.discard();
      } on DictationException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        KrithaSpacing.s12,
        KrithaSpacing.s6,
        KrithaSpacing.s12,
        KrithaSpacing.s12 + bottomInset,
      ),
      child: Semantics(
        label: transcribing ? 'Transcribing dictation' : 'Dictation listening',
        child: KrithaGlassSurface(
          borderRadius: KrithaRadius.xl,
          padding: EdgeInsets.symmetric(
            horizontal: KrithaSpacing.s8,
            vertical: KrithaSpacing.s6,
          ),
          border: Border.all(color: KrithaColors.borderSubtle),
          child: SizedBox(
            height: KrithaDimensions.actionButtonSize + 4,
            child: Row(
              children: [
                _DictationControl(
                  icon: HugeIcons.strokeRoundedX,
                  tooltip: 'Cancel dictation',
                  iconColor: KrithaColors.textSecondary,
                  iconSize: KrithaIcons.lg,
                  onTap: cancel,
                ),
                SizedBox(width: KrithaSpacing.s8),
                Expanded(
                  child: transcribing
                      ? Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: KrithaColors.accentLightBlue,
                              ),
                            ),
                            SizedBox(width: KrithaSpacing.s8),
                            Text(
                              'Transcribing...',
                              style: TextStyle(
                                color: KrithaColors.textMuted,
                                fontSize: KrithaText.sizeMd,
                              ),
                            ),
                          ],
                        )
                      : RecordingWaveform(levels: state.levels, paused: false),
                ),
                SizedBox(width: KrithaSpacing.s8),
                _DictationControl(
                  icon: HugeIcons.strokeRoundedSquare,
                  tooltip: 'Stop and transcribe',
                  iconColor: KrithaColors.iconSlate,
                  iconSize: KrithaIcons.base,
                  background: KrithaColors.bgTertiary,
                  onTap: transcribing ? null : () => transcribe(send: false),
                ),
                SizedBox(width: KrithaSpacing.s6),
                _DictationControl(
                  icon: HugeIcons.strokeRoundedArrowUp02,
                  tooltip: 'Send dictation',
                  iconColor: KrithaColors.textOnAccent,
                  iconSize: KrithaIcons.md,
                  background: KrithaColors.accentBlue,
                  onTap: transcribing ? null : () => transcribe(send: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DictationControl extends StatelessWidget {
  const _DictationControl({
    required this.icon,
    required this.tooltip,
    required this.iconColor,
    required this.iconSize,
    required this.onTap,
    this.background,
  });

  final List<List<dynamic>> icon;
  final String tooltip;
  final Color iconColor;
  final double iconSize;
  final VoidCallback? onTap;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background ?? Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KrithaRadius.lg),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KrithaRadius.lg),
          child: SizedBox(
            width: KrithaDimensions.actionButtonSize,
            height: KrithaDimensions.actionButtonSize,
            child: KrithaIcon(
              icon: icon,
              size: iconSize,
              color: enabled ? iconColor : iconColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
