/// Removes what must never be stored from a message: full card numbers
/// (kept as the last 4), national ID numbers and one-time codes. Phone
/// numbers keep only their last 3 digits.
String redact(String text) {
  var out = text.replaceAllMapped(
    RegExp(r'(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)'),
    (m) {
      final digits = m.group(0)!.replaceAll(RegExp(r'[ -]'), '');
      if (_luhn(digits)) return '••••${digits.substring(digits.length - 4)}';
      // Egyptian national ID: 14 digits starting with century 2 or 3.
      if (RegExp(r'^[23]\d{13}$').hasMatch(digits)) return '[ID]';
      return m.group(0)!;
    },
  );
  out = out.replaceAllMapped(
    RegExp(
      r'((?:otp|code|passcode|pin|رمز|كود|الرمز)\D{0,12})(\d{4,8})',
      caseSensitive: false,
    ),
    (m) => '${m.group(1)}[CODE]',
  );
  out = out.replaceAllMapped(
    RegExp(r'(?<!\d)(\+?20|0)(1[0125])(\d{5})(\d{3})(?!\d)'),
    (m) => '${m.group(1)}${m.group(2)}*****${m.group(4)}',
  );
  return out;
}

bool _luhn(String digits) {
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    var d = digits.codeUnitAt(digits.length - 1 - i) - 0x30;
    if (i.isOdd) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 == 0;
}
