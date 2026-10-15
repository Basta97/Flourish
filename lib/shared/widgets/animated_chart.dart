import 'package:flutter/material.dart';

/// Apple-style chart draw-in animation wrapper.
/// Animates the child widget with a fade-in + slight scale-up effect.
/// Ideal for fl_chart widgets to make them feel alive on entry.
class AnimatedChart extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const AnimatedChart({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 700),
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
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Transform.scale(
            scale: 0.96 + (_animation.value * 0.04),
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
