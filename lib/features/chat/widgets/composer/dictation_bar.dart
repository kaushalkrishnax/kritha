import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme.dart';
import '../../../../widgets/glass_surface.dart';
import '../../chat_controller.dart';
import '../../dictation_controller.dart';
import '../composer/composer_controller.dart';
import 'recording_waveform.dart';

/// Kritha's dictation strip.
///
/// The controls and flow are ported from the React Native `TextComposer`
/// dictation row: cancel (X), the live waveform, stop-and-transcribe (square)
/// and stop-transcribe-and-send (arrow). The waveform itself is the Flexiyo
/// pattern requested for this build.
///
/// No offline STT model is bundled, so [DictationNotifier.transcribe] raises a
/// clear error after stopping the take. The recording is never attached to the
/// message as a file.
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
          padding: const EdgeInsets.symmetric(
            horizontal: KrithaSpacing.s8,
            vertical: KrithaSpacing.s6,
          ),
          border: Border.all(color: KrithaColors.borderSubtle),
          child: SizedBox(
            height: KrithaDimensions.actionButtonSize + 4,
            child: Row(
              children: [
                _DictationControl(
                  icon: LucideIcons.x,
                  tooltip: 'Cancel dictation',
                  iconColor: KrithaColors.textSecondary,
                  iconSize: KrithaIcons.lg,
                  onTap: cancel,
                ),
                const SizedBox(width: KrithaSpacing.s8),
                Expanded(
                  child: transcribing
                      ? const Row(
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
                const SizedBox(width: KrithaSpacing.s8),
                _DictationControl(
                  icon: LucideIcons.square,
                  tooltip: 'Stop and transcribe',
                  iconColor: KrithaColors.iconSlate,
                  iconSize: KrithaIcons.base,
                  background: KrithaColors.bgTertiary,
                  onTap: transcribing ? null : () => transcribe(send: false),
                ),
                const SizedBox(width: KrithaSpacing.s6),
                _DictationControl(
                  icon: LucideIcons.arrowUp,
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

  final IconData icon;
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
            child: Icon(
              icon,
              size: iconSize,
              color: enabled ? iconColor : iconColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
