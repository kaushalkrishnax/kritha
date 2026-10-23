import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme.dart';

/// Chat header ported from the React Native `ChatHeader`.
///
/// The original has two pill clusters: navigation on the left, new-chat and the
/// wake-word toggle on the right. The wake-word runtime is not part of this
/// foundation, so the right slot is now the per-chat options menu (the runtime
/// controls live in Settings and the sidebar).
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.onMenu,
    required this.onNewChat,
    required this.onChatMenu,
    this.menuTooltip = 'Sessions',
  });

  final VoidCallback onMenu;
  final VoidCallback onNewChat;

  /// Opens the chat options menu at the ellipsis button's global position.
  final void Function(BuildContext buttonContext) onChatMenu;

  final String menuTooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: KrithaDimensions.headerHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KrithaSpacing.s16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _HeaderPill(
              children: [
                _HeaderIcon(
                  icon: LucideIcons.menu,
                  tooltip: menuTooltip,
                  onTap: onMenu,
                ),
              ],
            ),
            _HeaderPill(
              children: [
                _HeaderIcon(
                  icon: LucideIcons.squarePen,
                  tooltip: 'New chat',
                  onTap: onNewChat,
                ),
                _HeaderIcon(
                  icon: LucideIcons.ellipsisVertical,
                  tooltip: 'Chat options',
                  onTapWithContext: onChatMenu,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KrithaColors.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KrithaRadius.full),
        side: const BorderSide(color: KrithaColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      // The pill owns no outer padding. Each icon's ink surface fills the full
      // 48px pill height, so focus and press feedback never leave a dead ring
      // between the highlight and the capsule edge.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: KrithaSpacing.s4,
        children: children,
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.onTapWithContext,
  }) : assert(onTap != null || onTapWithContext != null);

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final void Function(BuildContext buttonContext)? onTapWithContext;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTapWithContext != null
              ? () => onTapWithContext!(buttonContext)
              : onTap,
          borderRadius: BorderRadius.circular(KrithaRadius.lg),
          splashColor: KrithaColors.contextMenuPressed,
          highlightColor: KrithaColors.contextMenuPressed,
          focusColor: KrithaColors.contextMenuPressed,
          hoverColor: KrithaColors.contextMenuPressed,
          child: Padding(
            // 12px all round makes a 48px ink surface: the former 4px pill
            // padding now lives inside the button instead of outside its ink.
            padding: const EdgeInsets.all(KrithaSpacing.s12),
            child: Icon(
              icon,
              size: KrithaIcons.lg,
              color: KrithaColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
