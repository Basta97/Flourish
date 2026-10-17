import 'parsed_payment.dart';
import 'payment_parser.dart';

/// Splits a pasted blob that may hold several alerts ("copy all" from the
/// Messages app) into one string per message.
class MessageSplitter {
  MessageSplitter._();

  static List<String> split(String input) {
    final normalized = input.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return const [];
    final out = <String>[];
    for (final block in normalized.split(RegExp(r'\n\s*\n'))) {
      final lines = block
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;
      // Lines that are each a whole payment are separate messages pasted
      // without blank lines; otherwise they are one message wrapped.
      final complete = lines.where(_isCompletePayment).length;
      if (lines.length > 1 && complete >= 2 && complete == lines.length) {
        out.addAll(lines);
      } else {
        out.add(lines.join(' '));
      }
    }
    return out;
  }

  static bool _isCompletePayment(String line) {
    final p = PaymentMessageParser.parse(
      RawMessage(text: line, receivedAt: DateTime.now(), source: 'paste'),
    );
    return !p.ignored && p.amount != null && p.currency != null && p.kind != null;
  }
}
