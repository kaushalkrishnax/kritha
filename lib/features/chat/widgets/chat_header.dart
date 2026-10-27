import 'package:material_ui/material_ui.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme.dart';

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.onMenu,
    required this.onNewChat,
    required this.onChatMenu,
    this.showMenuButton = true,
    this.menuTooltip = 'Sessions',
  });

  final VoidCallback onMenu;
  final VoidCallback onNewChat;

  final void Function(BuildContext buttonContext) onChatMenu;
  final bool showMenuButton;

  final String menuTooltip;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: KrithaDimensions.headerHeight),
      child: Padding(
        padding: EdgeInsets.only(
          left: KrithaSpacing.s12,
          top: KrithaSpacing.s12,
          right: KrithaSpacing.s12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (showMenuButton)
              _HeaderPill(
                children: [
                  _HeaderIcon(
                    icon: HugeIcons.strokeRoundedMenuTwoLine,
                    tooltip: menuTooltip,
                    onTap: onMenu,
                  ),
                ],
              )
            else
              SizedBox.shrink(),
            _HeaderPill(
              children: [
                _HeaderIcon(
                  icon: HugeIcons.strokeRoundedSquarePen,
                  tooltip: 'New chat',
                  onTap: onNewChat,
                ),
                _HeaderIcon(
                  icon: HugeIcons.strokeRoundedEllipsisVertical,
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
        side: BorderSide(color: KrithaColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
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

  final List<List<dynamic>> icon;
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
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: EdgeInsets.all(KrithaSpacing.s12),
            child: KrithaIcon(
              icon: icon,
              size: KrithaIcons.lg,
              color: KrithaColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
