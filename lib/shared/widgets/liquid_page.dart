import 'package:flutter/material.dart';
import 'package:flourish/core/theme/app_colors.dart';

class LiquidPageBackground extends StatelessWidget {
  const LiquidPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? AppColors.gradientBackdropDark
              : AppColors.gradientBackdropLight,
        ),
      ),
      child: child,
    );
  }
}
