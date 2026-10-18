import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'pressable.dart';

/// iOS-style inset group: a small caps label above one rounded card whose
/// rows are separated by hairlines.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: Sp.lg,
              bottom: Sp.sm,
            ),
            child: Text(
              title.toUpperCase(),
              style: AppTextStyles.eyebrow.copyWith(color: palette.textLow),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(Rad.lg),
              border: Border.all(color: palette.stroke),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Rad.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0 && children[i] is SettingsTile)
                      Divider(height: 1, indent: 62, color: palette.stroke),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final Color? tint;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.tint,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    final color = tint ?? palette.accent;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: titleColor ?? palette.textHigh,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: palette.textLow,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
          if (onTap != null && trailing == null)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: palette.textLow.withValues(alpha: 0.6),
            ),
        ],
      ),
    );
    return onTap == null
        ? row
        : Pressable(onTap: onTap, scale: 0.985, child: row);
  }
}
