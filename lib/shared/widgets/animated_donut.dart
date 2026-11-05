import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'package:fl_chart/fl_chart.dart';

/// Donut that sweeps in on first build; tapping a slice pops it outward and
/// shows its amount in the middle.
class AnimatedDonut extends StatelessWidget {
  const AnimatedDonut({
    super.key,
    required this.values,
    required this.colors,
    required this.touched,
    required this.onTouch,
    required this.center,
    required this.centerLabel,
  });

  final List<double> values;
  final List<Color> colors;
  final int? touched;
  final ValueChanged<int?> onTouch;
  final String center;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, Motion.chart),
      curve: Motion.enter,
      builder: (context, t, _) => Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: t.clamp(0, 1),
            child: PieChart(
              // fl_chart's own tween would restart every frame of the
              // sweep, so it only runs once the sweep has settled.
              duration: t < 1 ? Duration.zero : Motion.of(context, Motion.base),
              curve: Motion.springSnappy,
              PieChartData(
                startDegreeOffset: -90 - 140 * (1 - t),
                sectionsSpace: 2,
                centerSpaceRadius: 58,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (event is! FlTapUpEvent) return;
                    final i = response?.touchedSection?.touchedSectionIndex;
                    Haptics.select();
                    onTouch(i == null || i < 0 || i == touched ? null : i);
                  },
                ),
                sections: [
                  for (var i = 0; i < values.length; i++)
                    PieChartSectionData(
                      value: values[i],
                      color: colors[i],
                      title: '',
                      radius: (touched == i ? 30.0 : 22.0) * t,
                    ),
                ],
              ),
            ),
          ),
          IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.eyebrow.copyWith(
                    fontSize: 10,
                    color: palette.textLow,
                  ),
                ),
                const SizedBox(height: 2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 104),
                  child: FittedBox(
                    child: Text(
                      center,
                      style: AppTextStyles.number.copyWith(
                        color: palette.textHigh,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
