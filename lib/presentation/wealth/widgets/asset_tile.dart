import 'package:flutter/material.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/domain/finance/models.dart';
import 'package:flourish/shared/widgets/animated_list_item.dart';
import 'package:flourish/shared/widgets/pressable.dart';

/// Icon and tint for each asset class.
(IconData, Color) assetStyle(AssetKind kind) => switch (kind) {
  AssetKind.gold => (Icons.workspace_premium_rounded, const Color(0xFFE8C46E)),
  AssetKind.stock => (Icons.show_chart_rounded, const Color(0xFF5B9DF5)),
  AssetKind.fund => (Icons.pie_chart_outline_rounded, const Color(0xFF8B7CF6)),
  AssetKind.crypto => (Icons.currency_bitcoin_rounded, const Color(0xFFF4A261)),
  AssetKind.property => (Icons.home_work_outlined, const Color(0xFF3CC8C0)),
  AssetKind.custom => (Icons.category_outlined, const Color(0xFF8A94A6)),
};

/// Icon and tint for each contract kind; debts read coral, assets jade.
(IconData, Color) contractStyle(ContractKind kind) => switch (kind) {
  ContractKind.deposit => (Icons.savings_outlined, AppColors.income),
  ContractKind.certificate => (
    Icons.workspace_premium_outlined,
    AppColors.income,
  ),
  ContractKind.receivable => (Icons.call_received_rounded, AppColors.income),
  ContractKind.loan => (Icons.account_balance_outlined, AppColors.expense),
  ContractKind.creditCard => (Icons.credit_card_rounded, AppColors.expense),
};

/// A row in a grouped Wealth list: tinted icon, title + detail lines, and a
/// right-aligned value with an optional secondary line.
class AssetTile extends StatelessWidget {
  const AssetTile({
    super.key,
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.value,
    this.secondary,
    this.valueTone,
    this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final String value;
  final String? secondary;
  final Color? valueTone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: tint, size: 20),
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: palette.textHigh,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: palette.textLow,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Sp.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: AppTextStyles.numberSmall.copyWith(
                        color: valueTone ?? palette.textHigh,
                      ),
                    ),
                  ),
                  if (secondary != null) ...[
                    const SizedBox(height: Sp.xs),
                    Text(
                      secondary!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: palette.textLow,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rows grouped in one surface card with hairline dividers, staggering in.
class AssetGroup extends StatelessWidget {
  const AssetGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Rad.lg),
        border: Border.all(color: palette.stroke),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Rad.lg),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++)
              AnimatedListItem(
                key: children[i].key,
                index: i,
                child: Column(
                  children: [
                    if (i > 0)
                      Divider(height: 1, indent: 70, color: palette.stroke),
                    children[i],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Short explanatory note shown above a Wealth list or when it is empty.
class WealthHint extends StatelessWidget {
  const WealthHint(this.text, {super.key, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: palette.textLow),
        const SizedBox(width: Sp.sm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: palette.textLow,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
