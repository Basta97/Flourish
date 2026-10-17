import '../../domain/finance/amount.dart';
import 'bank_profiles.dart';
import 'category_concepts.dart';
import 'text_normalizer.dart';
import 'transaction_candidate.dart';

/// On-device extraction of a transaction from one bank / wallet / Apple Pay
/// message (English and Arabic). Runs with no network and is the first stage
/// of detection; the AI stage only sees messages this parser is unsure about.
class LocalTransactionParser {
  LocalTransactionParser._();

  static TransactionCandidate parse(String input, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final text = TextNormalizer.normalize(input);
    final lower = text.toLowerCase();

    final blocked = <_Span>[];
    final cardLast4 = _maskCards(text, blocked);
    _maskAccounts(text, blocked);
    final reference = _maskReferences(text, blocked);
    _maskPhones(text, blocked);
    final date = _extractDate(text, clock, blocked);

    final bank = BankProfiles.detect(lower);
    final kinds = _classify(text);
    final amount = _extractAmount(text, blocked, kinds);

    var kind = kinds.kind;
    if (kind.movesMoney && amount.value == null && amount.sawBalance) {
      kind = TransactionKind.balanceOnly;
    }
    final type = kinds.type;
    final merchant = _extractMerchant(text, type);
    final currency = amount.currency ?? bank?.defaultCurrency;

    final fields = <String, double>{
      'amount': amount.confidence,
      'type': kinds.confidence,
      'merchant': merchant.confidence,
      'date': date == null ? 0 : 0.9,
      'currency': amount.currency != null
          ? 0.9
          : bank?.defaultCurrency != null
          ? 0.6
          : 0,
    };

    final concept = CategoryConcepts.match(
      '${merchant.value} $text',
      type: type,
    );

    return TransactionCandidate(
      rawText: text,
      amount: amount.value,
      currency: currency,
      date: date,
      type: type,
      kind: kind,
      merchant: merchant.value,
      merchantKey: normalizeMerchant(merchant.value),
      cardLast4: cardLast4,
      reference: reference,
      bankHint: bank?.id,
      categoryHint: concept?.key,
      fieldConfidence: fields,
      confidence: _overall(fields, amount.value != null, kind),
      fingerprint: TextNormalizer.fingerprint(text),
    );
  }

  // ---------------------------------------------------------------- spans

  static bool _overlaps(List<_Span> spans, int start, int end) =>
      spans.any((s) => start < s.end && end > s.start);

  static final _cardPatterns = [
    RegExp(r'[*xX•#]{2,}[\s-]?(\d{4})(?!\d)'),
    RegExp(
      r'\b(?:ending|ends)(?:\s+(?:in|with))?\s*[:\-]?\s*(?:[*xX]+\s*)?(\d{4})(?!\d)',
      caseSensitive: false,
    ),
    RegExp(
      r'\bcard(?:\s+(?:no\.?|number|#))?\s*[:\-]?\s*(\d{4})(?![\d.,])',
      caseSensitive: false,
    ),
    RegExp(r'(?:بطاقة|بطاقتك|البطاقة)\s*(?:رقم)?\s*[*xX]*\s*(\d{4})(?!\d)'),
  ];

  static String? _maskCards(String text, List<_Span> blocked) {
    String? last4;
    for (final pattern in _cardPatterns) {
      for (final m in pattern.allMatches(text)) {
        final digits = m.group(1)!;
        final start = m.end - digits.length;
        blocked.add(_Span(start, m.end));
        last4 ??= digits;
      }
    }
    return last4;
  }

  static final _accountPattern = RegExp(
    r'(?<![A-Za-z؀-ۿ])(?:a/c|acct|account|iban|حسابك|الحساب|حساب)(?:\s+(?:no\.?|number|#|رقم))?\s*[:\-]?\s*[*xX]*\s*([A-Z]{0,4}\d[\d\s]{2,})',
    caseSensitive: false,
  );

