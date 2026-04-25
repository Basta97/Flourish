import 'package:flutter/material.dart';

class CategoryIconWidget extends StatelessWidget {
  final String iconName;
  final Color color;
  final double size;
  final double iconSize;

  const CategoryIconWidget({
    super.key,
    required this.iconName,
    required this.color,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(
        _iconData(iconName),
        color: color,
        size: iconSize,
      ),
    );
  }

  IconData _iconData(String name) {
    switch (name) {
      case 'payments': return Icons.payments;
      case 'laptop': return Icons.laptop;
      case 'trending_up': return Icons.trending_up;
      case 'restaurant': return Icons.restaurant;
      case 'directions_car': return Icons.directions_car;
      case 'shopping_bag': return Icons.shopping_bag;
      case 'receipt_long': return Icons.receipt_long;
      case 'movie': return Icons.movie;
      case 'favorite': return Icons.favorite;
      case 'school': return Icons.school;
      case 'home': return Icons.home;
      case 'more_horiz': return Icons.more_horiz;
      case 'account_balance': return Icons.account_balance;
      case 'account_balance_wallet': return Icons.account_balance_wallet;
      case 'credit_card': return Icons.credit_card;
      case 'savings': return Icons.savings;
      case 'wallet': return Icons.wallet;
      case 'currency_exchange': return Icons.currency_exchange;
      case 'monetization_on': return Icons.monetization_on;
      default: return Icons.circle;
    }
  }
}
