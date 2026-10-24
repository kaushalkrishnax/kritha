import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/responsive.dart';
import '../../../core/theme.dart';
import '../../../models/chat_session.dart';
import '../../../widgets/context_menu.dart';
import '../chat_controller.dart';

/// Shared sidebar body used both as an overlay drawer on compact/medium
/// viewports and as a docked panel on wide ones.
///
/// Sessions, pinning, renaming, archiving and deleting are backed by SQLite
/// through [ChatController]. Layout values follow the React Native
/// `ChatSidebar`: 24px gutters, a 30px logo, 56px top actions with no gaps
/// between them, 56px history rows and the account strip pinned to the bottom.
class ChatSidebar extends ConsumerStatefulWidget {
  const ChatSidebar({
    super.key,
    required this.onNewChat,
    required this.onSettings,
  });

  final VoidCallback onNewChat;
  final VoidCallback onSettings;

  static double drawerWidthFor(double screenWidth) {
    return math.min(
      screenWidth * KrithaDimensions.sidebarDrawerFraction,
      KrithaDimensions.sidebarDrawerMaxWidth,
    );
  }

  @override
  ConsumerState<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends ConsumerState<ChatSidebar> {
  ChatController get _controller => ref.read(chatControllerProvider.notifier);

  Future<void> _selectSession(ChatSession session, String? currentId) async {
    if (session.id == currentId) return;
    await _controller.selectSession(session.id);
  }

  Future<void> _openSessionMenu(
    BuildContext rowContext,
    Offset pressPosition,
    ChatSession session,
  ) async {
    final box = rowContext.findRenderObject() as RenderBox?;
    final boundaryWidth = box?.size.width;
    final selected = await showKrithaContextMenu(
      context: rowContext,
      anchor: ContextMenuAnchor(position: pressPosition, size: Size.zero),
      rightBoundary: boundaryWidth,
      items: [
        ContextMenuItem(
          id: 'pin',
          label: session.pinned ? 'Unpin' : 'Pin',
          icon: session.pinned
              ? HugeIcons.strokeRoundedPinOff
              : HugeIcons.strokeRoundedPin,
        ),
        const ContextMenuItem(
          id: 'rename',
          label: 'Rename',
          icon: HugeIcons.strokeRoundedPencil,
        ),
        const ContextMenuItem(
          id: 'archive',
          label: 'Archive',
          icon: HugeIcons.strokeRoundedArchive,
        ),
        const ContextMenuItem(
          id: 'delete',
          label: 'Delete',
          icon: HugeIcons.strokeRoundedTrash,
          destructive: true,
        ),
      ],
    );
    if (!mounted || selected == null) return;

    switch (selected) {
      case 'pin':
        await _controller.togglePinned(session.id);
      case 'rename':
        await _renameSession(session);
      case 'archive':
        await _controller.archiveSession(session.id);
      case 'delete':
        await _controller.deleteSession(session.id);
    }
  }

  Future<void> _renameSession(ChatSession session) async {
    final controller = TextEditingController(text: session.title);
    final next = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: KrithaColors.bgSurface,
        title: const Text('Rename chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          decoration: const InputDecoration(hintText: 'Chat title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    final title = next?.trim();
    if (!mounted || title == null || title.isEmpty) return;
    await _controller.renameSession(session.id, title);
  }

  Future<void> _openArchived() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _ArchivedSessionsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider).value;
    final sessions = chat?.sessions ?? const <ChatSession>[];
    final currentId = chat?.currentSessionId;
    final pinned = sessions.where((session) => session.pinned).toList();
    final recents = sessions.where((session) => !session.pinned).toList();
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Material(
      color: KrithaColors.bgDeepest,
      child: SafeArea(
        right: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SidebarHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: KrithaSpacing.s4),
                    _ActionRow(
                      icon: HugeIcons.strokeRoundedSquarePen,
                      label: 'New chat',
                      onTap: widget.onNewChat,
                    ),
                    _ActionRow(
                      icon: HugeIcons.strokeRoundedLibrary,
                      label: 'Library',
                      onTap: () => _stub(context, 'Library'),
                    ),
                    _ActionRow(
                      icon: HugeIcons.strokeRoundedArchive,
                      label: 'Archived Chats',
                      onTap: _openArchived,
                    ),
                    _ActionRow(
                      icon: HugeIcons.strokeRoundedPuzzle,
                      label: 'Extensions',
                      onTap: () => _stub(context, 'Extensions'),
                    ),
                    _ActionRow(
                      icon: HugeIcons.strokeRoundedShieldCheck,
                      label: 'Permissions',
                      onTap: () => _stub(context, 'Permissions'),
                    ),
                    _ActionRow(
                      icon: HugeIcons.strokeRoundedEllipsis,
                      label: 'More',
                      onTap: () => _stub(context, 'More'),
                    ),
                    const SizedBox(height: KrithaSpacing.s8),
                    if (pinned.isNotEmpty) ...[
                      const _SectionTitle('Pinned'),
                      for (final session in pinned)
                        _SessionRow(
                          key: ValueKey('session-${session.id}'),
                          session: session,
                          selected: session.id == currentId,
                          onTap: () => _selectSession(session, currentId),
                          onLongPress: (rowContext, pressPosition) =>
                              _openSessionMenu(
                                rowContext,
                                pressPosition,
                                session,
                              ),
                        ),
                    ],
                    const _SectionTitle('Recents'),
                    if (recents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(
                          KrithaSpacing.s24,
                          KrithaSpacing.s8,
                          KrithaSpacing.s24,
                          KrithaSpacing.s16,
                        ),
                        child: Text(
                          'No conversations yet',
                          style: TextStyle(
                            color: KrithaColors.textMuted,
                            fontSize: KrithaText.sizeSm,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    for (final session in recents)
                      _SessionRow(
                        key: ValueKey('session-${session.id}'),
                        session: session,
                        selected: session.id == currentId,
                        onTap: () => _selectSession(session, currentId),
                        onLongPress: (rowContext, pressPosition) =>
                            _openSessionMenu(
                              rowContext,
                              pressPosition,
                              session,
                            ),
                      ),
                    const SizedBox(height: KrithaSpacing.s4),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: KrithaColors.borderFaint),
            Padding(
              padding: EdgeInsets.fromLTRB(
                KrithaSpacing.s24,
                KrithaSpacing.s12,
                KrithaSpacing.s24,
                math.max(bottomInset, KrithaSpacing.s16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: KrithaColors.accentBlue,
                      borderRadius: BorderRadius.circular(KrithaRadius.lg),
                    ),
                    child: const Text(
                      'YN',
                      style: TextStyle(
                        color: KrithaColors.textOnAccent,
                        fontSize: KrithaText.sizeBase,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: KrithaSpacing.s12),
                  const Expanded(
                    child: Text(
                      'Your Name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: KrithaText.sizeMd,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onSettings,
                    tooltip: 'Settings',
                    icon: const KrithaIcon(
                      icon: HugeIcons.strokeRoundedSettings01,
                      size: KrithaIcons.md,
                      color: KrithaColors.iconMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _stub(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is not part of this foundation yet.')),
    );
  }
}

class _ArchivedSessionsDialog extends ConsumerWidget {
  const _ArchivedSessionsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived =
        ref.watch(chatControllerProvider).value?.archivedSessions ??
        const <ChatSession>[];

    return AlertDialog(
      backgroundColor: KrithaColors.bgSurface,
      title: const Text('Archived chats'),
      content: SizedBox(
        width: 360,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: archived.isEmpty
              ? const Text(
                  'No archived chats.',
                  style: TextStyle(color: KrithaColors.textMuted),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: archived.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: KrithaColors.borderFaint),
                  itemBuilder: (context, index) {
                    final session = archived[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Restore',
                            onPressed: () => ref
                                .read(chatControllerProvider.notifier)
                                .restoreSession(session.id),
                            icon: const KrithaIcon(
                              icon: HugeIcons.strokeRoundedArchiveRestore,
                              size: KrithaIcons.md,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => ref
                                .read(chatControllerProvider.notifier)
                                .deleteSession(session.id),
                            icon: const KrithaIcon(
                              icon: HugeIcons.strokeRoundedTrash,
                              size: KrithaIcons.md,
                              color: KrithaColors.error,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KrithaSpacing.s24,
        KrithaSpacing.s4,
        KrithaSpacing.s24,
        KrithaSpacing.s12,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(KrithaRadius.sm),
            child: Image.asset(
              'assets/images/kritha_logo.png',
              width: 30,
              height: 30,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KrithaColors.accentBlue,
                  borderRadius: BorderRadius.circular(KrithaRadius.sm),
                ),
                child: const Text(
                  'K',
                  style: TextStyle(
                    color: KrithaColors.textOnAccent,
                    fontSize: KrithaText.sizeSm,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: KrithaSpacing.s10),
          const Flexible(
            child: Text(
              'Kritha',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: KrithaText.size2xl,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: KrithaSpacing.s6),
          const Padding(
            padding: EdgeInsets.only(top: KrithaSpacing.s4),
            child: Text(
              'v1.0.0',
              style: TextStyle(
                color: KrithaColors.textMuted,
                fontSize: KrithaText.sizeXs,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          _CircleIconButton(
            icon: HugeIcons.strokeRoundedSearch01,
            tooltip: 'Search chats',
            onTap: () => _ChatSidebarState._stub(context, 'Chat search'),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: KrithaColors.bgSecondary,
        shape: const CircleBorder(
          side: BorderSide(color: KrithaColors.borderSubtle),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: KrithaIcon(
              icon: icon,
              size: KrithaIcons.md,
              color: KrithaColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: KrithaDimensions.sidebarActionRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KrithaSpacing.s24),
          child: Row(
            children: [
              KrithaIcon(
                icon: icon,
                size: KrithaIcons.lg,
                color: KrithaColors.textPrimary,
              ),
              const SizedBox(width: KrithaSpacing.s14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: KrithaText.sizeMd,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KrithaSpacing.s24,
        KrithaSpacing.s14,
        KrithaSpacing.s24,
        KrithaSpacing.s8,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: KrithaText.sizeLg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SessionRow extends StatefulWidget {
  const _SessionRow({
    super.key,
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final ChatSession session;
  final bool selected;
  final VoidCallback onTap;

  /// Receives the row context (for its width) and the global press point so the
  /// menu opens where the finger landed and stays inside the sidebar.
  final void Function(BuildContext rowContext, Offset pressPosition)
  onLongPress;

  @override
  State<_SessionRow> createState() => _SessionRowState();
}

class _SessionRowState extends State<_SessionRow> {
  Offset? _pressPosition;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => _pressPosition = event.position,
      child: Material(
        color: widget.selected ? KrithaColors.bgPrimary : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: () {
            final position = _pressPosition;
            if (position != null) widget.onLongPress(context, position);
          },
          child: SizedBox(
            height: KrithaDimensions.sidebarSessionRowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KrithaSpacing.s24,
              ),
              child: Row(
                children: [
                  if (widget.session.pinned) ...[
                    KrithaIcon(
                      icon: HugeIcons.strokeRoundedMessageCircle,
                      size: KrithaIcons.base,
                      color: widget.selected
                          ? KrithaColors.textPrimary
                          : KrithaColors.textMuted,
                    ),
                    const SizedBox(width: KrithaSpacing.s12),
                  ],
                  Expanded(
                    child: Text(
                      widget.session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: KrithaText.sizeMd,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Adapts the sidebar body into the shell: an overlay on small screens and a
/// docked column on wide ones. Chosen by [KrithaViewport], not the device type.
class ChatSidebarPanel extends StatelessWidget {
  const ChatSidebarPanel({
    super.key,
    required this.viewport,
    required this.width,
    required this.onNewChat,
    required this.onSettings,
  });

  final KrithaViewport viewport;
  final double width;
  final VoidCallback onNewChat;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: KrithaColors.bgDeepest,
        border: viewport.isWide
            ? const Border(right: BorderSide(color: KrithaColors.borderSubtle))
            : null,
      ),
      child: ChatSidebar(onNewChat: onNewChat, onSettings: onSettings),
    );
  }
}
