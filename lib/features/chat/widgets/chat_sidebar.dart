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
    this.onCollapse,
  });

  final VoidCallback onNewChat;
  final VoidCallback onSettings;
  final VoidCallback? onCollapse;

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
        ContextMenuItem(
          id: 'rename',
          label: 'Rename',
          icon: HugeIcons.strokeRoundedEdit03,
        ),
        ContextMenuItem(
          id: 'archive',
          label: 'Archive',
          icon: HugeIcons.strokeRoundedArchive,
        ),
        ContextMenuItem(
          id: 'delete',
          label: 'Delete',
          icon: HugeIcons.strokeRoundedDelete02,
          destructive: true,
          focusColor: Color(0x33FF453A),
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
        title: Text('Rename chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          decoration: InputDecoration(hintText: 'Chat title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text('Save'),
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
      builder: (_) => _ArchivedSessionsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider).value;
    final sessions = chat?.sessions ?? <ChatSession>[];
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
            _SidebarHeader(onCollapse: widget.onCollapse),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: KrithaSpacing.s4),
                    _ActionRow(
                      icon: HugeIcons.strokeRoundedSquarePen,
                      label: 'New chat',
                      onTap: widget.onNewChat,
                    ),
                    _ActionRow(
                      icon: HugeIcons.strokeRoundedLibraryBig,
                      label: 'Library',
                      onTap: () => _stub(context, 'Library'),
                    ),
                    _ActionRow(
                      icon: HugeIcons.strokeRoundedArchive,
                      label: 'Archived Chats',
                      onTap: _openArchived,
                    ),
                    _ActionRow(
                      icon: HugeIcons.strokeRoundedPlug02,
                      label: 'Plugins',
                      onTap: () => _stub(context, 'Plugins'),
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
                    SizedBox(height: KrithaSpacing.s8),
                    if (pinned.isNotEmpty) ...[
                      _SectionTitle('Pinned'),
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
                    _SectionTitle('Recents'),
                    if (recents.isEmpty)
                      Padding(
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
                    SizedBox(height: KrithaSpacing.s4),
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
              child: _AccountControl(
                compact: false,
                onSettings: widget.onSettings,
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
        <ChatSession>[];

    return AlertDialog(
      backgroundColor: KrithaColors.bgSurface,
      title: Text('Archived chats'),
      content: SizedBox(
        width: 360,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 360),
          child: archived.isEmpty
              ? Text(
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
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
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
                              icon: KrithaIcon(
                                icon: HugeIcons.strokeRoundedArchiveRestore,
                                size: KrithaIcons.md,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => ref
                                  .read(chatControllerProvider.notifier)
                                  .deleteSession(session.id),
                              icon: KrithaIcon(
                                icon: HugeIcons.strokeRoundedDelete02,
                                size: KrithaIcons.md,
                                color: KrithaColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({this.onCollapse});

  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final docked = onCollapse != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        KrithaSpacing.s24,
        KrithaSpacing.s4,
        // The drawer keeps only one trailing control, so the full 24px gutter
        // leaves a dead band to its right.
        docked ? KrithaSpacing.s16 : KrithaSpacing.s8,
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
                child: Text(
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
          SizedBox(width: KrithaSpacing.s10),
          Flexible(
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
          Spacer(),
          if (!docked)
            _CircleIconButton(
              icon: HugeIcons.strokeRoundedSearch01,
              tooltip: 'Search chats',
              onTap: () => _ChatSidebarState._stub(context, 'Chat search'),
            )
          else ...[
            _HeaderIconButton(
              icon: HugeIcons.strokeRoundedSearch01,
              tooltip: 'Search chats',
              onTap: () => _ChatSidebarState._stub(context, 'Chat search'),
            ),
            SizedBox(width: KrithaSpacing.s4),
            _HeaderIconButton(
              icon: HugeIcons.strokeRoundedPanelLeft,
              tooltip: 'Collapse sidebar',
              onTap: onCollapse!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Borderless header action used on the docked desktop sidebar, where the
/// persistent circular fill of [_CircleIconButton] reads as unnecessary chrome.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
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
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(KrithaRadius.base),
        hoverColor: KrithaColors.contextMenuPressed,
        splashColor: KrithaColors.contextMenuPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: KrithaIcon(
              icon: icon,
              size: KrithaIcons.md,
              color: KrithaColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountControl extends StatefulWidget {
  const _AccountControl({required this.compact, required this.onSettings});

  final bool compact;
  final VoidCallback onSettings;

  @override
  State<_AccountControl> createState() => _AccountControlState();
}

class _AccountControlState extends State<_AccountControl> {
  Offset? _pressPosition;

  Future<void> _openMenu(BuildContext context) async {
    final selection = await showKrithaContextMenu(
      context: context,
      // Anchor at the press point so the menu grows from where the user
      // clicked instead of being pinned to the row's leading edge.
      anchor: _pressPosition == null
          ? ContextMenuAnchor.fromContext(context)
          : ContextMenuAnchor(position: _pressPosition!, size: Size.zero),
      items: [
        ContextMenuItem(
          id: 'free',
          label: 'Free',
          disabled: true,
          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
        ),
        ContextMenuItem(
          id: 'personalization',
          label: 'Personalization',
          icon: HugeIcons.strokeRoundedSettings02,
        ),
        ContextMenuItem(
          id: 'profile',
          label: 'Profile',
          icon: HugeIcons.strokeRoundedUser,
        ),
        ContextMenuItem(
          id: 'settings',
          label: 'Settings',
          icon: HugeIcons.strokeRoundedSettings01,
        ),
        ContextMenuItem(
          id: 'logout',
          label: 'Log out',
          icon: HugeIcons.strokeRoundedLogout01,
        ),
      ],
    );
    if (!context.mounted || selection == null) return;
    if (selection == 'settings') {
      widget.onSettings();
      return;
    }
    final message = switch (selection) {
      'personalization' => 'Personalization is not available yet.',
      'profile' => 'Profile management is not available yet.',
      'logout' => 'Sign out is not available yet.',
      _ => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Account menu',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: (details) => _pressPosition = details.globalPosition,
          onTap: () => _openMenu(context),
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(KrithaRadius.base),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s6),
            child: widget.compact
                ? Center(child: _AccountAvatar(size: 32))
                : Row(
                    children: [
                      _AccountAvatar(size: 32),
                      SizedBox(width: KrithaSpacing.s10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Kaushal Krishna',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: KrithaText.sizeSm,
                                color: KrithaColors.textSecondary.withValues(
                                  alpha: 0.78,
                                ),
                              ),
                            ),
                            Text(
                              'Free',
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
          ),
        ),
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(0xFFEF493B),
        shape: BoxShape.circle,
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      child: Text(
        'KK',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class CompactSidebarRail extends StatelessWidget {
  const CompactSidebarRail({
    super.key,
    required this.onExpand,
    required this.onNewChat,
    required this.onSettings,
  });

  final VoidCallback onExpand;
  final VoidCallback onNewChat;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      decoration: BoxDecoration(
        color: KrithaColors.bgDeepest,
        border: Border(right: BorderSide(color: KrithaColors.borderSubtle)),
      ),
      child: Column(
        children: [
          SizedBox(height: KrithaSpacing.s8),
          _RailButton(
            icon: HugeIcons.strokeRoundedLayoutAlignLeft,
            tooltip: 'Expand sidebar',
            onTap: onExpand,
          ),
          SizedBox(height: KrithaSpacing.s8),
          _RailButton(
            icon: HugeIcons.strokeRoundedSquarePen,
            tooltip: 'New chat',
            onTap: onNewChat,
          ),
          SizedBox(height: KrithaSpacing.s8),
          _RailButton(
            icon: HugeIcons.strokeRoundedSearch01,
            tooltip: 'Search chats',
            onTap: () => _ChatSidebarState._stub(context, 'Chat search'),
          ),
          SizedBox(height: KrithaSpacing.s8),
          _RailButton(
            icon: HugeIcons.strokeRoundedPin,
            tooltip: 'Pinned chats',
            onTap: () => _ChatSidebarState._stub(context, 'Pinned chats'),
          ),
          SizedBox(height: KrithaSpacing.s8),
          _RailButton(
            icon: HugeIcons.strokeRoundedMessageCircle,
            tooltip: 'Chats',
            onTap: () => _ChatSidebarState._stub(context, 'Chats'),
          ),
          SizedBox(height: KrithaSpacing.s8),
          _RailButton(
            icon: HugeIcons.strokeRoundedLibraryBig,
            tooltip: 'Library',
            onTap: () => _ChatSidebarState._stub(context, 'Library'),
          ),
          Spacer(),
          Padding(
            padding: EdgeInsets.only(bottom: KrithaSpacing.s12),
            child: _AccountControl(compact: true, onSettings: onSettings),
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
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
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: IconButton(
          onPressed: onTap,
          tooltip: '',
          icon: KrithaIcon(
            icon: icon,
            size: KrithaIcons.md,
            color: KrithaColors.textSecondary,
          ),
        ),
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
        shape: CircleBorder(side: BorderSide(color: KrithaColors.borderSubtle)),
        child: InkWell(
          customBorder: CircleBorder(),
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
          padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s24),
          child: Row(
            children: [
              KrithaIcon(
                icon: icon,
                size: KrithaIcons.lg,
                color: KrithaColors.textPrimary,
              ),
              SizedBox(width: KrithaSpacing.s14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
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
      padding: EdgeInsets.fromLTRB(
        KrithaSpacing.s24,
        KrithaSpacing.s14,
        KrithaSpacing.s24,
        KrithaSpacing.s8,
      ),
      child: Text(
        text,
        style: TextStyle(
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
          mouseCursor: SystemMouseCursors.click,
          onLongPress: () {
            final position = _pressPosition;
            if (position != null) widget.onLongPress(context, position);
          },
          onSecondaryTap: () {
            final position = _pressPosition;
            if (position != null) widget.onLongPress(context, position);
          },
          child: SizedBox(
            height: KrithaDimensions.sidebarSessionRowHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s24),
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
                    SizedBox(width: KrithaSpacing.s12),
                  ],
                  Expanded(
                    child: Text(
                      widget.session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
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
            ? Border(right: BorderSide(color: KrithaColors.borderSubtle))
            : null,
      ),
      child: ChatSidebar(onNewChat: onNewChat, onSettings: onSettings),
    );
  }
}
