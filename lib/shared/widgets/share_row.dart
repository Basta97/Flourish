import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'pressable.dart';

/// Legend row: color dot, label, amount, and a share bar that fills in.
class ShareRow extends StatelessWidget {
  const ShareRow({
    super.key,
    required this.label,
    required this.value,
    required this.share,
    required this.color,
    this.highlighted = false,
    this.showBar = true,
    this.onTap,
  });

  final String label;
  final String value;
  final double share;
  final Color color;
  final bool highlighted;
  final bool showBar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    final row = AnimatedContainer(
      duration: Motion.of(context, Motion.base),
      curve: Motion.morph,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.sm),
      decoration: BoxDecoration(
        color: highlighted ? color.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(Rad.sm),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: palette.textHigh,
                  ),
                ),
              ),
              Text(
                '${(share * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.caption.copyWith(color: palette.textLow),
              ),
              const SizedBox(width: Sp.md),
              Text(
                value,
                style: AppTextStyles.numberSmall.copyWith(
                  color: palette.textHigh,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: palette.textLow,
                ),
              ],
            ],
          ),
          if (showBar) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(Rad.full),
              child: SizedBox(
                height: 4,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: share.clamp(0, 1)),
                  duration: Motion.of(
                    context,
                    const Duration(milliseconds: 900),
                  ),
                  curve: Motion.enter,
                  builder: (context, v, _) => Stack(
                    children: [
                      Container(color: palette.stroke),
                      FractionallySizedBox(
                        widthFactor: v,
                        child: Container(color: color),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return onTap == null
        ? row
        : Pressable(onTap: onTap, scale: 0.98, child: row);
  }
}
