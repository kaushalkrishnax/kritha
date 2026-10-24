import 'package:material_ui/material_ui.dart';

import '../../../../core/theme.dart';

/// Live recording waveform.
///
/// The bar construction is copied from Flexiyo's `voice_recorder_bar.dart`:
/// newest amplitudes on the right, older slots held at 0.12, 3px bars with a
/// 4px gap, 26px tall and fading in place while paused. The light-grey colour
/// matches the RN recording strip; only the surrounding chrome is Kritha's.
class RecordingWaveform extends StatefulWidget {
  const RecordingWaveform({
    super.key,
    required this.levels,
    required this.paused,
    Color? color,
    this.maxBars = KrithaDimensions.waveformMaxBars,
    this.barWidth = KrithaDimensions.waveformBarWidth,
    this.barGap = KrithaDimensions.waveformBarGap,
    this.barHeight = KrithaDimensions.waveformBarHeight,
  }) : _overrideColor = color;

  final List<double> levels;
  final bool paused;
  final Color? _overrideColor;

  Color get color => _overrideColor ?? KrithaColors.waveformBar;
  final int maxBars;
  final double barWidth;
  final double barGap;
  final double barHeight;

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 650),
    lowerBound: 0.35,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void initState() {
    super.initState();
    if (widget.paused) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(RecordingWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused == oldWidget.paused) return;
    if (widget.paused) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.barHeight + 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fitting =
              (constraints.maxWidth / (widget.barWidth + widget.barGap))
                  .floor()
                  .clamp(10, widget.maxBars);
          final bars = List<double>.from(widget.levels);
          while (bars.length < fitting) {
            bars.insert(0, 0.12);
          }
          final shown = bars.sublist(bars.length - fitting);

          return FadeTransition(
            opacity: widget.paused ? _pulse : AlwaysStoppedAnimation<double>(1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final level in shown)
                  Container(
                    width: widget.barWidth,
                    height: widget.barHeight * level.clamp(0.12, 1.0),
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(widget.barWidth / 2),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
