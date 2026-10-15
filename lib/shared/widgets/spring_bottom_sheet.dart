import 'package:flutter/material.dart';
import 'package:flourish/core/motion/motion.dart';

/// Shows a modal bottom sheet that rises on a spring, with a dimmed backdrop
/// and a light haptic on open. Collapses to a quick linear rise under
/// reduce-motion.
Future<T?> showSpringBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final reduced = Motion.reduced(context);
  Haptics.tap();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    // Sheets opened from inside a tab page must sit above the floating nav
    // bar, which lives outside the tab navigator.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    elevation: 0,
    sheetAnimationStyle: AnimationStyle(
      duration: reduced ? Motion.fast : const Duration(milliseconds: 520),
      reverseDuration: Motion.base,
      curve: reduced ? Curves.linear : Motion.springGentle,
      reverseCurve: Curves.easeInCubic,
    ),
    builder: builder,
  );
}
