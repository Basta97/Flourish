import 'package:flutter/material.dart';
import 'package:flourish/core/motion/motion.dart';

/// Springs its child down while a finger is on it and back with a slight
/// overshoot on release. It only listens to pointers, so the wrapped
/// button keeps its own tap handling, ripple, tooltip and semantics.
class TapBounce extends StatefulWidget {
  const TapBounce({super.key, required this.child, this.scale = 0.82});

  final Widget child;

  /// Scale while pressed.
  final double scale;

  @override
  State<TapBounce> createState() => _TapBounceState();
}

class _TapBounceState extends State<TapBounce> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed && !Motion.reduced(context) ? widget.scale : 1,
        duration: _pressed ? Motion.fast : Motion.slow,
        curve: _pressed ? Curves.easeOutCubic : Motion.settle,
        child: widget.child,
      ),
    );
  }
}
