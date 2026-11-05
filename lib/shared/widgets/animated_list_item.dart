import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flourish/core/motion/motion.dart';

/// Staggered list entry: a fade with a short rise.
/// Use inside `ListView.builder` itemBuilder. The stagger is capped at
/// [Motion.maxStaggered] items so long lists stay snappy, and the effect is
/// skipped for rows built mid-scroll and when the OS asks to reduce motion.
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
    if (Motion.reduced(context) || _scrolledInto(context)) return child;
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

/// Lazy lists build items as they scroll into view; only the first screen
/// gets the entrance, so scrolling never replays fades row by row.
bool _scrolledInto(BuildContext context) {
  final position = Scrollable.maybeOf(context)?.position;
  // Extents are unknown until the viewport's first layout: that's the first
  // screen, so it animates.
  return position != null &&
      position.hasPixels &&
      position.hasContentDimensions &&
      position.pixels > position.minScrollExtent + 1;
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
