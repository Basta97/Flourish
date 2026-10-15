/// Normalizes numbers typed or received in Arabic, Persian or Latin script so
/// they can be parsed with one set of rules.
class TextNormalizer {
  TextNormalizer._();

  static final _invisible = RegExp(
    r'[\u200E\u200F\u061C\u202A-\u202E\u2066-\u2069\u0640]',
    unicode: true,
  );
  static final _spaces = RegExp(r'[\u00A0\u202F\u2007\u2009]', unicode: true);

  /// Arabic-Indic (٠–٩) and Persian (۰–۹) digits become ASCII, the Arabic
  /// decimal (٫) becomes `.`, the Arabic thousands mark (٬) and comma (،)
  /// become `,`, and direction marks, tatweel and no-break spaces are removed
  /// or turned into plain spaces.
  static String digits(String input) {
    final out = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        out.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        out.writeCharCode(0x30 + rune - 0x06F0);
      } else if (rune == 0x066B) {
        out.write('.');
      } else if (rune == 0x066C || rune == 0x060C) {
        out.write(',');
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString().replaceAll(_invisible, '').replaceAll(_spaces, ' ');
  }
}
