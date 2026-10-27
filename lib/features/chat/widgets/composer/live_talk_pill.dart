import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme.dart';

/// Glowing visual indicator for the active Live Talk session.
class LiveTalkPill extends StatefulWidget {
  const LiveTalkPill({super.key, required this.active});

  /// Listening and speaking phases animate; paused keeps a dim static glow.
  final bool active;

  @override
  State<LiveTalkPill> createState() => _LiveTalkPillState();
}

class _LiveTalkPillState extends State<LiveTalkPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 2400),
    value: 0.3,
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
        ..value = 0.3;
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
      key: ValueKey('live-talk-pill'),
      width: KrithaDimensions.liveTalkPillMaxWidth,
      height: KrithaDimensions.liveTalkPillHeight,
      decoration: BoxDecoration(
        color: KrithaColors.bgDeepest,
        borderRadius: BorderRadius.circular(KrithaRadius.xl),
        border: Border.all(color: KrithaColors.borderFaint),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _flow,
        builder: (context, child) => CustomPaint(
          painter: _LiveTalkGlowPainter(
            progress: _flow.value,
            active: widget.active,
          ),
        ),
      ),
    );
  }
}

class _LiveTalkGlowPainter extends CustomPainter {
  const _LiveTalkGlowPainter({required this.progress, required this.active});

  final double progress;
  final bool active;

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
    // Intensity breathes with the flow instead of jumping between frames. The
    // paused state keeps a small residual glow so the pill never disappears.
    final energy = active ? 0.55 + 0.20 * math.sin(phase) : 0.18;

    // Three overlapping soft blobs move at different frequencies; together
    // they read as a fluid blue glow rising from the bottom of the pill.
    for (var index = 0; index < 3; index++) {
      final offset = index * 2.15;
      final centre = Offset(
        size.width * (0.24 + index * 0.27) +
            math.sin(phase * 1.25 + offset) * size.width * 0.10,
        size.height * (0.82 + math.cos(phase + offset) * 0.06),
      );
      final radius =
          size.height * (0.38 + 0.10 * math.sin(phase * 0.8 + offset)) +
          size.width * 0.10 * energy;
      final glow = RadialGradient(
        colors: [
          KrithaColors.accentLightBlue.withValues(alpha: 0.40 * energy),
          KrithaColors.accentBlue.withValues(alpha: 0.26 * energy),
          KrithaColors.accentCyanBg.withValues(alpha: 0.12 * energy),
          Colors.transparent,
        ],
        stops: [0.0, 0.35, 0.72, 1.0],
      ).createShader(Rect.fromCircle(center: centre, radius: radius));
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = glow
          ..blendMode = BlendMode.plus,
      );
    }

    // A restrained audio-level wave across the middle. Its amplitude and
    // opacity follow [energy], so the listening pulse is visible without
    // turning the pill into an equalizer.
    final amplitude = active ? 1.6 + energy * 6.4 : 1.2;
    final wave = Path();
    for (double x = 0; x <= size.width; x += 1.5) {
      final t = x / size.width;
      final y =
          size.height * 0.5 +
          math.sin(t * math.pi * 4 + phase) * amplitude * 0.55 +
          math.sin(t * math.pi * 9 - phase * 1.6) * amplitude * 0.25;
      if (x == 0) {
        wave.moveTo(x, y);
      } else {
        wave.lineTo(x, y);
      }
    }
    final waveAlpha = active ? 1.0 : 0.45;
    for (final layer in [
      (width: 8.0, alpha: 0.06),
      (width: 4.0, alpha: 0.14),
      (width: 1.6, alpha: 0.72),
    ]) {
      canvas.drawPath(
        wave,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = layer.width
          ..strokeCap = StrokeCap.round
          ..color = KrithaColors.accentLightBlue.withValues(
            alpha: layer.alpha * waveAlpha,
          ),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiveTalkGlowPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.active != active;
}
