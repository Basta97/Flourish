import '../utils/text_normalizer.dart';

/// Prepares bank and wallet messages for matching.
class MessageNormalizer {
  MessageNormalizer._();

  /// ASCII digits and separators, plain spaces, single-spaced, trimmed. Case
  /// and letters are kept so merchant names read naturally.
  static String clean(String input) =>
      TextNormalizer.digits(input).replaceAll(RegExp(r'\s+'), ' ').trim();

  /// A matching form of [cleaned] with the same length: lower case, and the
  /// Arabic letters people and banks write interchangeably folded together
  /// (أ إ آ → ا, ى → ي, ة → ه). Indexes in both strings line up.
  static String fold(String cleaned) {
    final out = StringBuffer();
    for (final unit in cleaned.toLowerCase().codeUnits) {
      out.writeCharCode(switch (unit) {
        0x0623 || 0x0625 || 0x0622 => 0x0627,
        0x0649 => 0x064A,
        0x0629 => 0x0647,
        _ => unit,
      });
    }
    return out.toString();
  }
}
