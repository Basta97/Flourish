import 'package:flutter/material.dart';
import 'package:flourish/core/motion/motion.dart';

/// Spring-scale + haptic tap feedback for any widget.
///
/// Prefer this over bare `GestureDetector`s for tappable tiles, chips and
/// buttons so every touch in the app feels the same.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.haptic = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale while pressed.
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value || widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) Haptics.tap();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                Haptics.select();
                widget.onLongPress!();
              },
        child: AnimatedScale(
          scale: _pressed && !reduced ? widget.scale : 1,
          duration: _pressed ? Motion.fast : Motion.base,
          curve: _pressed ? Curves.easeOutCubic : Motion.settle,
          child: AnimatedOpacity(
            opacity: _pressed ? 0.88 : 1,
            duration: Motion.fast,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