  static void _maskAccounts(String text, List<_Span> blocked) {
    for (final m in _accountPattern.allMatches(text)) {
      final value = m.group(1)!.trimRight();
      final digits = value.replaceAll(RegExp(r'\D'), '');
      // "account 1250.00 debited" is an amount; account numbers are long.
      if (digits.length < 6) continue;
      final start = m.end - m.group(1)!.length;
      blocked.add(_Span(start, start + value.length));
    }
  }

  static final _referencePattern = RegExp(
    r'(?:\bref(?:erence)?(?![a-z])|\btxn\b|\btrx\b|\brrn\b|\bauth(?:orization)?\s*code|\btransaction\s*(?:id|no\.?|number)|رقم\s*(?:العملية|المرجع)|مرجع)\s*(?:no\.?|number|#|id)?\s*[:#\-]?\s*([A-Z0-9][A-Z0-9\-]{3,})',
    caseSensitive: false,
  );

  static String? _maskReferences(String text, List<_Span> blocked) {
    String? ref;
    for (final m in _referencePattern.allMatches(text)) {
      final value = m.group(1)!;
      blocked.add(_Span(m.end - value.length, m.end));
      ref ??= value;
    }
    return ref;
  }

  static final _phonePatterns = [
    RegExp(r'\+\d{1,3}[\s\-]?\d[\d\s\-]{7,13}\d'),
    RegExp(r'(?<!\d)0\d{9,11}(?!\d)'),
    RegExp(
      r'\b(?:call|hotline|contact)\s*(?:us)?\s*(?:on|at)?\s*(\d{3,})',
      caseSensitive: false,
    ),
  ];

  static void _maskPhones(String text, List<_Span> blocked) {
    for (final pattern in _phonePatterns) {
      for (final m in pattern.allMatches(text)) {
        blocked.add(_Span(m.start, m.end));
      }
    }
  }

