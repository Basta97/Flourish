import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(
    double amount, {
    String currency = 'USD',
    bool showSign = false,
  }) {
    final formatter = NumberFormat.currency(
      symbol: symbolFor(currency),
      decimalDigits: currency == 'JPY' || currency == 'KRW'
          ? 0
          : ['KWD', 'BHD', 'OMR'].contains(currency)
          ? 3
          : 2,
    );
    final formatted = formatter.format(amount.abs());
    if (showSign && amount != 0) {
      return amount < 0 ? '-$formatted' : '+$formatted';
    }
    return amount < 0 ? '-$formatted' : formatted;
  }

  static String formatCompact(double amount, {String currency = 'USD'}) {
    final symbol = symbolFor(currency);
    final abs = amount.abs();
    if (abs >= 1000000) {
      return '$symbol${(abs / 1000000).toStringAsFixed(1)}M';
    } else if (abs >= 1000) {
      return '$symbol${(abs / 1000).toStringAsFixed(1)}K';
    }
    return format(amount, currency: currency);
  }

  static String symbolFor(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CNY':
        return '¥';
      case 'INR':
        return '₹';
      case 'IDR':
        return 'Rp';
      case 'MYR':
        return 'RM';
      case 'SAR':
        return '﷼';
      case 'AED':
        return 'د.إ';
      case 'EGP':
        return 'EGP ';
      default:
        return '$currency ';
    }
  }
}
