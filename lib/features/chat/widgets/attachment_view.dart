import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme.dart';
import '../../../models/chat_attachment.dart';

/// Horizontal strip of pending attachments shown inside the expanded composer.
class ComposerAttachmentStrip extends StatelessWidget {
  const ComposerAttachmentStrip({
    super.key,
    required this.attachments,
    required this.onRemove,
  });

  final List<ChatAttachment> attachments;
  final ValueChanged<ChatAttachment> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: KrithaDimensions.attachmentPreviewHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: attachments.length,
        separatorBuilder: (_, _) => SizedBox(width: KrithaSpacing.s8),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return _AttachmentTile(
            key: ValueKey('attachment-preview-${attachment.id}'),
            attachment: attachment,
            onRemove: () => onRemove(attachment),
          );
        },
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({super.key, required this.attachment, this.onRemove});

  final ChatAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final tile = attachment.isImage
        ? _ImageTile(attachment: attachment)
        : _FileTile(attachment: attachment);

    final sized = SizedBox(
      width: attachment.isImage ? KrithaDimensions.attachmentImageSize : 210,
      child: tile,
    );

    if (onRemove == null) return sized;

    return SizedBox(
      width: attachment.isImage ? KrithaDimensions.attachmentImageSize : 210,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          sized,
          Positioned(
            top: -2,
            right: -2,
            child: Tooltip(
              message: 'Remove attachment',
              child: Material(
                // One step above the attachment tile (bgTertiary) so the X
                // reads as a solid control instead of a black cut-out.
                color: KrithaColors.bgQuaternary,
                shape: CircleBorder(),
                child: InkWell(
                  customBorder: CircleBorder(),
                  onTap: onRemove,
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: KrithaIcon(
                      icon: HugeIcons.strokeRoundedX,
                      size: 12,
                      color: KrithaColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.attachment});

  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final size = KrithaDimensions.attachmentImageSize;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: KrithaColors.bgTertiary,
        borderRadius: BorderRadius.circular(KrithaRadius.base),
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.file(
        File(attachment.path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Center(
          child: KrithaIcon(
            icon: HugeIcons.strokeRoundedAlbum01,
            size: KrithaIcons.md,
            color: KrithaColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.attachment});

  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: KrithaDimensions.attachmentImageSize,
      padding: EdgeInsets.symmetric(
        horizontal: KrithaSpacing.s10,
        vertical: KrithaSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: KrithaColors.bgTertiary,
        borderRadius: BorderRadius.circular(KrithaRadius.base),
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      child: Row(
        children: [
          KrithaIcon(
            icon: HugeIcons.strokeRoundedAttachment,
            size: KrithaIcons.md,
            color: KrithaColors.accentLightBlue,
          ),
          SizedBox(width: KrithaSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  attachment.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: KrithaText.sizeXs,
                    fontWeight: FontWeight.w600,
                    color: KrithaColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  attachment.readableSize,
                  style: TextStyle(
                    fontSize: KrithaText.size2xs,
                    color: KrithaColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Attachments rendered inside a sent user message.
class MessageAttachmentList extends StatelessWidget {
  const MessageAttachmentList({super.key, required this.attachments});

  final List<ChatAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: KrithaSpacing.s8),
      child: Wrap(
        spacing: KrithaSpacing.s8,
        runSpacing: KrithaSpacing.s8,
        children: [
          for (final attachment in attachments)
            _AttachmentTile(attachment: attachment),
        ],
      ),
    );
  }
}
