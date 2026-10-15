import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flourish/core/motion/motion.dart';

/// Staggered list entry: a fade with a short rise.
/// Use inside `ListView.builder` itemBuilder. The stagger is capped at
/// [Motion.maxStaggered] items so long lists stay snappy, and the effect is
/// skipped entirely when the OS asks to reduce motion.
class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final double slideBegin;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = Duration.zero,
    this.duration = Motion.slow,
    this.slideBegin = 0.08,
  });

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return child
        .animate(delay: delay + Motion.staggerDelay(index))
        .fadeIn(duration: duration, curve: Motion.enter)
        .slideY(
          begin: slideBegin,
          end: 0,
          duration: duration,
          curve: Motion.enter,
        );
  }
}

/// Fades a whole body in with a slight rise. Useful for async content.
class AnimatedBody extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const AnimatedBody({
    super.key,
    required this.child,
    this.duration = Motion.slow,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return child
        .animate(delay: delay)
        .fadeIn(duration: duration, curve: Motion.enter)
        .slideY(begin: 0.03, end: 0, duration: duration, curve: Motion.enter);
  }
}
