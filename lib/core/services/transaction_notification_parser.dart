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
  // Currency codes, symbols and common Arabic currency words.
  static const _cur =
      r'USD|EGP|EUR|GBP|SAR|AED|JPY|CNY|INR|KWD|QAR|BHD|OMR|\$|£|€|جنيه|ج\.م|ريال|درهم|دولار';

  /// Optional leading currency, a number (comma-grouped or plain, optional
  /// decimals), an optional "k" (thousands) and an optional trailing currency.
  static final RegExp _amountRegex = RegExp(
    '(?:($_cur)\\s*)?'
    r'(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)'
    r'(\s?[kK](?![A-Za-z]))?'
    '\\s*($_cur)?',
    caseSensitive: false,
  );

  static final RegExp _merchantRegex = RegExp(
    r'\b(?:at|to|from|merchant|store|via)\s+|@\s*|لدى\s+',
    caseSensitive: false,
  );

  /// Words that end a merchant name ("Uber on card **** 7788" → "Uber").
  static final RegExp _merchantStop = RegExp(
    r'\s+(?:on|using|with|has|have|was|is|ending|card|account|ref|reference|balance|available|for|dated)\b|\s*[.,;:(*]|\s+\d{4,}',
    caseSensitive: false,
  );

  static const _otpWords = [
    'otp',
    'one-time',
    'one time',
    'verification code',
    'security code',
    'passcode',
    'do not share',
    'رمز التحقق',
    'كلمة المرور',
  ];

  static const _balanceWords = [
    'balance',
    'bal:',
    'bal ',
    'available',
    'avail',
    'limit',
    'رصيد',
    'الرصيد',
    'المتاح',
  ];

  static const _txnWords = [
    'spent',
    'paid',
    'pay ',
    'purchase',
    'debited',
    'credited',
    'received',
    'deposit',
    'charged',
    'withdrawal',
    'withdrawn',
    'refund',
    'transfer',
    'sent',
    'خصم',
    'مبلغ',
    'إيداع',
    'ايداع',
    'سحب',
    'شراء',
    'تحويل',
    'استلام',
  ];

  static ParsedTransactionNotification parse(String input) {
    final normalized = _normalizeDigits(
      input,
    ).replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final lower = normalized.toLowerCase();

    final amount = _extractAmount(normalized, lower);
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

  /// Arabic-Indic digits and separators → ASCII, so "٢٥٠٫٥٠" reads as 250.50.
  static String _normalizeDigits(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final out = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final a = arabic.indexOf(ch);
      final p = persian.indexOf(ch);
      if (a >= 0) {
        out.write(a);
      } else if (p >= 0) {
        out.write(p);
      } else if (ch == '٫') {
        out.write('.');
      } else if (ch == '٬') {
        out.write(',');
      } else {
        out.write(ch);
      }
    }
    return out.toString();
  }

  static double? _extractAmount(String input, String lower) {
    final isOtp = _otpWords.any(lower.contains);
    double? best;
    var bestScore = 0;
    var candidates = 0;
    double? only;

    for (final match in _amountRegex.allMatches(input)) {
      final raw = match.group(2);
      if (raw == null) continue;
      var value = double.tryParse(raw.replaceAll(',', ''));
      if (value == null || value <= 0) continue;
      if (match.group(3) != null) value *= 1000;

      final hasCurrency = match.group(1) != null || match.group(4) != null;
      final hasDecimal = raw.contains('.');
      final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
      final before = lower.substring(
        (match.start - 28).clamp(0, lower.length),
        match.start,
      );
      final around = lower.substring(
        (match.start - 14).clamp(0, lower.length),
        (match.end + 14).clamp(0, lower.length),
      );

      // Card suffixes ("card ending 4521", "**** 7788") and account numbers.
      final looksLikeCardSuffix =
          !hasDecimal &&
          !hasCurrency &&
          digits.length == 4 &&
          (around.contains('card') ||
              around.contains('ending') ||
              around.contains('xxxx') ||
              around.contains('*'));
      if (looksLikeCardSuffix) continue;
      final looksLikeAccountNumber =
          !hasDecimal && !hasCurrency && digits.length >= 9;
      if (looksLikeAccountNumber) continue;

      candidates++;
      only = value;

      var score = 0;
      if (hasCurrency) score += 3;
      if (hasDecimal) score += 2;
      if (_txnWords.any(before.contains)) score += 2;
      if (_balanceWords.any(before.contains)) score -= 6;
      // One-time codes are bare integers of 4–8 digits.
      if (isOtp && !hasCurrency && !hasDecimal) score -= 6;

      if (score > bestScore) {
        bestScore = score;
        best = value;
      }
    }

    if (best != null) return best;
    // A lone, unlabelled number still counts ("Starbucks 5") unless the
    // message is a verification code or a balance notice.
    if (candidates == 1 && !isOtp && only != null) {
      final looksLikeBalanceOnly = _balanceWords.any(lower.contains);
      if (!looksLikeBalanceOnly) return only;
    }
    return null;
  }

  static String _detectType(String lower) {
    const incomeWords = [
      'credited',
      'deposit',
      'deposited',
      'received',
      'refund',
      'salary',
      'إيداع',
      'ايداع',
      'استلام',
      'استلمت',
      'راتب',
      'استرداد',
      'تحويل وارد',
    ];
    const expenseWords = [
      'spent',
      'purchase',
      'debited',
      'paid',
      'transaction',
      'charged',
      'withdrawal',
      'apple pay',
      'tap to pay',
      'خصم',
      'سحب',
      'شراء',
      'دفع',
      'مدين',
    ];

    final incomeHits = incomeWords.where(lower.contains).length;
    final expenseHits = expenseWords.where(lower.contains).length;

    if (incomeHits > expenseHits) return 'income';
    return 'expense';
  }

  static String _extractMerchant(String input) {
    final match = _merchantRegex.firstMatch(input);
    if (match == null) return '';
    var rest = input.substring(match.end);
    final stop = _merchantStop.firstMatch(rest);
    if (stop != null) rest = rest.substring(0, stop.start);
    rest = rest.trim().replaceAll(RegExp(r'[.,]$'), '');
    // Don't return something that is only a number or very short.
    if (rest.length < 2 || RegExp(r'^[\d\s.,]+$').hasMatch(rest)) return '';
    return rest.length > 40 ? rest.substring(0, 40).trim() : rest;
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
