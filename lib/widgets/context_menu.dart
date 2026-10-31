import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// One row in a [showKrithaContextMenu] menu.
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

  final Offset position;
  final Size size;

  /// Builds an anchor from a widget's global paint bounds.
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

/// Shows the shared Kritha context menu and resolves to the selected item id.
Future<String?> showKrithaContextMenu({
  required BuildContext context,
  required ContextMenuAnchor anchor,
  required List<ContextMenuItem> items,
  Widget? header,
  ContextMenuAlign align = ContextMenuAlign.auto,
  double? targetHeight,
  Rect? bounds,
  bool fillBounds = false,
}) {
  if (items.isEmpty) return Future.value();
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss menu',
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    // Keeps composer focused and software keyboard open as an overlay.
    requestFocus: false,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _ContextMenuOverlay(
        anchor: anchor,
        items: items,
        header: header,
        align: align,
        targetHeight: targetHeight,
        bounds: bounds,
        fillBounds: fillBounds,
      );
    },
  );
}

/// Global paint bounds of [context], for menus that should stay inside it.
Rect? contextMenuBoundsOf(BuildContext? context) {
  final box = context?.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _ContextMenuOverlay extends StatefulWidget {
  const _ContextMenuOverlay({
    required this.anchor,
    required this.items,
    required this.align,
    this.header,
    this.targetHeight,
    this.bounds,
    this.fillBounds = false,
  });

  final ContextMenuAnchor anchor;
  final List<ContextMenuItem> items;
  final Widget? header;
  final ContextMenuAlign align;
  final double? targetHeight;
  final Rect? bounds;
  final bool fillBounds;

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
    // Row height includes 48px target, outer insets, and border allowance.
    final estimatedHeight =
        widget.items.length * KrithaDimensions.contextMenuItemHeight +
        (KrithaDimensions.contextMenuEdgeInset *
            (widget.header == null ? 2 : 1)) +
        headerHeight +
        2;

    const margin = KrithaDimensions.contextMenuScreenMargin;
    final bounds = widget.bounds;
    final panelLeft = bounds == null ? null : bounds.left + margin;
    final panelRight = bounds == null
        ? null
        : math.max(bounds.left + margin, bounds.right - margin);
    final menuWidth = widget.fillBounds && bounds != null
        ? math.max(0.0, panelRight! - panelLeft!)
        : KrithaDimensions.contextMenuWidth;

    double left;
    if (bounds != null) {
      final maxPanelLeft = math.max(panelLeft!, panelRight! - menuWidth);
      switch (widget.align) {
        case ContextMenuAlign.left:
          left = panelLeft;
        case ContextMenuAlign.right:
          left = maxPanelLeft;
        case ContextMenuAlign.auto:
          left = anchor.position.dx.clamp(panelLeft, maxPanelLeft).toDouble();
      }
    } else {
      final minLeft = insets.left + margin;
      final maxLeft = screen.width - insets.right - menuWidth - margin;
      switch (widget.align) {
        case ContextMenuAlign.left:
          left = minLeft;
        case ContextMenuAlign.right:
          // Aligns with anchor instead of viewport so parent padding stays outside.
          left = (anchor.position.dx + anchor.size.width - menuWidth)
              .clamp(minLeft, math.max(minLeft, maxLeft))
              .toDouble();
        case ContextMenuAlign.auto:
          left = anchor.position.dx
              .clamp(minLeft, math.max(minLeft, maxLeft))
              .toDouble();
      }
    }

    var top =
        anchor.position.dy + target + KrithaDimensions.contextMenuVerticalGap;
    var flippedAbove = false;
    // Keeps menu above keyboard without stealing composer focus.
    final keyboard = media.viewInsets.bottom;
    final topLimit = bounds == null
        ? insets.top + KrithaDimensions.contextMenuSafeTop
        : math.max(
            insets.top + KrithaDimensions.contextMenuSafeTop,
            bounds.top + margin,
          );
    final bottomLimit = bounds == null
        ? screen.height - keyboard - insets.bottom - margin
        : math.min(
            screen.height - keyboard - insets.bottom - margin,
            bounds.bottom - margin,
          );
    if (top + estimatedHeight > bottomLimit) {
      if (keyboard > 0) {
        top = bottomLimit - estimatedHeight;
      } else {
        flippedAbove = true;
        top =
            anchor.position.dy -
            estimatedHeight -
            KrithaDimensions.contextMenuVerticalGap;
      }
    }
    top = top
        .clamp(topLimit, math.max(topLimit, bottomLimit - estimatedHeight))
        .toDouble();

    // Expands from corner nearest press point to anchor to trigger.
    final openToRight =
        !widget.fillBounds &&
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
          // Edge-to-edge rows carry outer insets so press feedback covers rounded corners.
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

    // Hit target includes outer inset so press feedback fills edge to edge.
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
