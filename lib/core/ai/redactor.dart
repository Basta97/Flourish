/// Removes personal data from text before it leaves the device. Amounts,
/// merchant names and dates stay; anything that identifies the person or
/// their accounts does not.
class Redactor {
  Redactor._();

  static final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
  static final _iban = RegExp(r'\b[A-Z]{2}\d{2}[A-Z0-9]{10,30}\b');
  static final _phone = RegExp(r'\+\d{1,3}[\s\-]?\d[\d\s\-]{7,13}\d|(?<!\d)0\d{9,11}(?!\d)');
  static final _longDigits = RegExp(r'(?<![\d.,])\d(?:[\d\-]{4,})\d(?![\d.,])');

  /// [keepNumbers] are digit strings that must survive (the detected amount
  /// written without separators, e.g. "250000").
  static String redact(String text, {Set<String> keepNumbers = const {}}) {
    var out = text
        .replaceAll(_email, '[email]')
        .replaceAll(_iban, '[iban]')
        .replaceAll(_phone, '[phone]');
    out = out.replaceAllMapped(_longDigits, (m) {
      final raw = m.group(0)!;
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 6 || keepNumbers.contains(digits)) return raw;
      return '****${digits.substring(digits.length - 4)}';
    });
    return out;
  }
}
