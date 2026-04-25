import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Text(title, style: AppTextStyles.bodySemiBold.copyWith(fontSize: 16)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
