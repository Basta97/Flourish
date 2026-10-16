import 'package:flutter/material.dart';

class IconUtils {
  IconUtils._();

  static IconData accountIcon(String name) {
    switch (name) {
      case 'account_balance':
        return Icons.account_balance;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'credit_card':
        return Icons.credit_card;
      case 'savings':
        return Icons.savings;
      case 'wallet':
        return Icons.wallet;
      case 'payments':
        return Icons.payments;
      case 'currency_exchange':
        return Icons.currency_exchange;
      case 'monetization_on':
        return Icons.monetization_on;
      default:
        return Icons.account_balance_wallet;
    }
  }

  static IconData categoryIcon(String name) {
    switch (name) {
      case 'payments':
        return Icons.payments;
      case 'laptop':
        return Icons.laptop;
      case 'trending_up':
        return Icons.trending_up;
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'flight':
        return Icons.flight;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'receipt_long':
        return Icons.receipt_long;
      case 'movie':
        return Icons.movie;
      case 'favorite':
        return Icons.favorite;
      case 'school':
        return Icons.school;
      case 'home':
        return Icons.home;
      case 'more_horiz':
        return Icons.more_horiz;
      case 'account_balance':
        return Icons.account_balance;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'credit_card':
        return Icons.credit_card;
      case 'savings':
        return Icons.savings;
      case 'wallet':
        return Icons.wallet;
      case 'currency_exchange':
        return Icons.currency_exchange;
      case 'monetization_on':
        return Icons.monetization_on;
      case 'north_east':
        return Icons.north_east_rounded;
      case 'south_west':
        return Icons.south_west_rounded;
      case 'swap_horiz':
        return Icons.swap_horiz_rounded;
      case 'percent':
        return Icons.percent_rounded;
      case 'undo':
        return Icons.undo_rounded;
      default:
        return Icons.circle;
    }
  }
}
