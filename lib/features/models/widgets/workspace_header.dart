import 'package:material_ui/material_ui.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme.dart';

class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.actions = const [],
    this.backTooltip = 'Back',
  });

  final String title;
  final VoidCallback onBack;
  final List<Widget> actions;
  final String backTooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        KrithaSpacing.s12,
        KrithaSpacing.s12,
        KrithaSpacing.s12,
        KrithaSpacing.s8,
      ),
      child: Row(
        children: [
          WorkspaceBackButton(tooltip: backTooltip, onTap: onBack),
          SizedBox(width: KrithaSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: KrithaText.sizeXl,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            SizedBox(width: KrithaSpacing.s8),
            Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ],
      ),
    );
  }
}

class WorkspaceBackButton extends StatelessWidget {
  const WorkspaceBackButton({
    super.key,
    required this.tooltip,
    required this.onTap,
  });

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkResponse(
          onTap: onTap,
          customBorder: const CircleBorder(),
          containedInkWell: true,
          hoverColor: KrithaColors.contextMenuPressed,
          focusColor: KrithaColors.contextMenuPressed,
          splashColor: KrithaColors.contextMenuPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: KrithaIcon(
              icon: HugeIcons.strokeRoundedArrowLeft02,
              size: KrithaIcons.md,
              color: KrithaColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class WorkspaceIconButton extends StatelessWidget {
  const WorkspaceIconButton({
    super.key,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KrithaRadius.full),
          side: BorderSide(color: KrithaColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          hoverColor: KrithaColors.contextMenuPressed,
          focusColor: KrithaColors.contextMenuPressed,
          splashColor: KrithaColors.contextMenuPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: KrithaIcon(
                icon: icon,
                size: KrithaIcons.md,
                color: KrithaColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WorkspaceSectionTitle extends StatelessWidget {
  const WorkspaceSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: KrithaSpacing.s8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: KrithaText.sizeLg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class WorkspaceCard extends StatelessWidget {
  const WorkspaceCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.all(KrithaSpacing.s16),
      decoration: BoxDecoration(
        color: KrithaColors.bgSurface,
        borderRadius: BorderRadius.circular(KrithaRadius.md),
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      child: child,
    );
  }
}

class WorkspaceOutlinedAction extends StatelessWidget {
  const WorkspaceOutlinedAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final List<List<dynamic>>? icon;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: KrithaColors.textSecondary,
      side: BorderSide(color: KrithaColors.borderStrong),
      minimumSize: const Size(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KrithaRadius.base),
      ),
    );
    final child = busy
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: KrithaColors.textMuted,
            ),
          )
        : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (icon == null) {
      return OutlinedButton(onPressed: onPressed, style: style, child: child);
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: style,
      icon: KrithaIcon(icon: icon!, size: 16),
      label: child,
    );
  }
}

class WorkspaceDivider extends StatelessWidget {
  const WorkspaceDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: KrithaColors.borderFaint);
}

class CapabilityChip extends StatelessWidget {
  const CapabilityChip({super.key, required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: KrithaSpacing.s8,
        vertical: KrithaSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: selected
            ? KrithaColors.accentBlue.withValues(alpha: 0.16)
            : KrithaColors.bgTertiary,
        borderRadius: BorderRadius.circular(KrithaRadius.full),
        border: Border.all(
          color: selected
              ? KrithaColors.borderAccent
              : KrithaColors.borderSubtle,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: KrithaText.size2xs,
          fontWeight: FontWeight.w600,
          color: selected
              ? KrithaColors.accentLightBlue
              : KrithaColors.textMuted,
        ),
      ),
    );
  }
}