  // ----------------------------------------------------------------- date

  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
    'يناير': 1,
    'فبراير': 2,
    'مارس': 3,
    'أبريل': 4,
    'ابريل': 4,
    'مايو': 5,
    'يونيو': 6,
    'يوليو': 7,
    'أغسطس': 8,
    'اغسطس': 8,
    'سبتمبر': 9,
    'أكتوبر': 10,
    'اكتوبر': 10,
    'نوفمبر': 11,
    'ديسمبر': 12,
  };

  static const _monthNames =
      r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';
  static const _arabicMonths =
      r'(يناير|فبراير|مارس|أبريل|ابريل|مايو|يونيو|يوليو|أغسطس|اغسطس|سبتمبر|أكتوبر|اكتوبر|نوفمبر|ديسمبر)';

  static final _isoDate = RegExp(r'(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)');
  static final _numericDate = RegExp(
    r'(?<![\d.,])(\d{1,2})([/.\-])(\d{1,2})\2(\d{4}|\d{2})(?![\d.,])',
  );
  static final _shortDate = RegExp(r'(?<![\d.,/])(\d{1,2})[/\-](\d{1,2})(?![\d/\-])');
  static final _dayMonth = RegExp(
    '(?<!\\d)(\\d{1,2})(?:st|nd|rd|th)?[\\s\\-]*$_monthNames(?![a-z])[\\s\\-,]*(\\d{4}|\\d{2}(?![\\d:]))?',
    caseSensitive: false,
  );
  static final _monthDay = RegExp(
    '(?<![a-z])$_monthNames\\s+(\\d{1,2})(?:st|nd|rd|th)?(?!\\d)(?:,?\\s*(\\d{4}))?',
    caseSensitive: false,
  );
  static final _arabicDate = RegExp(
    '(?<!\\d)(\\d{1,2})\\s*$_arabicMonths\\s*(\\d{4})?',
  );
  static final _time = RegExp(
    r'(?<!\d)(\d{1,2}):(\d{2})(?::(\d{2}))?(?:\s*(am|pm))?',
    caseSensitive: false,
  );

  static DateTime? _extractDate(
    String text,
    DateTime now,
    List<_Span> blocked,
  ) {
    DateTime? found;

    void take(RegExpMatch m, DateTime? Function() build) {
      if (_overlaps(blocked, m.start, m.end)) return;
      final value = build();
      if (value == null) return;
      blocked.add(_Span(m.start, m.end));
      found ??= value;
    }

    for (final m in _isoDate.allMatches(text)) {
      take(
        m,
        () => _validDate(
          int.parse(m.group(1)!),
          int.parse(m.group(2)!),
          int.parse(m.group(3)!),
          now,
          explicitYear: true,
        ),
      );
    }
    for (final m in _numericDate.allMatches(text)) {
      take(m, () {
        var a = int.parse(m.group(1)!), b = int.parse(m.group(3)!);
        var year = int.parse(m.group(4)!);
        if (year < 100) year += 2000;
        // Day first unless that is impossible (US-style 10/25/2026).
        if (b > 12 && a <= 12) (a, b) = (b, a);
        return _validDate(year, b, a, now, explicitYear: true);
      });
    }
    for (final m in _dayMonth.allMatches(text)) {
      take(m, () {
        final month = _months[m.group(2)!.substring(0, 3).toLowerCase()]!;
        final year = _year(m.group(3));
        return _validDate(
          year ?? now.year,
          month,
          int.parse(m.group(1)!),
          now,
          explicitYear: year != null,
        );
      });
    }
    for (final m in _monthDay.allMatches(text)) {
      take(m, () {
        final month = _months[m.group(1)!.substring(0, 3).toLowerCase()]!;
        final year = _year(m.group(3));
        return _validDate(
          year ?? now.year,
          month,
          int.parse(m.group(2)!),
          now,
          explicitYear: year != null,
        );
      });
    }
    for (final m in _arabicDate.allMatches(text)) {
      take(m, () {
        final year = _year(m.group(3));
        return _validDate(
          year ?? now.year,
          _months[m.group(2)!]!,
          int.parse(m.group(1)!),
          now,
          explicitYear: year != null,
        );
      });
    }
    for (final m in _shortDate.allMatches(text)) {
      take(m, () {
        var a = int.parse(m.group(1)!), b = int.parse(m.group(2)!);
        if (b > 12 && a <= 12) (a, b) = (b, a);
        return _validDate(now.year, b, a, now, explicitYear: false);
      });
    }

    final lower = text.toLowerCase();
    if (found == null) {
      if (RegExp(r'\byesterday\b').hasMatch(lower) || lower.contains('أمس')) {
        found = DateTime(now.year, now.month, now.day - 1);
      } else if (RegExp(r'\btoday\b').hasMatch(lower) ||
          lower.contains('اليوم')) {
        found = DateTime(now.year, now.month, now.day);
      }
    }

    // A time is only useful together with a date; mask it either way so
    // "12:30" is never read as an amount.
    for (final m in _time.allMatches(text)) {
      if (_overlaps(blocked, m.start, m.end)) continue;
      var hour = int.parse(m.group(1)!);
      final minute = int.parse(m.group(2)!);
      if (hour > 23 || minute > 59) continue;
      blocked.add(_Span(m.start, m.end));
      final meridiem = m.group(4)?.toLowerCase();
      if (meridiem == 'pm' && hour < 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;
      final day = found;
      if (day != null && day.hour == 0 && day.minute == 0) {
        found = DateTime(day.year, day.month, day.day, hour, minute);
      }
    }
    return found;
  }

  static int? _year(String? raw) {
    if (raw == null) return null;
    final y = int.parse(raw);
    return y < 100 ? 2000 + y : y;
  }

  static DateTime? _validDate(
    int year,
    int month,
    int day,
    DateTime now, {
    required bool explicitYear,
  }) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    var date = DateTime(year, month, day);
    if (date.month != month) return null; // 31/02
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (!explicitYear && date.isAfter(tomorrow)) {
      date = DateTime(year - 1, month, day);
    }
    if (date.isAfter(tomorrow)) return null;
    if (now.difference(date).inDays > 366 * 5) return null;
    return date;
  }

  // ------------------------------------------------------------- currency

  static final _currencyTokens = <(RegExp, String)>[
    for (final (pattern, code) in const [
      (r'ريال\s*سعودي|ر\.\s?س', 'SAR'),
      (r'ريال\s*قطري|ر\.\s?ق', 'QAR'),
      (r'ريال\s*عماني|ر\.\s?ع', 'OMR'),
      (r'دينار\s*كويتي|د\.\s?ك', 'KWD'),
      (r'دينار\s*بحريني|د\.\s?ب', 'BHD'),
      (r'دينار\s*أردني|دينار\s*اردني', 'JOD'),
      (r'جنيه(?:ا|اً|ًا)?(?:\s*مصري)?|ج\.\s?م', 'EGP'),
      (r'درهم|د\.\s?إ', 'AED'),
      (r'دولار', 'USD'),
      (r'يورو', 'EUR'),
      (r'ريال', 'SAR'),
      (r'US\$', 'USD'),
      (r'(?<![A-Za-z])L\.E\.?(?![A-Za-z])|(?<![A-Za-z])LE(?![A-Za-z])', 'EGP'),
      (r'(?<![A-Za-z])Dhs?\.?(?![A-Za-z])', 'AED'),
      (r'(?<![A-Za-z])KD(?![A-Za-z])', 'KWD'),
      (r'(?<![A-Za-z])SR(?![A-Za-z])', 'SAR'),
      (r'(?<![A-Za-z])Rs\.?(?![A-Za-z])|₹', 'INR'),
      (r'\$', 'USD'),
      (r'£', 'GBP'),
      (r'€', 'EUR'),
      (r'₺', 'TRY'),
    ])
      (RegExp(pattern), code),
    (
      RegExp(
        r'(?<![A-Za-z])(USD|EGP|EUR|GBP|SAR|AED|JPY|CNY|INR|KWD|QAR|BHD|OMR|JOD|TND|TRY|CHF|CAD|AUD|MAD|LBP|PKR)(?![A-Za-z])',
        caseSensitive: false,
      ),
      '',
    ),
  ];

  static List<_Currency> _currencies(String text) {
    final found = <_Currency>[];
    for (final (pattern, code) in _currencyTokens) {
      for (final m in pattern.allMatches(text)) {
        if (found.any((c) => m.start < c.end && m.end > c.start)) continue;
        found.add(
          _Currency(
            m.start,
            m.end,
            code.isEmpty ? m.group(1)!.toUpperCase() : code,
          ),
        );
      }
    }
    found.sort((a, b) => a.start.compareTo(b.start));
    return found;
  }

  // --------------------------------------------------------------- amount

  static final _number = RegExp(
    r'(?<![\d.,])(\d{1,3}(?:[ ,]\d{3})+(?:[.,]\d{1,3})?|\d{1,3}(?:\.\d{3})+(?:,\d{1,3})?|\d+(?:[.,]\d{1,3})?)(?!\d)(\s?[kK](?![A-Za-z]))?',
  );

  static final _txnVerb = RegExp(
    r'\b(?:spent|paid|pay|payment|purchase|purchased|debited|credited|received|deposit|deposited|charged|withdrawal|withdrawn|refund|refunded|transfer|transferred|sent|amount|total|value|of|for)\b|خصم|مبلغ|بمبلغ|بقيمة|إيداع|ايداع|سحب|شراء|تحويل|استلام|دفع|قيمة',
    caseSensitive: false,
  );

  static final _balanceWord = RegExp(
    r'\b(?:balance|bal|available|avail|avl|limit|outstanding)\b|رصيد|الرصيد|المتاح|الحد',
    caseSensitive: false,
  );

  static _AmountResult _extractAmount(
    String text,
    List<_Span> blocked,
    _Classification kinds,
  ) {
    final currencies = _currencies(text);
    final numbers = <_Number>[];
    for (final m in _number.allMatches(text)) {
      final rawEnd = m.start + m.group(1)!.length;
      if (_overlaps(blocked, m.start, rawEnd)) continue;
      numbers.add(_Number(m.start, m.end, m.group(1)!, m.group(2) != null));
    }

    // Bind each currency token to the number right next to it. A token between
    // two numbers goes to the closer one, preferring one with decimals.
    for (final c in currencies) {
      _Number? before, after;
      for (final n in numbers) {
        if (n.end <= c.start && _gapOk(text, n.end, c.start)) before = n;
        if (n.start >= c.end && _gapOk(text, c.end, n.start)) {
          after ??= n;
        }
      }
      _Number? chosen;
      if (before != null && after != null) {
        if (after.hasDecimal != before.hasDecimal) {
          chosen = after.hasDecimal ? after : before;
        } else {
          chosen = (c.start - before.end) <= (after.start - c.end)
              ? before
              : after;
        }
      } else {
        chosen = before ?? after;
      }
      if (chosen != null && chosen.currency == null) chosen.currency = c.code;
    }

    var sawBalance = false;
    _Number? best;
    var bestScore = -1 << 30;
    var runnerUp = -1 << 30;
    final plain = <_Number>[];

    for (final n in numbers) {
      final value = n.parse();
      if (value == null) continue;
      final digits = n.raw.replaceAll(RegExp(r'\D'), '');
      if (!n.hasDecimal && n.currency == null && digits.length >= 9) continue;

      var score = 0;
      if (n.currency != null) score += 4;
      if (n.hasDecimal) score += 2;
      final before = text.substring((n.start - 30).clamp(0, text.length), n.start);
      final verb = _txnVerb.allMatches(before).lastOrNull;
      if (verb != null) score += 2;
      final balance = _balanceWord.allMatches(before).lastOrNull;
      final nearBalance =
          balance != null &&
          before.length - balance.end <= 22 &&
          (verb == null || verb.start < balance.start);
      if (nearBalance) {
        score -= 8;
        sawBalance = true;
      }
      if (kinds.kind == TransactionKind.otp &&
          n.currency == null &&
          !n.hasDecimal) {
        score -= 6;
      }
      if (!n.hasDecimal &&
          n.currency == null &&
          RegExp(r'^(19|20)\d{2}$').hasMatch(digits)) {
        score -= 3;
      }
      n.score = score;
      n.value = value;
      if (!nearBalance) plain.add(n);
      if (score > bestScore) {
        runnerUp = bestScore;
        bestScore = score;
        best = n;
      } else if (score > runnerUp) {
        runnerUp = score;
      }
    }

    if (best == null || bestScore <= 0) {
      // A lone unlabelled number still counts ("Starbucks 5") unless the
      // message is a code or only reports a balance.
      final lone = plain.length == 1 ? plain.single : null;
      if (lone != null &&
          lone.score >= 0 &&
          kinds.kind != TransactionKind.otp) {
        return _AmountResult(lone.value, lone.currency, 0.45, sawBalance);
      }
      return _AmountResult(null, null, 0, sawBalance);
    }

    var confidence = 0.5;
    if (best.currency != null) confidence += 0.25;
    if (best.hasDecimal) confidence += 0.1;
    if (bestScore >= 6) confidence += 0.1;
    if (runnerUp > 0 && bestScore - runnerUp <= 1) confidence -= 0.25;
    return _AmountResult(
      best.value,
      best.currency,
      confidence.clamp(0.0, 0.95),
      sawBalance,
    );
  }

  static bool _gapOk(String text, int from, int to) =>
      to - from <= 3 && RegExp(r'^[\s:]*$').hasMatch(text.substring(from, to));

  // ---------------------------------------------------------- type / kind

  static final _rules = <_Rule>[
    // Not money movements; checked before everything else.
    _Rule(
      TransactionKind.otp,
      null,
      9,
      r'\botp\b|\bone[\s-]?time\s*(?:password|code|pin)|\bverification\s*code|\bsecurity\s*code|\bpasscode\b|\bdo\s*not\s*share\b|رمز\s*التحقق|كلمة\s*المرور|لا\s*تشارك',
    ),
    _Rule(
      TransactionKind.declined,
      null,
      9,
      r'\bdeclined\b|\bwas\s*not\s*(?:completed|successful|processed)|\bunsuccessful\b|\bfailed\b|\brejected\b|\binsufficient\s*(?:funds|balance)|\bcould\s*not\s*be\s*processed|مرفوض|فشل|لم\s*تتم|غير\s*ناجح|رصيد\s*غير\s*كا',
    ),
    _Rule(
      TransactionKind.paymentDue,
      null,
      9,
      r'\bpayment\s*(?:is\s*)?due\b|\bdue\s*date\b|\bminimum\s*(?:payment|amount)|\bis\s*due\b|\boverdue\b|\bplease\s*pay\b|مستحق|تاريخ\s*الاستحقاق|الحد\s*الأدنى\s*للسداد',
    ),
    _Rule(
      TransactionKind.promo,
      null,
      1,
      r'\boffer\b|\bdiscount\b|\bpromo\b|\bchance\s*to\s*win\b|\bwin\b|%\s*off\b|\bget\s*up\s*to\b|\buse\s*code\b|\bsubscribe\s*now\b|\bcashback\s*offer|عرض|اربح|كوبون|خصم\s*\d+\s*%',
    ),
    // Income.
    _Rule(
      TransactionKind.refund,
      'income',
      3,
      r'\brefund(?:ed)?\b|\breversal\b|\breversed\b|\breturned\b|استرداد|مرتجع',
    ),
    _Rule(
      TransactionKind.salary,
      'income',
      3,
      r'\bsalary\b|\bpayroll\b|\bwages\b|راتب|مرتب',
    ),
    _Rule(
      TransactionKind.transferIn,
      'income',
      2,
      r'\bcredited\b|\breceived\b|\bdeposit(?:ed)?\b|\bincoming\s*transfer|\bcash\s*in\b|\badded\s*to\s*your\b|إيداع|ايداع|استلام|استلمت|وارد|أضيف|اضيف|إضافة|اضافة|دائن',
    ),
    // Expense.
    _Rule(
      TransactionKind.atm,
      'expense',
      3,
      r'\batm\b|\bcash\s*withdrawal\b|سحب\s*نقدي|ماكينة',
    ),
    _Rule(
      TransactionKind.transferOut,
      'expense',
      2,
      r'\bsent\b|\btransferred\s*to\b|\btransfer\s*to\b|\boutgoing\s*transfer|تحويل\s*صادر|تم\s*تحويل',
    ),
    _Rule(
      TransactionKind.purchase,
      'expense',
      2,
      r'\bspent\b|\bpurchase[ds]?\b|\bpaid\b|\bdebited\b|\bcharged\b|\bpayment\s*of\b|\bwithdrawn\b|\bwithdrawal\b|\bpos\b|\btap\s*to\s*pay\b|\bapple\s*pay\b|\bgoogle\s*pay\b|خصم|شراء|دفع|مدين|سحب',
    ),
    _Rule(
      TransactionKind.fee,
      'expense',
      1,
      r'\bfees?\b|\bcommission\b|\bannual\s*fee|رسوم|عمولة',
    ),
  ];

  static _Classification _classify(String text) {
    var income = 0, expense = 0;
    TransactionKind? incomeKind, expenseKind, blocker;
    var incomeKindWeight = 0, expenseKindWeight = 0;
    var promo = 0;

    for (final rule in _rules) {
      final hits = rule.pattern.allMatches(text).length;
      if (hits == 0) continue;
      if (rule.type == null) {
        if (rule.kind == TransactionKind.promo) {
          promo += hits;
        } else {
          blocker ??= rule.kind;
        }
        continue;
      }
      final weight = rule.weight * (hits > 1 ? 2 : 1);
      if (rule.type == 'income') {
        income += weight;
        if (rule.weight > incomeKindWeight) {
          incomeKind = rule.kind;
          incomeKindWeight = rule.weight;
        }
      } else {
        expense += weight;
        if (rule.weight > expenseKindWeight) {
          expenseKind = rule.kind;
          expenseKindWeight = rule.weight;
        }
      }
    }

    final type = income > expense ? 'income' : 'expense';
    final winner = type == 'income' ? income : expense;
    final loser = type == 'income' ? expense : income;
    final confidence = winner == 0
        ? 0.35
        : loser == 0 && winner >= 2
        ? 0.9
        : winner > loser
        ? 0.7
        : 0.5;

    TransactionKind kind;
    if (blocker != null) {
      kind = blocker;
    } else if (promo > 0 && (income + expense < 3 || promo >= 2)) {
      kind = TransactionKind.promo;
    } else {
      kind =
          (type == 'income' ? incomeKind : expenseKind) ??
          TransactionKind.unknown;
    }
    return _Classification(type, kind, confidence);
  }

  // ------------------------------------------------------------- merchant

  static final _markers = <(RegExp, int)>[
    (RegExp(r'\bmerchant\s*[:\-]?\s*', caseSensitive: false), 4),
    (RegExp(r'\bat\s+', caseSensitive: false), 3),
    (RegExp(r'(?<![\w.])@\s*'), 3),
    (RegExp(r'لدى\s+'), 3),
    (RegExp(r'عند\s+'), 3),
    (RegExp(r'\bfrom\s+', caseSensitive: false), 2),
    (RegExp(r'\bto\s+', caseSensitive: false), 2),
    (RegExp(r'\bvia\s+', caseSensitive: false), 1),
    (RegExp(r'(?<!\S)(?:من|إلى|الى)\s+'), 1),
    (RegExp(r'(?<!\S)في\s+'), 1),
  ];

  static final _merchantStop = RegExp(
    r'\s+(?:on|using|with|has|have|had|was|were|is|ending|card|account|a/c|ref|reference|balance|available|avl|avail|for|dated|date|from|to|at|via|and|your|amount|by|thank|thanks|USD|EGP|EUR|GBP|SAR|AED|KWD|QAR|BHD|OMR)\b'
    r'|[,;:()|*\n]|\s+-\s+'
    r'|(?<!\b(?:St|Mt|Dr|Co|Mr|Ms|Jr))\.(?=\s|$)'
    r'|\s+\d{2,}'
    r'|\s+(?:بتاريخ|في|الرصيد|رصيد|من|على|بمبلغ|بقيمة|عبر|بطاقة|بطاقتك|رقم)(?=\s|$)',
    caseSensitive: false,
  );

  static final _rejectMerchant = RegExp(
    r'^(?:your|you|my|our|the\s+account|account|card|a/c|acct|wallet|mobile|number|حسابك|حساب|بطاقتك|بطاقة|رقم|محفظتك)(?=[\s.,]|$)',
    caseSensitive: false,
  );

  static _Field _extractMerchant(String text, String type) {
    var best = '';
    var bestScore = 0;
    for (final (marker, weight) in _markers) {
      for (final m in marker.allMatches(text)) {
        var rest = text.substring(m.end);
        final stop = _merchantStop.firstMatch(rest);
        if (stop != null) rest = rest.substring(0, stop.start);
        rest = rest.trim().replaceAll(RegExp(r'[.,\-]+$'), '').trim();
        if (rest.length < 2 ||
            RegExp(r'^[\d\s.,]+$').hasMatch(rest) ||
            _rejectMerchant.hasMatch(rest)) {
          continue;
        }
        if (rest.length > 40) rest = rest.substring(0, 40).trim();
        var score = weight;
        if (RegExp(r'^[A-Z؀-ۿ]').hasMatch(rest)) score += 1;
        final word = m.group(0)!.trim().toLowerCase();
        if (type == 'income' && (word == 'from' || word == 'من')) score += 1;
        if (type == 'expense' && (word == 'at' || word == 'to')) score += 1;
        if (score > bestScore) {
          bestScore = score;
          best = rest;
        }
      }
    }
    if (best.isEmpty) return const _Field('', 0);
    return _Field(best, bestScore >= 4 ? 0.85 : bestScore >= 3 ? 0.65 : 0.45);
  }

  /// Key used to remember a merchant: "SQ *Blue Bottle #12 LLC" →
  /// "blue bottle".
  static String normalizeMerchant(String merchant) {
    var key = merchant.toLowerCase().trim();
    key = key.replaceFirst(
      RegExp(r'^(?:sq|tst|apl|pp|paypal|pos|ecom|sumup|zettle|izettle|mp|amzn)\s*\*\s*'),
      '',
    );
    key = key.replaceFirst(RegExp(r'^(?:pos|ecom|purchase)\s+'), '');
    key = key
        .replaceAll(RegExp(r'#\s*\d+'), ' ')
        .replaceAll(RegExp(r'\b\d{2,}\b'), ' ')
        .replaceAll(
          RegExp(
            r'\b(?:llc|ltd|inc|co|corp|sae|s\.a\.e|fzco|fze|fz|llp|plc|gmbh|est)\b\.?',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s&]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return key;
  }

  // ----------------------------------------------------------- confidence

  static double _overall(
    Map<String, double> f,
    bool hasAmount,
    TransactionKind kind,
  ) {
    var score =
        f['amount']! * 0.45 +
        f['type']! * 0.25 +
        f['merchant']! * 0.15 +
        f['currency']! * 0.1 +
        f['date']! * 0.05;
    if (!hasAmount) score = score.clamp(0.0, 0.3);
    if (kind == TransactionKind.unknown) score *= 0.8;
    return double.parse(score.clamp(0.0, 0.97).toStringAsFixed(3));
  }
}

