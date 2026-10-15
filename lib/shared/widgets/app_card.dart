import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/shared/widgets/pressable.dart';

/// Layered surface: soft fill, hairline stroke with a lighter top edge, and a
/// long low shadow. Tappable cards get spring + haptic feedback.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? height;
  final double? width;
  final List<Color>? gradient;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? bgColor;
  final bool outlined;
  final double blur;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.height,
    this.width,
    this.gradient,
    this.borderRadius = Rad.lg,
    this.onTap,
    this.bgColor,
    this.outlined = false,
    this.blur = 0,
  });

  const AppCard.gradient({
    super.key,
    required this.child,
    required this.gradient,
    this.padding,
    this.margin,
    this.height,
    this.width,
    this.borderRadius = Rad.lg,
    this.onTap,
    this.bgColor,
    this.outlined = false,
    this.blur = 0,
  });

  const AppCard.outlined({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.height,
    this.width,
    this.borderRadius = Rad.lg,
    this.onTap,
    this.bgColor,
    this.blur = 0,
  }) : gradient = null,
       outlined = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = FlourishPalette.of(context);
    final hasGradient = gradient != null;
    final radius = BorderRadius.circular(borderRadius);

    final fill = bgColor ?? palette.surface;

    // The stroke is brighter along the top edge, like light catching a lip.
    final strokeGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: hasGradient
          ? [
              Colors.white.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.04),
            ]
          : [
              palette.highlight,
              outlined ? AppColors.glassStroke(context) : palette.stroke,
            ],
    );

    final inner = Container(
      height: height,
      width: width,
      padding: padding ?? const EdgeInsets.all(Sp.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          (borderRadius - 1).clamp(0, double.infinity),
        ),
        color: hasGradient ? null : fill.withValues(alpha: blur > 0 ? 0.72 : 1),
        gradient: hasGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient!,
              )
            : null,
      ),
      child: child,
    );

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: strokeGradient,
        boxShadow: [
          BoxShadow(
            color: hasGradient
                ? gradient!.first.withValues(alpha: isDark ? 0.28 : 0.18)
                : AppColors.shadow(context),
            blurRadius: hasGradient ? 32 : 24,
            spreadRadius: -6,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          (borderRadius - 1).clamp(0, double.infinity),
        ),
        child: blur > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: inner,
              )
            : inner,
      ),
    );

    if (onTap != null) {
      card = Pressable(onTap: onTap, scale: 0.975, child: card);
    }
    return card;
  }
}
