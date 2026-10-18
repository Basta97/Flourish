import 'package:intl/intl.dart';

import '../../../domain/finance/amount.dart';
import 'import_source.dart';

/// Value parsers shared by every import source. They throw
/// [FormatException] so callers can turn a bad cell into a row error.
abstract final class ImportValues {
  static const _easternDigits = '٠١٢٣٤٥٦٧٨٩';
  static const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

  /// [text] with Arabic-Indic and Persian digits (and the Arabic decimal
  /// and thousands marks) replaced by ASCII ones.
  static String westernDigits(String text) => _westernDigits(text);

  static String _westernDigits(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final eastern = _easternDigits.indexOf(char);
      final persian = _persianDigits.indexOf(char);
      out.write(
        eastern >= 0
            ? '$eastern'
            : persian >= 0
            ? '$persian'
            : char == '٫'
            ? '.'
            : char == '٬'
            ? ','
            : char,
      );
    }
    return out.toString();
  }

  /// Picks the decimal separator a file uses from a sample of its amounts:
  /// the later of `.`/`,` in `1.234,56`, or a separator followed by one or
  /// two digits. Null when every sample is ambiguous (`1,234`, `12`).
  static String? detectDecimalSeparator(Iterable<String> samples) {
    var dot = 0, comma = 0;
    for (final raw in samples) {
      final s = _westernDigits(raw).replaceAll(RegExp(r'[^0-9.,]'), '');
      final lastDot = s.lastIndexOf('.'), lastComma = s.lastIndexOf(',');
      if (lastDot >= 0 && lastComma >= 0) {
        lastDot > lastComma ? dot++ : comma++;
      } else if (RegExp(r',\d{1,2}$').hasMatch(s) ||
          RegExp(r'\.\d{3}\.').hasMatch(s)) {
        comma++;
      } else if (RegExp(r'\.\d{1,2}$').hasMatch(s) ||
          RegExp(r',\d{3},').hasMatch(s)) {
        dot++;
      }
    }
    if (dot == comma) return null;
    return dot > comma ? '.' : ',';
  }

  /// Reads a signed amount: currency symbols and codes, spaces and
  /// apostrophes as thousands separators, `(12.00)`, `12.00-`, `12 DR`,
  /// Unicode minus and Arabic-Indic digits are all understood. With no
  /// [decimalSeparator], a lone `,` followed by three digits is a thousands
  /// separator and anything else is decimal.
  static Amount amount(String raw, {String? decimalSeparator}) {
    var s = _westernDigits(raw.trim()).replaceAll('−', '-');
    if (s.isEmpty) throw const FormatException('Missing amount');
    var negative = false;
    if (RegExp(r'^\(.*\)$').hasMatch(s)) {
      negative = true;
      s = s.substring(1, s.length - 1);
    }
    final marker = RegExp(r'(CR|DR)\.?$', caseSensitive: false).firstMatch(s);
    if (marker != null) {
      if (marker[1]!.toUpperCase() == 'DR') negative = !negative;
      s = s.substring(0, marker.start);
    }
    s = s.replaceAll(RegExp(r"[\s  '’]"), '');
    if (s.endsWith('-')) {
      negative = !negative;
      s = s.substring(0, s.length - 1);
    }
    final minus = RegExp(r'^[^0-9.,]*-').hasMatch(s);
    if (minus) negative = !negative;
    s = s.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (!RegExp(r'\d').hasMatch(s)) {
      throw FormatException('Not an amount: "$raw"');
    }
    final separator = decimalSeparator ?? _guessDecimal(s);
    if (separator == ',') {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
    if (!RegExp(r'^\d*\.?\d+$|^\d+\.$').hasMatch(s)) {
      throw FormatException('Not an amount: "$raw"');
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    final value = Amount(s.startsWith('.') ? '0$s' : s);
    return negative ? -value : value;
  }

  static String _guessDecimal(String s) {
    final lastDot = s.lastIndexOf('.'), lastComma = s.lastIndexOf(',');
    if (lastDot >= 0 && lastComma >= 0) return lastDot > lastComma ? '.' : ',';
    if (lastComma >= 0) {
      final commas = ','.allMatches(s).length;
      return commas == 1 && !RegExp(r',\d{3}$').hasMatch(s) ? ',' : '.';
    }
    if ('.'.allMatches(s).length > 1) return ',';
    return '.';
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static final _iso = RegExp(
    r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})'
    r'(?:[ T]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
  );
  static final _compact = RegExp(r'^(\d{4})(\d{2})(\d{2})$');
  static final _numeric = RegExp(
    r"^(\d{1,2})\s*[/.\-]\s*(\d{1,2})\s*([/.\-'])\s*(\d{4}|\d{2})"
    r'(?:[ T,]+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AaPp][Mm])?)?',
  );
  static final _dayMonthName = RegExp(
    r'^(\d{1,2})[\s\-/.]+([A-Za-z]{3,9})\.?[\s\-/.,]+(\d{4}|\d{2})\b',
  );
  static final _monthNameDay = RegExp(
    r'^([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b',
  );

  /// Numeric `a/b/y` dates in [samples] decide the order: a first part above
  /// 12 means day-first, a second part above 12 means month-first. Null when
  /// nothing in the file disambiguates.
  static DateOrder? detectDateOrder(Iterable<String> samples) {
    var dmy = 0, mdy = 0;
    for (final raw in samples) {
      final m = _numeric.firstMatch(raw.trim());
      if (m == null) continue;
      final a = int.parse(m[1]!), b = int.parse(m[2]!);
      if (a > 12 && b <= 12) dmy++;
      if (b > 12 && a <= 12) mdy++;
    }
    if (dmy == mdy) return null;
    return dmy > mdy ? DateOrder.dmy : DateOrder.mdy;
  }

  static int _year(String text, {bool apostrophe = false}) {
    final y = int.parse(text);
    if (text.length == 4) return y;
    // Quicken writes 2000-and-later years as 1/2'24.
    if (apostrophe) return 2000 + y;
    return y + 2000 <= DateTime.now().year + 10 ? 2000 + y : 1900 + y;
  }

  static DateTime _checked(
    int y,
    int m,
    int d, [
    int h = 0,
    int mi = 0,
    int s = 0,
  ]) {
    final date = DateTime(y, m, d, h, mi, s);
    if (m < 1 || m > 12 || date.month != m || date.day != d || h > 23) {
      throw FormatException('Invalid date $y-$m-$d');
    }
    return date;
  }

  /// Reads ISO, numeric (`03/04/24`, `3.4.2024`, Quicken's `3/ 4'24`) and
  /// month-name (`3 Apr 2024`, `Apr 3, 2024`) dates. [order] settles
  /// numeric dates whose day and month are both 12 or less; [pattern] (an
  /// `intl` pattern) replaces all of this when given.
  static DateTime date(String raw, {String? pattern, DateOrder? order}) {
    final s = _westernDigits(raw.trim());
    if (s.isEmpty) throw const FormatException('Missing date');
    if (pattern != null) {
      try {
        return DateFormat(pattern).parse(s);
      } on FormatException {
        throw FormatException('Date "$raw" does not match $pattern');
      }
    }
    var m = _iso.firstMatch(s) ?? _compact.firstMatch(s);
    if (m != null) {
      return _checked(
        int.parse(m[1]!),
        int.parse(m[2]!),
        int.parse(m[3]!),
        int.parse(m.groupCount > 3 ? m[4] ?? '0' : '0'),
        int.parse(m.groupCount > 3 ? m[5] ?? '0' : '0'),
        int.parse(m.groupCount > 3 ? m[6] ?? '0' : '0'),
      );
    }
    m = _numeric.firstMatch(s);
    if (m != null) {
      final a = int.parse(m[1]!), b = int.parse(m[2]!);
      final year = _year(m[4]!, apostrophe: m[3]!.startsWith("'"));
      final dayFirst = a > 12
          ? true
          : b > 12
          ? false
          : order != DateOrder.mdy;
      var hour = int.parse(m[5] ?? '0');
      final meridiem = m[8]?.toLowerCase();
      if (meridiem == 'pm' && hour < 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;
      return _checked(
        year,
        dayFirst ? b : a,
        dayFirst ? a : b,
        hour,
        int.parse(m[6] ?? '0'),
        int.parse(m[7] ?? '0'),
      );
    }
    m = _dayMonthName.firstMatch(s);
    final month1 = m == null
        ? null
        : _months[m[2]!.toLowerCase().substring(0, 3)];
    if (m != null && month1 != null) {
      return _checked(_year(m[3]!), month1, int.parse(m[1]!));
    }
    m = _monthNameDay.firstMatch(s);
    final month2 = m == null
        ? null
        : _months[m[1]!.toLowerCase().substring(0, 3)];
    if (m != null && month2 != null) {
      return _checked(int.parse(m[3]!), month2, int.parse(m[2]!));
    }
    throw FormatException('Unrecognised date "$raw"');
  }

  static const _symbols = {
    r'$': 'USD', r'US$': 'USD', '€': 'EUR', '£': 'GBP', '¥': 'JPY', //
    '₹': 'INR', 'E£': 'EGP', 'LE': 'EGP', 'L.E': 'EGP', 'ج.م': 'EGP',
    '₽': 'RUB', '₺': 'TRY', '₩': 'KRW', '₴': 'UAH', 'zł': 'PLN',
    'Kč': 'CZK', 'CHF': 'CHF', 'Fr.': 'CHF', r'R$': 'BRL', '₱': 'PHP',
    '﷼': 'SAR', 'د.إ': 'AED',
  };

  /// Upper-case ISO code for a code or common symbol, or null when [raw] is
  /// empty or unknown.
  static String? currency(String? raw) {
    final s = raw?.trim() ?? '';
    if (s.isEmpty) return null;
    if (RegExp(r'^[A-Za-z]{3}$').hasMatch(s)) return s.toUpperCase();
    return _symbols[s];
  }

  static String? text(String? raw) {
    final s = raw?.trim();
    return s == null || s.isEmpty ? null : s;
  }

  /// `Food:Groceries` → (`Food`, `Groceries`); deeper paths keep the rest
  /// in the subcategory.
  static (String?, String?) categoryPath(String? raw, {String divider = ':'}) {
    final s = text(raw);
    if (s == null) return (null, null);
    final cut = s.indexOf(divider);
    if (cut < 0) return (s, null);
    return (text(s.substring(0, cut)), text(s.substring(cut + divider.length)));
  }
}
