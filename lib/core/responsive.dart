import 'package:material_ui/material_ui.dart';

/// Shared viewport breakpoints for the whole application.
///
/// Compact: `< 600` logical pixels.
/// Medium: `600 – 839` logical pixels.
/// Wide: `>= 840` logical pixels.
///
/// These mirror the three states the chat shell is designed around. Keep every
/// responsive decision in the app anchored to this one definition so a
/// component never disagrees with the shell about the current viewport.
abstract final class KrithaBreakpoints {
  static const double compact = 600;
  static const double medium = 840;
}

enum KrithaViewport { compact, medium, wide }

KrithaViewport viewportOf(double width) {
  if (width < KrithaBreakpoints.compact) return KrithaViewport.compact;
  if (width < KrithaBreakpoints.medium) return KrithaViewport.medium;
  return KrithaViewport.wide;
}

extension KrithaViewportX on KrithaViewport {
  bool get isCompact => this == KrithaViewport.compact;
  bool get isMedium => this == KrithaViewport.medium;
  bool get isWide => this == KrithaViewport.wide;

  /// Messages and the composer share one readable column. Medium viewports
  /// are already narrower than the cap, so only wide screens need it.
  bool get usesCenteredColumn => this == KrithaViewport.wide;

  /// Wide screens get a docked sidebar; smaller screens use an overlay drawer.
  bool get usesDockedSidebar => this == KrithaViewport.wide;
}

/// Small helper that exposes the current [KrithaViewport] to a subtree using
/// the constraints it is actually rendered with, not the device type.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, KrithaViewport viewport) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          builder(context, viewportOf(constraints.maxWidth)),
    );
  }
}
