import '../detection/parsed_payment.dart';
import '../detection/payment_parser.dart';

class ParsedTransactionNotification {
  const ParsedTransactionNotification({
    required this.rawText,
    required this.amount,
    required this.type,
    required this.merchant,
    required this.confidence,
    this.suggestedCategoryKeyword,
  });

  final String rawText;
  final double? amount;
  final String type;
  final String merchant;
  final double confidence;
  final String? suggestedCategoryKeyword;

  bool get isExpense => type == 'expense';
}

/// Adapter kept for the paste/share import screen; the work is done by
/// [PaymentMessageParser], which understands Arabic and Egyptian formats.
class TransactionNotificationParser {
  static ParsedTransactionNotification parse(String input) {
    final parsed = PaymentMessageParser.parse(
      RawMessage(text: input, receivedAt: DateTime.now(), source: 'paste'),
    );
    final normalized = input
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final merchant = parsed.merchant ?? parsed.counterparty ?? '';
    return ParsedTransactionNotification(
      rawText: normalized,
      amount: parsed.ignored ? null : parsed.amount?.toDouble(),
      type: parsed.direction,
      merchant: merchant,
      confidence: parsed.confidence,
      suggestedCategoryKeyword: _suggestCategoryKeyword(
        normalized.toLowerCase(),
        merchant,
      ),
    );
  }

  static String? _suggestCategoryKeyword(String lower, String merchant) {
    final haystack = '$lower ${merchant.toLowerCase()}';
    if (haystack.contains('uber') ||
        haystack.contains('careem') ||
        haystack.contains('taxi') ||
        haystack.contains('metro')) {
      return 'transport';
    }
    if (haystack.contains('restaurant') ||
        haystack.contains('coffee') ||
        haystack.contains('cafe') ||
        haystack.contains('food')) {
      return 'food';
    }
    if (haystack.contains('amazon') ||
        haystack.contains('store') ||
        haystack.contains('mall') ||
        haystack.contains('apple')) {
      return 'shopping';
    }
    if (haystack.contains('netflix') ||
        haystack.contains('spotify') ||
        haystack.contains('cinema')) {
      return 'entertainment';
    }
    if (haystack.contains('salary') || haystack.contains('payroll')) {
      return 'salary';
    }
    return null;
  }
}
