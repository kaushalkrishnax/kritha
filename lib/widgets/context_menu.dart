import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// One row in a [showKrithaContextMenu] menu.
///
/// Menus never draw separator lines. Group emphasis comes from destructive
/// colour and the 48px row rhythm, with an 8px outer inset owned by the first
/// and last rows. If a menu has a heading, the top edge inset belongs to the
/// heading; the first action remains a normal-height row.
class ContextMenuItem {
  ContextMenuItem({
    required this.id,
    required this.label,
    this.icon,
    this.destructive = false,
    this.disabled = false,
    this.focusColor,
  });

  final String id;
  final String label;
  final List<List<dynamic>>? icon;
  final bool destructive;
  final bool disabled;
  final Color? focusColor;
}

enum ContextMenuAlign { left, right, auto }

/// A rectangle in global coordinates that the menu should attach itself to.
class ContextMenuAnchor {
  ContextMenuAnchor({required this.position, required this.size});

  /// Top-left corner of the target in global coordinates.
  final Offset position;
  final Size size;

  /// Builds an anchor from a widget's paint bounds. Call this from a widget
  /// that is already laid out (for example inside a long-press callback).
  factory ContextMenuAnchor.fromContext(
    BuildContext context, {
    double? height,
  }) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return ContextMenuAnchor(position: Offset.zero, size: Size.zero);
    }
    return ContextMenuAnchor(
      position: box.localToGlobal(Offset.zero),
      size: Size(box.size.width, height ?? box.size.height),
    );
  }
}

/// Shows the shared Kritha context menu and resolves to the selected item id,
/// or `null` when dismissed.
///
/// This is a direct Flutter port of `src/components/ui/ContextMenu.tsx`:
/// 200px wide, 48px rows with an 8px edge inset on the first/last row, 24px
/// corners, the same safe-area clamping, the same 8px gap and flip-above
/// behaviour when there is room, and the same fade + spring-in animation. With
/// the software keyboard open the menu stays fully
/// above the IME (the IME is a separate window on Android, so anything drawn
/// inside its rectangle would be hidden) and the route does not request focus,
/// so the composer keyboard stays up.
///
/// [rightBoundary] optionally keeps an auto-aligned menu inside a panel (for
/// example the sidebar) instead of letting it spill into the chat column.
///
/// [width] and [left] replace the default 200px surface and horizontal
/// clamping. They position the menu independently of the opening widget's
/// padding, which the sidebar account menu uses to span the whole panel.
Future<String?> showKrithaContextMenu({
  required BuildContext context,
  required ContextMenuAnchor anchor,
  required List<ContextMenuItem> items,
  Widget? header,
  ContextMenuAlign align = ContextMenuAlign.auto,
  double? targetHeight,
  double? rightBoundary,
  double? width,
  double? left,
}) {
  if (items.isEmpty) return Future.value();
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss menu',
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    // Keep the composer's TextField focused and the software keyboard open.
    // The menu is an overlay, not a focus-taking dialog.
    requestFocus: false,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _ContextMenuOverlay(
        anchor: anchor,
        items: items,
        header: header,
        align: align,
        targetHeight: targetHeight,
        rightBoundary: rightBoundary,
        width: width,
        left: left,
      );
    },
  );
}

class _ContextMenuOverlay extends StatefulWidget {
  const _ContextMenuOverlay({
    required this.anchor,
    required this.items,
    required this.align,
    this.header,
    this.targetHeight,
    this.rightBoundary,
    this.width,
    this.left,
  });

  final ContextMenuAnchor anchor;
  final List<ContextMenuItem> items;
  final Widget? header;
  final ContextMenuAlign align;
  final double? targetHeight;
  final double? rightBoundary;
  final double? width;
  final double? left;

  @override
  State<_ContextMenuOverlay> createState() => _ContextMenuOverlayState();
}

