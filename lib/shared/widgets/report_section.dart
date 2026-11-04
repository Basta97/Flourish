import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_card.dart';

class ReportSection extends StatelessWidget {
  const ReportSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.subtitle.copyWith(color: palette.textHigh),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: Sp.xs),
            Text(
              subtitle!,
              style: AppTextStyles.caption.copyWith(
                color: palette.textLow,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: Sp.md),
          child,
        ],
      ),
    );
  }
}

class MutedText extends StatelessWidget {
  const MutedText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Sp.sm),
    child: Text(
      text,
      style: AppTextStyles.body.copyWith(
        color: FlourishPalette.of(context).textLow,
      ),
    ),
  );
}

class NoticeBanner extends StatelessWidget {
  const NoticeBanner(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = FlourishPalette.of(context).warning;
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: tone.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: tone),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(color: tone),
            ),
          ),
        ],
      ),
    );
  }
}

class ValueRow extends StatelessWidget {
  const ValueRow(this.label, this.value, {super.key, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(color: palette.textHigh),
            ),
          ),
          const SizedBox(width: Sp.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.numberSmall.copyWith(
                color: tone ?? palette.textHigh,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
