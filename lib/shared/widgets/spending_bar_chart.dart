import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'animated_chart.dart';

/// Vertical bars with a few bottom labels and a tap tooltip. With [secondary]
/// each slot shows two bars side by side (e.g. income next to spending).
class SpendingBarChart extends StatelessWidget {
  const SpendingBarChart({
    super.key,
    required this.values,
    required this.color,
    required this.label,
    required this.tooltip,
    this.secondary,
    this.secondaryColor,
    this.highlight,
    this.labelEvery = 1,
    this.height = 160,
  });

  final List<double> values;
  final Color color;
  final List<double>? secondary;
  final Color? secondaryColor;

  /// Bottom label for slot i; only every [labelEvery]th is drawn.
  final String Function(int i) label;
  final String Function(int i, double value) tooltip;

  /// Slot drawn at full strength (e.g. today); others are dimmed after it.
  final int? highlight;
  final int labelEvery;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    final top = [...values, ...?secondary].fold(0.0, (a, b) => a > b ? a : b);
    final width = secondary == null ? (values.length > 20 ? 6.0 : 14.0) : 9.0;
    Color tint(Color c, int i) =>
        highlight != null && i > highlight! ? c.withValues(alpha: 0.25) : c;
    return AnimatedChart(
      child: SizedBox(
        height: height,
        child: BarChart(
          duration: Motion.of(context, Motion.base),
          BarChartData(
            maxY: top <= 0 ? 1 : top * 1.15,
            alignment: BarChartAlignment.spaceBetween,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: top <= 0 ? 1 : top / 2,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: palette.stroke, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i % labelEvery != 0 && i != values.length - 1) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        label(i),
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          color: palette.textLow,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => palette.raised,
                getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                  tooltip(group.x, rod.toY),
                  AppTextStyles.caption.copyWith(color: palette.textHigh),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < values.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 2,
                  barRods: [
                    if (secondary != null)
                      BarChartRodData(
                        toY: secondary![i],
                        width: width,
                        color: tint(secondaryColor ?? palette.income, i),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    BarChartRodData(
                      toY: values[i],
                      width: width,
                      color: tint(color, i),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
