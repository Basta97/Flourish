import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_spacing.dart';

/// Tint for a spend-against-limit ratio: [base] while comfortably under,
/// amber from 75%, coral once over.
Color limitTone(BuildContext context, double ratio, Color base) {
  final palette = FlourishPalette.of(context);
  if (ratio >= 1) return palette.expense;
  if (ratio >= 0.75) return palette.warning;
  return base;
}

/// Circular progress that sweeps in from zero on first build and glides to
/// new values afterwards. The color cross-fades along with the value.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 64,
    this.stroke = 6,
    this.child,
    this.semanticsLabel,
  });

  /// 0..1; values above 1 draw a full ring.
  final double value;
  final Color color;
  final double size;
  final double stroke;
  final Widget? child;

  /// Read by screen readers instead of the ring's contents.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final track = FlourishPalette.of(context).stroke;
    final ring = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: Motion.of(context, const Duration(milliseconds: 1100)),
      curve: Motion.enter,
      builder: (context, v, _) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: Motion.of(context, Motion.slow),
        builder: (context, tint, _) => SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: v,
              color: tint ?? color,
              track: track,
              stroke: stroke,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      // Isolate the per-frame sweep from the surrounding card.
      child: RepaintBoundary(child: ring),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - stroke / 2,
    );
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        // Rotated so the gradient starts at 12 o'clock with the arc.
        ..shader = SweepGradient(
          colors: [color.withValues(alpha: 0.55), color],
          stops: [0, progress.clamp(0.01, 1)],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}

/// Rounded linear progress that fills in on first build and glides to new
/// values. Over-limit values fill the bar and keep the over color.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final track = FlourishPalette.of(context).stroke;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Rad.full),
      child: SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1)),
          duration: Motion.of(context, const Duration(milliseconds: 1000)),
          curve: Motion.enter,
          builder: (context, v, _) => Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: track)),
              FractionallySizedBox(
                widthFactor: v,
                child: AnimatedContainer(
                  duration: Motion.of(context, Motion.slow),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Rad.full),
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.65), color],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
