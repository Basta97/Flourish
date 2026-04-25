import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';

class AmountText extends StatelessWidget {
  final double amount;
  final String currency;
  final bool compact;
  final bool showColor;

  const AmountText({
    super.key,
    required this.amount,
    this.currency = 'USD',
    this.compact = false,
    this.showColor = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = showColor
        ? (amount >= 0 ? AppColors.income : AppColors.expense)
        : null;
    return Text(
      compact
          ? CurrencyFormatter.formatCompact(amount, currency: currency)
          : CurrencyFormatter.format(amount, currency: currency, showSign: true),
      style: AppTextStyles.numberMono.copyWith(
        color: color,
        fontSize: 14,
      ),
    );
  }
}
