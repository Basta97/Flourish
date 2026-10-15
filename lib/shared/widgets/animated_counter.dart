import 'package:flutter/material.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';

/// Counts a number up to [value] with tabular figures.
///
/// While rolling it shows an approximate double; once settled it shows
/// [exactText] when provided, so exact `Amount`s are never displayed rounded
/// through a double.
class AnimatedCounter extends StatefulWidget {
  final double value;
  final String currency;
  final TextStyle? style;
  final bool showSign;
  final Duration duration;

  /// Custom formatter for intermediate values. Defaults to
  /// [CurrencyFormatter.format] with [currency].
  final String Function(double value)? format;

  /// Exact text shown once the animation finishes.
  final String? exactText;

  /// Optional percentage change shown as a ▲/▼ chip after the number.
  final double? deltaPercent;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.currency = 'USD',
    this.style,
    this.showSign = false,
    this.duration = Motion.countUp,
    this.format,
    this.exactText,
    this.deltaPercent,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = _tween(0, widget.value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Motion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  Animation<double> _tween(double from, double to) => Tween<double>(
    begin: from,
    end: to,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = _tween(_animation.value, widget.value);
      if (Motion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(double v) =>
      widget.format?.call(v) ??
      CurrencyFormatter.format(
        v,
        currency: widget.currency,
        showSign: widget.showSign,
      );

  @override
  Widget build(BuildContext context) {
    final style = (widget.style ?? AppTextStyles.number).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final counter = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final done = _controller.isCompleted;
          final text = done && widget.exactText != null
              ? widget.exactText!
              : _format(_animation.value);
          return Text(text, style: style, maxLines: 1);
        },
      ),
    );

    // The row is intrinsic so it works under unbounded constraints; callers
    // bound the width (e.g. with a FittedBox).
    final delta = widget.deltaPercent;
    if (delta == null || !delta.isFinite) return counter;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        counter,
        const SizedBox(width: 10),
        DeltaChip(percent: delta),
      ],
    );
  }
}

/// "▲ 2.4%" pill tinted by direction.
class DeltaChip extends StatelessWidget {
  const DeltaChip({super.key, required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    final up = percent >= 0;
    final tone = up ? palette.income : palette.expense;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${up ? '▲' : '▼'} ${percent.abs().toStringAsFixed(1)}%',
        style: AppTextStyles.caption.copyWith(
          color: tone,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
