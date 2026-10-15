import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Shared motion tokens. Every animated widget reads durations, curves and
/// springs from here so the app moves with one consistent rhythm.
class Motion {
  Motion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 450);
  static const Duration countUp = Duration(milliseconds: 900);
  static const Duration stagger = Duration(milliseconds: 40);

  /// Entries and reveals.
  static const Curve enter = Curves.easeOutQuint;

  /// Shape and position morphs.
  static const Curve morph = Curves.easeInOutCubic;

  /// Slight overshoot for playful-but-calm settles.
  static const Curve settle = Curves.easeOutBack;

  static const SpringDescription snappy = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 34,
  );

  static const SpringDescription gentle = SpringDescription(
    mass: 1,
    stiffness: 260,
    damping: 28,
  );

  /// Spring curves for APIs that take a [Curve] (implicit animations, sheets).
  static final Curve springSnappy = SpringCurve(snappy);
  static final Curve springGentle = SpringCurve(gentle);

  /// Maximum number of list items that get a staggered entrance; anything
  /// beyond appears with the last delay so long lists never lag.
  static const int maxStaggered = 8;

  /// True when the user asked the OS to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero when reduce-motion is on.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;

  static Duration staggerDelay(int index) =>
      stagger * (index < maxStaggered ? index : maxStaggered);
}

/// Semantic haptics so call sites describe intent rather than intensity.
class Haptics {
  Haptics._();

  static void tap() => HapticFeedback.lightImpact();
  static void select() => HapticFeedback.selectionClick();
  static void success() => HapticFeedback.mediumImpact();
  static void warning() => HapticFeedback.heavyImpact();
}

/// A [Curve] driven by a critically-tuned spring, for APIs that only accept
/// curves (route transitions, sheets). Normalised so it ends at exactly 1.
class SpringCurve extends Curve {
  SpringCurve([this.spring = Motion.gentle]);

  final SpringDescription spring;

  // The simulation runs for this long in "spring time"; t∈[0,1] maps onto it.
  static const double _span = 0.9;

  late final SpringSimulation _sim = SpringSimulation(spring, 0, 1, 0);

  @override
  double transformInternal(double t) => _sim.x(t * _span) / _sim.x(_span);
}
