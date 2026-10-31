import 'package:material_ui/material_ui.dart';

/// Shared viewport breakpoints for responsive layouts.
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

  /// Messages and composer readable column cap; only wide screens need it.
  bool get usesCenteredColumn => this == KrithaViewport.wide;

  /// Docked sidebar on wide screens; overlay drawer on smaller screens.
  bool get usesDockedSidebar => this == KrithaViewport.wide;
}

/// Exposes [KrithaViewport] from local constraints rather than device type.
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
