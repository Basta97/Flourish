import 'package:flutter/material.dart';
import 'package:bastasaving/core/theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? height;
  final double? width;
  final List<Color>? gradient;
  final double borderRadius;
  final VoidCallback? onTap;
  final double elevation;
  final Color? bgColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.height,
    this.width,
    this.gradient,
    this.borderRadius = 16,
    this.onTap,
    this.elevation = 4,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = gradient != null
        ? Colors.transparent
        : (bgColor ?? (isDark ? AppColors.cardDark : AppColors.cardLight));

    final card = Container(
      height: height,
      width: width,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: gradient != null ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient!,
        ) : null,
        color: gradient != null ? null : backgroundColor,
        border: gradient == null
            ? Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: (gradient != null ? gradient!.first : (isDark ? Colors.black : Colors.grey.shade300))
                .withValues(alpha: isDark ? 0.35 : 0.1),
            blurRadius: elevation * 4,
            offset: Offset(0, elevation),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          child: card,
        ),
      );
    }

    return card;
  }
}
