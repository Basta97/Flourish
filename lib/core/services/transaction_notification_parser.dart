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

class TransactionNotificationParser {
  static final RegExp _amountRegex = RegExp(
    r'(?:(?:USD|EGP|EUR|GBP|SAR|AED|JPY|CNY|INR)\s*)?([0-9]{1,3}(?:[,\s][0-9]{3})*(?:\.[0-9]{1,2})|[0-9]+(?:\.[0-9]{1,2})?)\s*(?:USD|EGP|EUR|GBP|SAR|AED|JPY|CNY|INR)?',
    caseSensitive: false,
  );

  static final RegExp _merchantRegex = RegExp(
    r'(?:at|to|from|merchant|store|via|@)\s+([A-Za-z0-9&\-\.\s]{2,40})',
    caseSensitive: false,
  );

  static ParsedTransactionNotification parse(String input) {
    final normalized = input
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final lower = normalized.toLowerCase();

    final amount = _extractAmount(normalized);
    final type = _detectType(lower);
    final merchant = _extractMerchant(normalized);
    final confidence = _scoreConfidence(lower, amount, merchant);

    return ParsedTransactionNotification(
      rawText: normalized,
      amount: amount,
      type: type,
      merchant: merchant,
      confidence: confidence,
      suggestedCategoryKeyword: _suggestCategoryKeyword(lower, merchant),
    );
  }

  static double? _extractAmount(String input) {
    final matches = _amountRegex.allMatches(input);
    double? fallback;
    for (final match in matches) {
      final raw = match.group(1);
      if (raw == null) continue;
      final cleaned = raw.replaceAll(',', '').replaceAll(' ', '');
      final value = double.tryParse(cleaned);
      if (value == null || value <= 0) continue;

      final segmentStart = (match.start - 14).clamp(0, input.length);
      final segmentEnd = (match.end + 14).clamp(0, input.length);
      final context = input.substring(segmentStart, segmentEnd).toLowerCase();
      final looksLikeCardSuffix =
          !raw.contains('.') &&
          cleaned.length == 4 &&
          (context.contains('card') ||
              context.contains('ending') ||
              context.contains('xxxx'));

      if (looksLikeCardSuffix) continue;

      final looksLikeMoney =
          raw.contains('.') ||
          context.contains('usd') ||
          context.contains('egp') ||
          context.contains('eur') ||
          context.contains('gbp') ||
          context.contains('aed') ||
          context.contains('sar') ||
          context.contains('spent') ||
          context.contains('paid') ||
          context.contains('credited');

      if (looksLikeMoney) return value;
      fallback ??= value;
    }
    return fallback;
  }

  static String _detectType(String lower) {
    const incomeWords = [
      'credited',
      'deposit',
      'deposited',
      'received',
      'refund',
      'salary',
    ];
    const expenseWords = [
      'spent',
      'purchase',
      'debited',
      'paid',
      'transaction',
      'charged',
      'apple pay',
      'tap to pay',
    ];

    final incomeHits = incomeWords.where(lower.contains).length;
    final expenseHits = expenseWords.where(lower.contains).length;

    if (incomeHits > expenseHits) return 'income';
    return 'expense';
  }

  static String _extractMerchant(String input) {
    final match = _merchantRegex.firstMatch(input);
    if (match == null) return '';
    final merchant = match.group(1)?.trim() ?? '';
    return merchant.replaceAll(RegExp(r'[.,]$'), '');
  }

  static double _scoreConfidence(
    String lower,
    double? amount,
    String merchant,
  ) {
    double score = 0.2;
    if (amount != null) score += 0.35;
    if (merchant.isNotEmpty) score += 0.2;
    if (lower.contains('apple pay') ||
        lower.contains('transaction') ||
        lower.contains('purchase')) {
      score += 0.15;
    }
    if (lower.contains('card') || lower.contains('account')) score += 0.1;
    return score.clamp(0.0, 0.95);
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
