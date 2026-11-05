import 'package:flutter/material.dart';
import 'package:flourish/core/motion/motion.dart';

/// Apple-style chart draw-in animation wrapper.
/// Animates the child widget with a fade-in + slight scale-up effect.
/// Ideal for fl_chart widgets to make them feel alive on entry.
class AnimatedChart extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const AnimatedChart({
    super.key,
    required this.child,
    this.duration = Motion.chart,
  });

  @override
  State<AnimatedChart> createState() => _AnimatedChartState();
}

class _AnimatedChartState extends State<AnimatedChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Motion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Transitions animate on the compositor without rebuilding the chart,
    // and the boundary keeps chart repaints from spreading to the page.
    return FadeTransition(
      opacity: _animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(_animation),
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}
