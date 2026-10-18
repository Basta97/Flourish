import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  /// Privacy mode: amounts render as dots. Set by the app from
  /// `hideAmountsProvider`.
  static bool hidden = false;

  /// Right-to-left UI: a leading left-to-right mark keeps the sign and symbol
  /// on the left of the digits inside Arabic text.
  static bool rtl = false;

  static const _mask = '••••';

  static String _wrap(String text) => rtl ? '\u200E$text' : text;

  static const _noDecimals = {
    'JPY', 'KRW', 'VND', 'CLP', 'ISK', 'UGX', 'PYG', 'XAF', 'XOF', 'RWF', //
  };
  static const _threeDecimals = {
    'KWD', 'BHD', 'OMR', 'JOD', 'TND', 'LYD', 'IQD', //
  };

  /// Minor-unit digits for [currency] (ISO 4217): 0 for JPY, 3 for KWD, 2 for
  /// everything else. The single source used for input, display and rounding.
  static int decimalsFor(String currency) => _noDecimals.contains(currency)
      ? 0
      : _threeDecimals.contains(currency)
      ? 3
      : 2;

  static String format(
    double amount, {
    required String currency,
    bool showSign = false,
  }) {
    if (hidden) return _wrap('${symbolFor(currency)}$_mask');
    // Latin digits and separators in every language, so amounts read the
    // same way across the app, exports and bank alerts.
    final formatter = NumberFormat.currency(
      locale: 'en',
      symbol: symbolFor(currency),
      decimalDigits: decimalsFor(currency),
    );
    final formatted = formatter.format(amount.abs());
    if (showSign && amount != 0) {
      return _wrap(amount < 0 ? '-$formatted' : '+$formatted');
    }
    return _wrap(amount < 0 ? '-$formatted' : formatted);
  }

  /// `EGP 1.2K`, `-$3.4M`; amounts under 1,000 are shown in full. The sign is
  /// always kept.
  static String formatCompact(double amount, {required String currency}) {
    final abs = amount.abs();
    if (hidden || abs < 1000) return format(amount, currency: currency);
    final sign = amount < 0 ? '-' : '';
    final symbol = symbolFor(currency);
    const units = [(1e3, 'K'), (1e6, 'M'), (1e9, 'B'), (1e12, 'T')];
    for (var i = 0; i < units.length; i++) {
      final (size, suffix) = units[i];
      final shown = (abs / size).toStringAsFixed(1);
      // 999,960 would otherwise read "1000.0K".
      if (double.parse(shown) < 1000 || i == units.length - 1) {
        return _wrap('$sign$symbol$shown$suffix');
      }
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
        return 'CN¥';
      case 'INR':
        return '₹';
      case 'IDR':
        return 'Rp';
      case 'MYR':
        return 'RM';
      default:
        // Right-to-left signs (﷼, د.إ) render unreliably before a number, so
        // Gulf currencies and EGP use their ISO codes.
        return '$currency ';
    }
  }
}
