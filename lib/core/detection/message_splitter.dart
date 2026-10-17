import 'local_parser.dart';

/// Splits a pasted blob that may hold several alerts ("copy all" from the
/// Messages app) into one string per message.
class MessageSplitter {
  MessageSplitter._();

  static List<String> split(String input) {
    final normalized = input.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return const [];
    final blocks = normalized
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
    final out = <String>[];
    for (final block in blocks) {
      final lines = block
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      // A block whose lines are each a complete transaction is several
      // messages pasted without blank lines; otherwise the lines are one
      // message wrapped across lines.
      final complete = lines.where(_isCompleteMessage).length;
      if (lines.length > 1 && complete >= 2 && complete == lines.length) {
        out.addAll(lines);
      } else {
        out.add(block);
      }
    }
    return out;
  }

  static bool _isCompleteMessage(String line) {
    final c = LocalTransactionParser.parse(line);
    return c.amount != null &&
        c.currency != null &&
        c.fieldConfidence['type']! >= 0.7;
  }
}
