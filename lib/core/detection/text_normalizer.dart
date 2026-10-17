import 'dart:convert';

import 'package:cryptography/dart.dart';

import '../../domain/finance/amount.dart';

/// Shared text clean-up for detection, so the parser, the review form and the
/// importers all read "١٬٢٥٠٫٥٠" and "1 250,50" the same way.
class TextNormalizer {
  TextNormalizer._();

  static const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  static const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

  /// Arabic-Indic / Persian digits and separators → ASCII; NBSP and narrow
  /// spaces → plain spaces; runs of whitespace collapsed.
  static String normalize(String input) {
    final out = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final a = _arabicDigits.indexOf(ch);
      final p = _persianDigits.indexOf(ch);
      if (a >= 0) {
        out.write(a);
      } else if (p >= 0) {
        out.write(p);
      } else if (ch == '٫') {
        out.write('.');
      } else if (ch == '٬') {
        out.write(',');
      } else if (rune == 0x00A0 || rune == 0x202F || rune == 0x2009) {
        out.write(' ');
      } else {
        out.write(ch);
      }
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Currencies whose minor unit has three digits, so "1.250" is 1.25 KWD and
  /// not one thousand.
  static const threeDecimalCurrencies = {'KWD', 'BHD', 'OMR', 'JOD', 'TND'};

  /// Currencies that are usually written with "." thousands and "," decimals.
  static const commaDecimalCurrencies = {'EUR', 'TRY', 'IDR', 'BRL'};

  /// Parses a human-typed amount ("1,250.50", "1.250,50", "12 000", "٢٥٠٫٥",
  /// "1.5k") into an exact [Amount]. Returns null for anything unreadable or
  /// not positive.
  static Amount? parseAmount(String input, {String? currency}) {
    var text = normalize(input).replaceAll(RegExp(r'[^\d.,\s\-kK]'), '');
    text = text.trim();
    if (text.isEmpty) return null;
    var multiplier = 1;
    if (RegExp(r'[kK]$').hasMatch(text)) {
      multiplier = 1000;
      text = text.substring(0, text.length - 1).trim();
    }
    if (text.startsWith('-')) return null;
    final canonical = canonicalNumber(text, currency: currency);
    if (canonical == null) return null;
    try {
      var value = Amount(canonical);
      if (multiplier != 1) value = value * Amount('$multiplier');
      return value > Amount.zero ? value : null;
    } on FormatException {
      return null;
    }
  }

  /// Turns a grouped number into "1234.56", deciding which separator is the
  /// decimal point. Returns null when the text is not a single number.
  static String? canonicalNumber(String raw, {String? currency}) {
    final text = raw.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d[\d.,]*$').hasMatch(text)) return null;
    final dots = '.'.allMatches(text).length;
    final commas = ','.allMatches(text).length;
    String integer, fraction = '';

    if (dots > 0 && commas > 0) {
      // Whichever separator comes last is the decimal point.
      final decimalSep = text.lastIndexOf('.') > text.lastIndexOf(',')
          ? '.'
          : ',';
      final groupSep = decimalSep == '.' ? ',' : '.';
      final parts = text.split(decimalSep);
      if (parts.length != 2) return null;
      integer = parts[0].replaceAll(groupSep, '');
      fraction = parts[1];
      if (fraction.contains(groupSep)) return null;
    } else if (dots + commas == 0) {
      integer = text;
    } else {
      final sep = dots > 0 ? '.' : ',';
      final parts = text.split(sep);
      final last = parts.last;
      final grouped =
          parts.length > 2 ||
          (last.length == 3 &&
              parts.first.length <= 3 &&
              !_threeDecimalPreferred(sep, currency));
      if (grouped) {
        if (parts.skip(1).any((p) => p.length != 3)) return null;
        integer = parts.join();
      } else {
        if (parts.length != 2 || last.isEmpty || last.length > 3) return null;
        integer = parts.first;
        fraction = last;
      }
    }
    if (integer.isEmpty) return null;
    return fraction.isEmpty ? integer : '$integer.$fraction';
  }

  /// "1.250": three digits after the only separator. It is a decimal for
  /// three-decimal currencies, otherwise thousands — except "." with an
  /// unknown currency, which Gulf and Egyptian banks never use for grouping.
  static bool _threeDecimalPreferred(String sep, String? currency) {
    if (sep == '.') {
      if (currency != null && threeDecimalCurrencies.contains(currency)) {
        return true;
      }
      return currency == null || !commaDecimalCurrencies.contains(currency);
    }
    return false;
  }

  /// Stable SHA-256 hex of the normalised, lower-cased text.
  static String fingerprint(String text) {
    final digest = const DartSha256().hashSync(
      utf8.encode(normalize(text).toLowerCase()),
    );
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