class _Span {
  const _Span(this.start, this.end);
  final int start, end;
}

class _Currency {
  const _Currency(this.start, this.end, this.code);
  final int start, end;
  final String code;
}

class _Number {
  _Number(this.start, this.end, this.raw, this.thousands);
  final int start, end;
  final String raw;
  final bool thousands;
  String? currency;
  int score = 0;
  Amount? value;

  bool get hasDecimal {
    final canonical = TextNormalizer.canonicalNumber(raw, currency: currency);
    return canonical != null && canonical.contains('.');
  }

  Amount? parse() {
    final canonical = TextNormalizer.canonicalNumber(raw, currency: currency);
    if (canonical == null) return null;
    var amount = Amount(canonical);
    if (thousands) amount = amount * Amount('1000');
    return amount > Amount.zero ? amount : null;
  }
}

class _AmountResult {
  const _AmountResult(this.value, this.currency, this.confidence, this.sawBalance);
  final Amount? value;
  final String? currency;
  final double confidence;
  final bool sawBalance;
}

class _Rule {
  _Rule(this.kind, this.type, this.weight, String pattern)
    : pattern = RegExp(pattern, caseSensitive: false);
  final TransactionKind kind;
  final String? type;
  final int weight;
  final RegExp pattern;
}

class _Classification {
  const _Classification(this.type, this.kind, this.confidence);
  final String type;
  final TransactionKind kind;
  final double confidence;
}

class _Field {
  const _Field(this.value, this.confidence);
  final String value;
  final double confidence;
}
