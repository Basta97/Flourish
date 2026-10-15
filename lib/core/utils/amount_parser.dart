import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import '../../domain/finance/amount.dart';
import 'currency_formatter.dart';
import 'text_normalizer.dart';

class AmountParseResult {
  final Amount? value;
  final String? error;
  const AmountParseResult.ok(Amount this.value) : error = null;
  const AmountParseResult.fail(String this.error) : value = null;
  bool get isValid => value != null;
}

/// Parses money typed by people or found in bank messages, without going
/// through `double`.
///
/// * Arabic-Indic / Persian digits and `٫` / `٬` are accepted.
/// * With both `.` and `,`, the last one is the decimal separator.
/// * A single `,` followed by exactly three digits groups thousands
///   ("1,234"); otherwise it is the decimal separator ("12,50").
/// * A single `.` is the decimal separator; repeated separators group
///   thousands ("1.234.567").
/// * The number of decimals is limited by the currency (0 for JPY, 3 for
///   KWD…). [lenient] rounds extra decimals instead of rejecting them and
///   ignores surrounding text such as a currency code.
class AmountParser {
  AmountParser._();

  static final _grouped = RegExp(r'^\d{1,3}(?:[ ]\d{3})+(?:[.,]\d*)?$');

  static AmountParseResult parse(
    String text, {
    required String currency,
    bool lenient = false,
    bool allowZero = false,
  }) {
    var s = TextNormalizer.digits(text).trim();
    if (lenient) {
      final match = RegExp(r'\d[\d.,\s]*').firstMatch(s);
      s = match == null ? '' : match.group(0)!.trim();
      s = s.replaceAll(RegExp(r'[.,\s]+$'), '');
    }
    if (s.isEmpty) return const AmountParseResult.fail('Enter an amount');
    if (s.contains(' ')) {
      if (!_grouped.hasMatch(s)) {
        return const AmountParseResult.fail('Check the number format');
      }
      s = s.replaceAll(' ', '');
    }
    if (!RegExp(r'^[\d.,]+$').hasMatch(s)) {
      return const AmountParseResult.fail('Enter numbers only');
    }
    final normalized = _canonical(s);
    if (normalized == null) {
      return const AmountParseResult.fail('Check the number format');
    }
    var value = Decimal.parse(normalized);
    final digits = CurrencyFormatter.decimalsFor(currency);
    if (value.scale > digits) {
      if (!lenient) {
        return AmountParseResult.fail(
          digits == 0
              ? '$currency has no decimals'
              : 'Use at most $digits decimals for $currency',
        );
      }
      value = value.round(scale: digits);
    }
    if (value == Decimal.zero && !allowZero) {
      return const AmountParseResult.fail('Enter an amount above zero');
    }
    return AmountParseResult.ok(Amount(value.toString()));
  }

  /// Returns a plain `1234.56` form, or null when separators are ambiguous
  /// in a way that cannot be resolved.
  static String? _canonical(String s) {
    final dots = '.'.allMatches(s).length, commas = ','.allMatches(s).length;
    String grouped(String whole, String sep) => whole.split(sep).join();
    bool validGroups(String whole, String sep) {
      final parts = whole.split(sep);
      if (parts.first.isEmpty || parts.first.length > 3) return false;
      return parts.skip(1).every((p) => p.length == 3);
    }

    String? split(String sepThousands, String sepDecimal) {
      final at = s.lastIndexOf(sepDecimal);
      final whole = s.substring(0, at), fraction = s.substring(at + 1);
      if (fraction.contains(sepThousands) || fraction.contains(sepDecimal)) {
        return null;
      }
      if (whole.contains(sepThousands) && !validGroups(whole, sepThousands)) {
        return null;
      }
      final integer = grouped(whole, sepThousands);
      return '${integer.isEmpty ? '0' : integer}.${fraction.isEmpty ? '0' : fraction}';
    }

    if (dots > 0 && commas > 0) {
      return s.lastIndexOf('.') > s.lastIndexOf(',')
          ? split(',', '.')
          : split('.', ',');
    }
    for (final sep in ['.', ',']) {
      final count = sep == '.' ? dots : commas;
      if (count == 0) continue;
      final groupsThousands =
          count > 1 || (sep == ',' && RegExp(r'^\d{1,3},\d{3}$').hasMatch(s));
      if (groupsThousands) {
        return validGroups(s, sep) ? grouped(s, sep) : null;
      }
      return split(sep == '.' ? ',' : '.', sep);
    }
    return s;
  }

  /// Parses quantities, rates and signed values from the finance forms, with
  /// the same separator rules but no currency limit on decimals.
  static Amount decimal(String text, {bool allowNegative = true}) {
    var s = TextNormalizer.digits(text).trim();
    final negative = s.startsWith('-') || s.startsWith('\u2212');
    if (negative) {
      if (!allowNegative) throw ArgumentError('Enter a positive number');
      s = s.substring(1).trim();
    }
    if (s.contains(' ')) {
      if (!_grouped.hasMatch(s)) throw ArgumentError('Check "$text"');
      s = s.replaceAll(' ', '');
    }
    final normalized = RegExp(r'^[\d.,]+$').hasMatch(s) ? _canonical(s) : null;
    if (normalized == null) throw ArgumentError('"$text" is not a number');
    return Amount('${negative ? '-' : ''}$normalized');
  }

  /// Convenience for forms: the parsed amount or null.
  static Amount? tryParse(String text, {required String currency}) =>
      parse(text, currency: currency).value;
}

/// Lets people type digits in any script plus the separators the parser
/// understands; Arabic-Indic digits are shown as typed but stored as ASCII.
class AmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = TextNormalizer.digits(newValue.text);
    if (!RegExp(r'^[\d.,\s]*$').hasMatch(text)) return oldValue;
    if (text == newValue.text) return newValue;
    final offset = newValue.selection.baseOffset.clamp(0, text.length);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
