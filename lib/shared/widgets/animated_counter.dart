import 'package:flutter/material.dart';
import '../../core/utils/currency_formatter.dart';

class AnimatedCounter extends StatefulWidget {
  final double value;
  final String currency;
  final TextStyle? style;
  final bool showSign;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.currency = 'USD',
    this.style,
    this.showSign = false,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _displayValue = 0;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: _displayValue, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _animation.addListener(() {
      setState(() => _displayValue = _animation.value);
    });
    if (widget.value != 0) _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.reset();
      _animation = Tween<double>(begin: _displayValue, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      CurrencyFormatter.format(_displayValue, currency: widget.currency, showSign: widget.showSign),
      style: widget.style,
    );
  }
}
