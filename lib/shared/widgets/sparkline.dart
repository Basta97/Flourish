import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/core/theme/app_colors.dart';

/// Minimal line chart that draws itself in from left to right with a soft
/// gradient fill underneath. No axes, no grid; for trend-at-a-glance only.
class Sparkline extends StatefulWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.color,
    this.height = 56,
    this.strokeWidth = 2.2,
  });

  final List<double> values;
  final Color? color;
  final double height;
  final double strokeWidth;

  @override
  State<Sparkline> createState() => _SparklineState();
}

class _SparklineState extends State<Sparkline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Motion.reduced(context) ? _reveal.value = 1 : _reveal.forward();
    });
  }

  @override
  void didUpdateWidget(Sparkline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values.length != widget.values.length &&
        !Motion.reduced(context)) {
      _reveal.forward(from: 0.35);
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? FlourishPalette.of(context).accent;
    final values = widget.values;
    if (values.length < 2) return SizedBox(height: widget.height);

    var minY = values.reduce((a, b) => a < b ? a : b);
    var maxY = values.reduce((a, b) => a > b ? a : b);
    if (maxY == minY) {
      maxY += 1;
      minY -= 1;
    }
    final pad = (maxY - minY) * 0.12;

    final chart = LineChart(
      duration: Motion.slow,
      curve: Motion.enter,
      LineChartData(
        minX: 0,
        maxX: (values.length - 1).toDouble(),
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        clipData: const FlClipData.all(),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values[i]),
            ],
            isCurved: true,
            curveSmoothness: 0.32,
            preventCurveOverShooting: true,
            color: color,
            barWidth: widget.strokeWidth,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, bar) => spot.x == bar.spots.last.x,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3.5,
                color: color,
                strokeWidth: 3,
                strokeColor: color.withValues(alpha: 0.25),
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.28),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      height: widget.height,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _reveal,
          builder: (context, child) => ClipRect(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: Curves.easeInOutCubic.transform(_reveal.value),
              child: child,
            ),
          ),
          child: chart,
        ),
      ),
    );
  }
}
