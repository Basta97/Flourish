import 'package:flutter/material.dart';
import 'package:flourish/core/theme/app_colors.dart';

/// The page canvas. Flat, and the same color as the app bar and every other
/// scaffold, so pushed pages never show a seam or a different tint.
class LiquidPageBackground extends StatelessWidget {
  const LiquidPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppColors.surface(context), child: child);
  }
}
