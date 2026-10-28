import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/responsive.dart';
import '../../../core/theme.dart';
import '../../../models/chat_message.dart';
import '../../../widgets/context_menu.dart';
import '../chat_controller.dart';
import 'attachment_view.dart';
import 'composer/composer_controller.dart';
import 'markdown_view.dart';
import 'response_actions.dart';

class MessageList extends StatelessWidget {
  const MessageList({
    super.key,
    required this.messages,
    required this.sending,
    required this.streamingText,
    required this.failure,
    required this.onRetry,
    required this.scrollController,
    this.topPadding = 0,
    this.bottomPadding = KrithaSpacing.s16,
  });

  final List<ChatMessage> messages;
  final bool sending;

  /// Partial assistant text for the in-flight reply, if any.
  final String? streamingText;

  /// Failure for the last reply, when one was not produced.
  final ChatFailure? failure;

  final VoidCallback onRetry;
  final ScrollController scrollController;

  /// Space reserved for the floating header so the first turn can scroll clear
  /// of the top fade.
  final double topPadding;

  /// Space reserved for the floating composer so the last turn can scroll clear
  /// of it.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = viewportOf(MediaQuery.sizeOf(context).width);
        final contentWidth = viewport.usesCenteredColumn
            ? math.min(constraints.maxWidth, KrithaDimensions.maxContentWidth)
            : constraints.maxWidth;
        final bubbleMaxWidth = math.min(
          (contentWidth - KrithaSpacing.screenPadding * 2) * 0.80,
          560.0,
        );

        return ListView.builder(
          controller: scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            KrithaSpacing.screenPadding,
            topPadding,
            KrithaSpacing.screenPadding,
            bottomPadding,
          ),
          itemCount:
              messages.length +
              (sending ? 1 : 0) +
              (failure != null && !sending ? 1 : 0),
          itemBuilder: (context, index) {
            final Widget item;
            if (index < messages.length) {
              final message = messages[index];
              item = switch (message.role) {
                ChatRole.user => _UserMessage(
                  message: message,
                  maxWidth: bubbleMaxWidth,
                ),
                ChatRole.assistant => _AssistantMessage(message: message),
              };
            } else if (sending) {
              final partial = streamingText;
              item = partial == null || partial.isEmpty
                  ? _ThinkingRow()
                  : _StreamingMessage(text: partial);
            } else {
              item = _ReplyFailureRow(failure: failure!, onRetry: onRetry);
            }

            final padded = Padding(
              padding: EdgeInsets.only(bottom: KrithaSpacing.messageGap),
              child: item,
            );
            if (!viewport.usesCenteredColumn) return padded;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: KrithaDimensions.maxContentWidth,
                ),
                child: padded,
              ),
            );
          },
        );
      },
    );
  }
}

class _UserMessage extends ConsumerWidget {
  const _UserMessage({required this.message, required this.maxWidth});

  final ChatMessage message;
  final double maxWidth;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message.text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Message copied')));
  }

  Future<void> _openMenu(BuildContext bubbleContext, WidgetRef ref) async {
    final selected = await showKrithaContextMenu(
      context: bubbleContext,
      anchor: ContextMenuAnchor.fromContext(bubbleContext),
      align: ContextMenuAlign.right,
      header: Text(
        _formatMessageTime(message.createdAt),
        style: TextStyle(
          color: KrithaColors.textMuted,
          fontSize: KrithaText.sizeBase,
        ),
      ),
      items: [
        ContextMenuItem(
          id: 'copy',
          label: 'Copy',
          icon: HugeIcons.strokeRoundedCopy01,
        ),
        ContextMenuItem(
          id: 'edit',
          label: 'Edit message',
          icon: HugeIcons.strokeRoundedEdit03,
        ),
      ],
    );
    if (!bubbleContext.mounted) return;
    switch (selected) {
      case 'copy':
        await _copy(bubbleContext);
      case 'edit':
        ref
            .read(composerProvider.notifier)
            .beginEditingMessage(message.id, message.text);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Builder(
          builder: (bubbleContext) => Material(
            key: ValueKey('message-${message.id}'),
            color: KrithaColors.userBubbleBg,
            borderRadius: BorderRadius.circular(KrithaRadius.xl),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onLongPress: () => _openMenu(bubbleContext, ref),
              onSecondaryTap: () => _openMenu(bubbleContext, ref),
              mouseCursor: SystemMouseCursors.click,
              splashColor: KrithaColors.contextMenuPressed,
              highlightColor: KrithaColors.contextMenuPressed,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: KrithaSpacing.s20,
                  vertical: KrithaSpacing.s12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.attachments.isNotEmpty)
                      MessageAttachmentList(attachments: message.attachments),
                    if (message.text.trim().isNotEmpty)
                      Text(message.text, style: KrithaText.message),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatMessageTime(DateTime timestamp) {
  final now = DateTime.now();
  final isToday =
      timestamp.year == now.year &&
      timestamp.month == now.month &&
      timestamp.day == now.day;
  final yesterday = now.subtract(Duration(days: 1));
  final isYesterday =
      timestamp.year == yesterday.year &&
      timestamp.month == yesterday.month &&
      timestamp.day == yesterday.day;

  final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
  final minute = timestamp.minute.toString().padLeft(2, '0');
  final period = timestamp.hour < 12 ? 'am' : 'pm';
  final time = '$hour:$minute $period';

  if (isToday) return 'Today, $time';
  if (isYesterday) return 'Yesterday, $time';

  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[timestamp.month - 1]} ${timestamp.day}, $time';
}

class _AssistantMessage extends StatelessWidget {
  const _AssistantMessage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: KrithaSpacing.s12,
        horizontal: KrithaSpacing.s2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MarkdownView(data: message.text),
          if (message.text.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: ResponseActions(
                text: message.text,
                onSpeak: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'TTS models are downloaded separately and are not '
                        'bundled in this build.',
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: KrithaSpacing.s6,
        horizontal: KrithaSpacing.s4,
      ),
      child: Row(
        children: [
          KrithaIcon(
            icon: HugeIcons.strokeRoundedBrain,
            size: KrithaIcons.sm,
            color: KrithaColors.accentLightBlue,
          ),
          SizedBox(width: KrithaSpacing.s8),
          Text(
            'Thinking…',
            style: TextStyle(
              fontSize: KrithaText.sizeBase,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: KrithaColors.accentLightBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamingMessage extends StatelessWidget {
  const _StreamingMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: KrithaSpacing.s12,
        horizontal: KrithaSpacing.s2,
      ),
      child: MarkdownView(data: text),
    );
  }
}

class _ReplyFailureRow extends StatelessWidget {
  const _ReplyFailureRow({required this.failure, required this.onRetry});

  final ChatFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('reply-failure'),
      padding: EdgeInsets.all(KrithaSpacing.s12),
      decoration: BoxDecoration(
        color: KrithaColors.bgSurface,
        borderRadius: BorderRadius.circular(KrithaRadius.md),
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KrithaIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: KrithaIcons.md,
            color: KrithaColors.error,
          ),
          SizedBox(width: KrithaSpacing.s10),
          Expanded(
            child: Text(
              failure.message,
              style: TextStyle(
                fontSize: KrithaText.sizeSm,
                height: 1.4,
                color: KrithaColors.textSecondary,
              ),
            ),
          ),
          if (failure.retryable) ...[
            SizedBox(width: KrithaSpacing.s8),
            TextButton(onPressed: onRetry, child: Text('Retry')),
          ],
        ],
      ),
    );
  }
}
