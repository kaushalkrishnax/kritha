import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// Shimmering placeholder for content that is still loading.
///
/// Use it to mirror real screen geometry, never inside buttons or labels.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius});

  final double? width;
  final double height;
  final BorderRadius? radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          colors: [
            KrithaColors.bgSecondary,
            KrithaColors.bgTertiary,
            KrithaColors.bgSecondary,
          ],
          stops: const [0.35, 0.5, 0.65],
          transform: _SlidingGradientTransform(_controller.value * 2 - 1),
        ).createShader(bounds),
        child: child,
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: KrithaColors.bgSecondary,
          borderRadius: widget.radius ?? BorderRadius.circular(KrithaRadius.xs),
        ),
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.slide);

  final double slide;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slide, 0, 0);
  }
}
