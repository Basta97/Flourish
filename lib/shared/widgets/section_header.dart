import 'package:flutter/material.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/theme/app_spacing.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Sp.screenH,
        vertical: Sp.md,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.subtitle),
              const SizedBox(height: 2),
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(Rad.full),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (trailing case final Widget widget) widget,
        ],
      ),
    );
  }
}
