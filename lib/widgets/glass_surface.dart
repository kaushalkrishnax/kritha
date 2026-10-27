import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// Frosted glass surface using backdrop blur.
class KrithaGlassSurface extends StatelessWidget {
  const KrithaGlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.color,
    this.border,
    this.boxShadow,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow:
            boxShadow ??
            [
              BoxShadow(
                color: KrithaColors.composerShadow,
                blurRadius: 24,
                spreadRadius: 2,
                offset: Offset(0, 8),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: KrithaDimensions.composerBlurSigma,
            sigmaY: KrithaDimensions.composerBlurSigma,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? KrithaColors.composerGlass,
              borderRadius: radius,
              border: border ?? Border.all(color: KrithaColors.borderSubtle),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
