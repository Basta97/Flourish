import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/theme/app_spacing.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    final reduced = Motion.reduced(context);

    Widget badge = Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            palette.accent.withValues(alpha: 0.22),
            palette.accent.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: palette.accent.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, size: 32, color: palette.accent),
    );
    if (!reduced) {
      // A slow, gentle float so the empty screen feels alive, not broken.
      badge = badge
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: -3, end: 3, duration: 2400.ms, curve: Curves.easeInOut);
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(height: Sp.xl),
        Text(
          title,
          style: AppTextStyles.title.copyWith(color: palette.textHigh),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: Sp.sm),
          Text(
            subtitle!,
            style: AppTextStyles.body.copyWith(color: palette.textLow),
            textAlign: TextAlign.center,
          ),
        ],
        if (action != null) ...[const SizedBox(height: Sp.xxl), action!],
      ],
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Sp.xxxl,
          vertical: Sp.xxxl * 2,
        ),
        child: reduced
            ? content
            : content
                  .animate()
                  .fadeIn(duration: Motion.slow, curve: Motion.enter)
                  .slideY(begin: 0.06, end: 0, curve: Motion.enter),
      ),
    );
  }
}
