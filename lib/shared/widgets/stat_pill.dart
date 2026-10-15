import 'package:flutter/material.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/shared/widgets/animated_counter.dart';
import 'package:flourish/shared/widgets/shimmer_loading.dart';

/// Compact metric tile: tinted icon, label, and an amount that counts up.
/// Pass `value: null` to show a skeleton while data loads.
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.label,
    required this.icon,
    required this.tone,
    required this.value,
    this.exactText,
    this.format,
  });

  final String label;
  final IconData icon;
  final Color tone;
  final double? value;
  final String? exactText;
  final String Function(double value)? format;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.md + 2),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Rad.lg),
        border: Border.all(color: palette.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(Rad.sm + 2),
            ),
            child: Icon(icon, size: 17, color: tone),
          ),
          const SizedBox(height: Sp.md),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: palette.textLow),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Sp.xs),
          SizedBox(
            height: 22,
            child: value == null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: ShimmerLoading.block(width: 64, height: 16),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedCounter(
                      value: value!,
                      exactText: exactText,
                      format: format,
                      style: AppTextStyles.number.copyWith(
                        color: palette.textHigh,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
