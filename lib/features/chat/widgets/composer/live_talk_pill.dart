import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme.dart';

/// Transparent glass fish-pot pill with continuous, seam-free water waves.
class LiveTalkPill extends StatefulWidget {
  const LiveTalkPill({
    super.key,
    required this.active,
    this.audioLevel = 0.0,
  });

  /// Listening and speaking animate; paused settles to calm water.
  final bool active;

  /// Normalized voice/audio amplitude (0..1) driving wave height and bump energy.
  final double audioLevel;

  @override
  State<LiveTalkPill> createState() => _LiveTalkPillState();
}

class _LiveTalkPillState extends State<LiveTalkPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
    value: 0.0,
  );

  double _smoothedLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _smoothedLevel = widget.audioLevel;
    _sync();
  }

  @override
  void didUpdateWidget(LiveTalkPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    _smoothedLevel = _smoothedLevel * 0.55 + widget.audioLevel * 0.45;
    if (oldWidget.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active) {
      _flow.repeat();
    } else {
      _flow.stop();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.active ? _smoothedLevel.clamp(0.0, 1.0) : 0.0;
    return Container(
      key: const ValueKey('live-talk-pill'),
      width: KrithaDimensions.liveTalkPillMaxWidth,
      height: KrithaDimensions.liveTalkPillHeight,
      decoration: BoxDecoration(
        color: KrithaColors.bgDeepest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(KrithaRadius.xl),
        border: Border.all(
          color: KrithaColors.accentLightBlue.withValues(
            alpha: widget.active ? (0.24 + level * 0.22) : 0.14,
          ),
        ),
        boxShadow: [
          if (widget.active && level > 0.05)
            BoxShadow(
              color: KrithaColors.accentBlue.withValues(alpha: level * 0.26),
              blurRadius: 14,
              spreadRadius: -2,
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _flow,
        builder: (context, child) => CustomPaint(
          painter: _FishPotWaterPainter(
            progress: _flow.value,
            active: widget.active,
            audioLevel: level,
          ),
        ),
      ),
    );
  }
}

class _FishPotWaterPainter extends CustomPainter {
  const _FishPotWaterPainter({
    required this.progress,
    required this.active,
    required this.audioLevel,
  });

  final double progress;
  final bool active;
  final double audioLevel;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final clip = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );
    canvas.save();
    canvas.clipRRect(clip);

    // Integer cycle multipliers ensure progress=1.0 wraps to 0.0 with zero cut.
    final tau = progress * math.pi * 2;
    final energy = active ? audioLevel : 0.0;
    final idleRipple = active ? 0.032 : 0.012;

    _drawWaterLayer(
      canvas,
      size,
      baseFillRatio: 0.72 - energy * 0.24,
      amplitude: size.height * (idleRipple + 0.16 * energy),
      spatialCycles: 2.0,
      phase: tau * 1.0 + 1.4,
      sloshTilt: math.sin(tau * 1.0) * size.height * (0.015 + 0.08 * energy),
      colors: [
        KrithaColors.accentCyanBg.withValues(alpha: 0.22 + 0.20 * energy),
        KrithaColors.accentBlue.withValues(alpha: 0.30 + 0.22 * energy),
      ],
    );

    _drawWaterLayer(
      canvas,
      size,
      baseFillRatio: 0.76 - energy * 0.22,
      amplitude: size.height * (idleRipple * 1.15 + 0.18 * energy),
      spatialCycles: 2.0,
      phase: -tau * 2.0 + 0.5,
      sloshTilt: math.cos(tau * 1.0) * size.height * (0.012 + 0.09 * energy),
      colors: [
        KrithaColors.accentLightBlue.withValues(alpha: 0.26 + 0.26 * energy),
        KrithaColors.accentBlue.withValues(alpha: 0.42 + 0.26 * energy),
      ],
    );

    _drawWaterLayer(
      canvas,
      size,
      baseFillRatio: 0.81 - energy * 0.18,
      amplitude: size.height * (idleRipple * 0.85 + 0.14 * energy),
      spatialCycles: 3.0,
      phase: tau * 2.0 + 2.6,
      sloshTilt:
          math.sin(tau * 1.0 + 1.0) * size.height * (0.010 + 0.06 * energy),
      colors: [
        KrithaColors.accentLightBlue.withValues(alpha: 0.32 + 0.28 * energy),
        KrithaColors.accentCyanBg.withValues(alpha: 0.18 + 0.20 * energy),
      ],
    );

    final glassHighlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: active ? 0.14 : 0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.36));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.36),
      glassHighlight,
    );

    canvas.restore();
  }

  void _drawWaterLayer(
    Canvas canvas,
    Size size, {
    required double baseFillRatio,
    required double amplitude,
    required double spatialCycles,
    required double phase,
    required double sloshTilt,
    required List<Color> colors,
  }) {
    final path = Path();
    final baseY = size.height * baseFillRatio;
    const steps = 40;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = t * size.width;
      final tiltOffset = (t - 0.5) * 2 * sloshTilt;
      final bump =
          math.sin(t * math.pi * 2 * spatialCycles + phase) * amplitude +
          math.cos(t * math.pi * 2 * (spatialCycles + 1.0) - phase) *
              (amplitude * 0.32);
      final y = (baseY + tiltOffset + bump).clamp(2.0, size.height - 1.0);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FishPotWaterPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.active != active ||
      (oldDelegate.audioLevel - audioLevel).abs() > 0.01;
}