class _ContextMenuOverlayState extends State<_ContextMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: KrithaMotion.contextMenu,
  )..forward();

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.95,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final insets = media.viewPadding;
    final screen = media.size;
    final anchor = widget.anchor;

    final target = widget.targetHeight ?? anchor.size.height;
    final headerHeight = widget.header == null
        ? 0.0
        : KrithaDimensions.contextMenuHeaderHeight;
    // Every row owns its full 48px press surface. The first and last rows add
    // an 8px outer edge inset inside that press surface, so the estimate must
    // include the outside edge padding, with the leading inset shared with a
    // header when present. The 2px allowance covers the 1px border.
    final estimatedHeight =
        widget.items.length * KrithaDimensions.contextMenuItemHeight +
        (KrithaDimensions.contextMenuEdgeInset *
            (widget.header == null ? 2 : 1)) +
        headerHeight +
        2;

    final menuWidth = widget.width ?? KrithaDimensions.contextMenuWidth;
    final minLeft = insets.left + KrithaDimensions.contextMenuScreenMargin;
    final maxLeft =
        screen.width -
        insets.right -
        menuWidth -
        KrithaDimensions.contextMenuScreenMargin;

    double left;
    if (widget.left != null) {
      left = widget.left!
          .clamp(
            insets.left,
            math.max(insets.left, screen.width - insets.right - menuWidth),
          )
          .toDouble();
    } else {
      switch (widget.align) {
        case ContextMenuAlign.left:
          left = minLeft;
        case ContextMenuAlign.right:
          final rightEdge = widget.rightBoundary;
          left = rightEdge == null
              ? screen.width -
                    insets.right -
                    menuWidth -
                    KrithaDimensions.contextMenuScreenMargin
              // A caller-provided boundary already sits inside the target's
              // padding, so do not add the screen gutter on top of it.
              : rightEdge - menuWidth;
          if (left < minLeft) left = minLeft;
        case ContextMenuAlign.auto:
          var autoMaxLeft = maxLeft;
          if (widget.rightBoundary != null) {
            final boundaryLeft = widget.rightBoundary! - menuWidth;
            if (boundaryLeft < autoMaxLeft) autoMaxLeft = boundaryLeft;
          }
          left = anchor.position.dx;
          if (left > autoMaxLeft) left = autoMaxLeft;
          if (left < minLeft) left = minLeft;
      }
    }

    var top =
        anchor.position.dy + target + KrithaDimensions.contextMenuVerticalGap;
    var flippedAbove = false;
    final topLimit = insets.top + KrithaDimensions.contextMenuSafeTop;
    // The IME is a separate window above the app on Android, so a menu drawn
    // into the keyboard's rectangle would be hidden behind it. Keep the whole
    // menu above the keyboard (ChatGPT-style) instead of clamping halfway into
    // it, while still not stealing composer focus.
    final keyboard = media.viewInsets.bottom;
    final bottomLimit =
        screen.height -
        keyboard -
        insets.bottom -
        KrithaDimensions.contextMenuScreenMargin;
    if (top + estimatedHeight > bottomLimit) {
      if (keyboard > 0) {
        top = bottomLimit - estimatedHeight;
        if (top < topLimit) top = topLimit;
      } else {
        flippedAbove = true;
        top =
            anchor.position.dy -
            estimatedHeight -
            KrithaDimensions.contextMenuVerticalGap;
        if (top < topLimit) top = topLimit;
      }
    }

    // Grow out of the corner nearest the press point instead of the centre, so
    // the menu reads as coming from the bubble/row that opened it.
    final openToRight =
        widget.left == null &&
        (widget.align == ContextMenuAlign.right ||
            (widget.align == ContextMenuAlign.auto &&
                left + menuWidth / 2 > anchor.position.dx));
    final horizontal = openToRight ? Alignment.topRight : Alignment.topLeft;
    final scaleOrigin = flippedAbove
        ? (openToRight ? Alignment.bottomRight : Alignment.bottomLeft)
        : horizontal;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: menuWidth,
          child: FadeTransition(
            opacity: _opacity,
            child: ScaleTransition(
              scale: _scale,
              alignment: scaleOrigin,
              child: _MenuSurface(items: widget.items, header: widget.header),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuSurface extends StatelessWidget {
  const _MenuSurface({required this.items, this.header});

  final List<ContextMenuItem> items;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey('context-menu-surface'),
      decoration: BoxDecoration(
        color: KrithaColors.bgPrimary,
        borderRadius: BorderRadius.circular(KrithaRadius.xl),
        border: Border.all(color: KrithaColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: KrithaColors.menuShadow,
            offset: Offset(0, 10),
            blurRadius: 24,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KrithaRadius.xl),
        child: Material(
          type: MaterialType.transparency,
          // Rows fill the surface edge to edge. The first and last rows carry
          // the outer edge inset themselves, so there is no menu-level gutter
          // and their press feedback still fills the full rounded surface.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    KrithaSpacing.s20,
                    KrithaSpacing.s12 + KrithaDimensions.contextMenuEdgeInset,
                    KrithaSpacing.s20,
                    KrithaSpacing.s8,
                  ),
                  child: header,
                ),
              for (var index = 0; index < items.length; index++)
                _MenuItemRow(
                  item: items[index],
                  topInset: header == null && index == 0
                      ? KrithaDimensions.contextMenuEdgeInset
                      : 0,
                  bottomInset: index == items.length - 1
                      ? KrithaDimensions.contextMenuEdgeInset
                      : 0,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({
    required this.item,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  final ContextMenuItem item;
  final double topInset;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final textColor = item.disabled
        ? KrithaColors.textMuted
        : item.destructive
        ? KrithaColors.error
        : KrithaColors.textPrimary;

    final row = SizedBox(
      height: KrithaDimensions.contextMenuItemHeight + topInset + bottomInset,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          KrithaSpacing.s20,
          topInset,
          KrithaSpacing.s20,
          bottomInset,
        ),
        child: Row(
          children: [
            if (item.icon != null) ...[
              SizedBox(
                width: KrithaDimensions.contextMenuIconColumn,
                child: Center(
                  child: KrithaIcon(
                    icon: item.icon!,
                    size: KrithaDimensions.contextMenuIconSize,
                    color: textColor,
                  ),
                ),
              ),
              SizedBox(width: KrithaDimensions.contextMenuIconGap),
            ],
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: KrithaText.sizeMd,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // The whole row is the hit target, including its outer edge inset, so
    // feedback fills the surface edge to edge with no dead band.
    if (item.disabled) {
      return Opacity(opacity: 0.5, child: row);
    }
    return Semantics(
      button: true,
      label: item.label,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(item.id),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStatePropertyAll(
          item.focusColor ?? KrithaColors.contextMenuPressed,
        ),
        child: row,
      ),
    );
  }
}
