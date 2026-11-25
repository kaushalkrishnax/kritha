import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme.dart';

/// Transparent glass fish-pot pill with fluid bumping water waves for Live Talk.
class LiveTalkPill extends StatefulWidget {
  const LiveTalkPill({
    super.key,
    required this.active,
    this.audioLevel = 0.0,
  });

  /// Listening and speaking animate; paused settles to calm water.
  final bool active;

  /// Normalized voice/audio amplitude (0..1) driving wave bump intensity.
  final double audioLevel;

  @override
  State<LiveTalkPill> createState() => _LiveTalkPillState();
}

class _LiveTalkPillState extends State<LiveTalkPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
    value: 0.25,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(LiveTalkPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active) {
      _flow.repeat();
    } else {
      _flow
        ..stop()
        ..value = 0.25;
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('live-talk-pill'),
      width: KrithaDimensions.liveTalkPillMaxWidth,
      height: KrithaDimensions.liveTalkPillHeight,
      decoration: BoxDecoration(
        color: KrithaColors.bgDeepest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(KrithaRadius.xl),
        border: Border.all(
          color: KrithaColors.accentLightBlue.withValues(
            alpha: widget.active ? 0.34 : 0.14,
          ),
        ),
        boxShadow: [
          if (widget.active)
            BoxShadow(
              color: KrithaColors.accentBlue.withValues(
                alpha: 0.18 + widget.audioLevel * 0.20,
              ),
              blurRadius: 16,
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
            audioLevel: widget.audioLevel.clamp(0.0, 1.0),
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

    final phase = progress * math.pi * 2;
    final energy = active ? (0.35 + audioLevel * 0.65) : 0.10;

    // Back-to-front translucent water layers creating a sloshing fish-pot effect.
    _drawWaterLayer(
      canvas,
      size,
      baseFillRatio: 0.48 - energy * 0.08,
      amplitude: size.height * (0.07 + 0.14 * energy),
      frequency: 1.5,
      phase: phase + 1.8,
      sloshTilt: math.sin(phase * 0.8) * size.height * 0.07 * energy,
      colors: [
        KrithaColors.accentCyanBg.withValues(alpha: 0.24 + 0.18 * energy),
        KrithaColors.accentBlue.withValues(alpha: 0.34 + 0.20 * energy),
      ],
    );

    _drawWaterLayer(
      canvas,
      size,
      baseFillRatio: 0.56 - energy * 0.09,
      amplitude: size.height * (0.09 + 0.17 * energy),
      frequency: 2.2,
      phase: -phase * 1.15 + 0.6,
      sloshTilt: math.cos(phase * 1.1) * size.height * 0.09 * energy,
      colors: [
        KrithaColors.accentLightBlue.withValues(alpha: 0.30 + 0.24 * energy),
        KrithaColors.accentBlue.withValues(alpha: 0.46 + 0.24 * energy),
      ],
    );

    _drawWaterLayer(
      canvas,
      size,
      baseFillRatio: 0.66 - energy * 0.10,
      amplitude: size.height * (0.06 + 0.15 * energy),
      frequency: 3.0,
      phase: phase * 1.45,
      sloshTilt: math.sin(phase * 1.3 + 1.0) * size.height * 0.06 * energy,
      colors: [
        KrithaColors.accentLightBlue.withValues(alpha: 0.36 + 0.28 * energy),
        KrithaColors.accentCyanBg.withValues(alpha: 0.22 + 0.18 * energy),
      ],
    );

    // Subtle glass specular highlight along the top rim of the capsule.
    final glassHighlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: active ? 0.16 : 0.07),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.38));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.38),
      glassHighlight,
    );

    canvas.restore();
  }

  void _drawWaterLayer(
    Canvas canvas,
    Size size, {
    required double baseFillRatio,
    required double amplitude,
    required double frequency,
    required double phase,
    required double sloshTilt,
    required List<Color> colors,
  }) {
    final path = Path();
    final baseY = size.height * baseFillRatio;
    const steps = 36;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = t * size.width;
      final tiltOffset = (t - 0.5) * 2 * sloshTilt;
      final bump =
          math.sin(t * math.pi * 2 * frequency + phase) * amplitude +
          math.cos(t * math.pi * 2 * (frequency + 0.7) - phase * 0.8) *
              (amplitude * 0.35);
      final y = (baseY + tiltOffset + bump).clamp(2.0, size.height - 2.0);
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
