import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme.dart';
import '../../../../models/chat_attachment.dart';
import '../../../../widgets/context_menu.dart';
import 'attachment_picker.dart';
import 'composer_controller.dart';

/// Opens the attachment actions in the shared context menu. Camera, Plugins and
/// Think harder are visible to match the reference menu but disabled because
/// those integrations do not exist in this build.
Future<void> showAttachmentMenu(
  BuildContext anchorContext,
  WidgetRef ref,
) async {
  final selected = await showKrithaContextMenu(
    context: anchorContext,
    anchor: ContextMenuAnchor.fromContext(anchorContext),
    items: [
      ContextMenuItem(
        id: 'camera',
        label: 'Camera',
        icon: HugeIcons.strokeRoundedCamera01,
        disabled: true,
      ),
      ContextMenuItem(
        id: 'photos',
        label: 'Photos',
        icon: HugeIcons.strokeRoundedImage01,
      ),
      ContextMenuItem(
        id: 'files',
        label: 'Files',
        icon: HugeIcons.strokeRoundedAttachment,
      ),
      ContextMenuItem(
        id: 'plugins',
        label: 'Plugins',
        icon: HugeIcons.strokeRoundedPlug02,
        disabled: true,
      ),
      ContextMenuItem(
        id: 'think',
        label: 'Think harder',
        icon: HugeIcons.strokeRoundedBrainCircuit,
        disabled: true,
      ),
    ],
  );
  if (selected == null || !anchorContext.mounted) return;

  switch (selected) {
    case 'photos':
      await _pick(
        anchorContext,
        ref,
        picker: ref.read(attachmentPickerProvider).pickImages,
        failureLabel: 'images',
      );
    case 'files':
      await _pick(
        anchorContext,
        ref,
        picker: ref.read(attachmentPickerProvider).pickFiles,
        failureLabel: 'files',
      );
  }
}

Future<void> _pick(
  BuildContext context,
  WidgetRef ref, {
  required Future<List<ChatAttachment>> Function() picker,
  required String failureLabel,
}) async {
  try {
    final result = await picker();
    if (!context.mounted || result.isEmpty) return;
    ref.read(composerProvider.notifier).addAttachments(result);
  } on Object catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not add $failureLabel: $error')),
    );
  }
}

class PlusButton extends StatelessWidget {
  const PlusButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: KrithaDimensions.actionButtonSize,
      height: KrithaDimensions.actionButtonSize,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        tooltip: 'Add attachments',
        icon: KrithaIcon(
          icon: HugeIcons.strokeRoundedPlus,
          size: KrithaIcons.lg,
          color: KrithaColors.textSecondary,
        ),
      ),
    );
  }
}

class VoiceModeButton extends StatelessWidget {
  const VoiceModeButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: KrithaDimensions.actionButtonSize,
      height: KrithaDimensions.actionButtonSize,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        tooltip: 'Start dictation',
        icon: KrithaIcon(
          icon: HugeIcons.strokeRoundedMic01,
          size: KrithaIcons.lg,
          color: KrithaColors.textPrimary,
        ),
      ),
    );
  }
}

/// Primary action: send when there is content, otherwise start Live Talk,
/// and a stop glyph while a reply is in flight.
class ComposerActionButton extends StatelessWidget {
  const ComposerActionButton({
    super.key,
    required this.isBusy,
    required this.hasContent,
    required this.compact,
    required this.onTap,
  });

  final bool isBusy;
  final bool hasContent;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final List<List<dynamic>> icon;
    final double iconSize;
    final String tooltip;

    if (isBusy) {
      icon = HugeIcons.strokeRoundedSquare;
      iconSize = 16;
      tooltip = 'Stop response';
    } else if (hasContent) {
      icon = HugeIcons.strokeRoundedArrowUp02;
      iconSize = compact ? KrithaIcons.md : KrithaIcons.sm;
      tooltip = 'Send message';
    } else {
      icon = HugeIcons.strokeRoundedAudioLines;
      iconSize = compact ? KrithaIcons.lg : KrithaIcons.md;
      tooltip = 'Live Talk';
    }

    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: KrithaMotion.fast,
        width: KrithaDimensions.actionButtonSize,
        height: KrithaDimensions.actionButtonSize,
        decoration: BoxDecoration(
          color: KrithaColors.accentBlue,
          borderRadius: BorderRadius.circular(KrithaRadius.lg),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(KrithaRadius.lg),
            child: KrithaIcon(
              icon: icon,
              size: iconSize,
              color: KrithaColors.textOnAccent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Round 48px control used by the Live Talk capsule row.
class LiveTalkCircleButton extends StatelessWidget {
  const LiveTalkCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.iconColor,
    this.size = KrithaDimensions.liveTalkCircleSize,
  });

  final List<List<dynamic>> icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: KrithaColors.bgTertiary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KrithaRadius.xl),
          side: BorderSide(color: KrithaColors.borderSubtle),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KrithaRadius.xl),
          child: SizedBox(
            width: size,
            height: size,
            child: KrithaIcon(
              icon: icon,
              size: KrithaIcons.lg,
              color: iconColor ?? KrithaColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
