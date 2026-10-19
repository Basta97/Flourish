import '../../domain/finance/models.dart';
import '../utils/amount_parser.dart';
import 'issuers.dart';
import 'lexicon.dart';
import 'normalizer.dart';
import 'parsed_payment.dart';
import 'redact.dart';

/// Reads Egyptian bank and wallet messages (SMS or app notifications, in
/// English or Arabic) into a [ParsedPayment].
///
/// It never guesses silently: numbers count as money only next to a
/// currency or an amount word, balances and limits are told apart from the
/// payment, and OTP, declined and promotional messages are ignored.
class PaymentMessageParser {
  PaymentMessageParser._();

  /// Space-grouped thousands ("12 000") first, then any digit run.
  static final _number = RegExp(
    r'(?<![\d])\d{1,3}(?: \d{3})+(?:[.,]\d+)?(?![\d])|(?<![\d])\d[\d,.]*',
  );
  static final _amountWord = RegExp(
    r'(amount|value|sum|of|paid|spent|charged|debited|credited|deducted|'
    r'withdrawn|مبلغ|بمبلغ|بقيمه|قيمه|قدره)\s*:?\s*$',
  );

  /// "Card 4521 EGP 250.00": a card's last 4 right after the word card is
  /// never the amount, even with a currency next to it.
  static final _cardBefore = RegExp(
    r'(?:card|بطاقه|بطاقتك|بطاقتكم)\s*(?:no\.?|number|رقم)?\s*:?\s*$',
  );
  static final _thousands = RegExp(r'^\s?k(?![a-z])');
  static final _creditCard = RegExp(
    r'credit card|بطاقه (?:\S+ ){0,3}الائتمان|البطاقه الائتمانيه|ائتمانيه',
  );
  static final _limitWord = RegExp(
    r'limit|\bcredit\b|(?:^|\s|[,.])(?:و|ال|وال)?حد\s',
  );
  static final _arabicLetter = RegExp(r'[؀-ۿ]');
  static final _latinLetter = RegExp(r'[a-z]');

  static ParsedPayment parse(RawMessage message) {
    final text = MessageNormalizer.clean(message.text);
    final f = MessageNormalizer.fold(text);
    if (text.isEmpty) return const ParsedPayment.ignored('no_amount');
    if (Lexicon.otp.hasMatch(f)) return const ParsedPayment.ignored('otp');
    if (Lexicon.declined.hasMatch(f)) {
      return const ParsedPayment.ignored('declined');
    }
    if (Lexicon.due.hasMatch(f) && !Lexicon.dueSettled.hasMatch(f)) {
      return const ParsedPayment.ignored('notice');
    }
    final kind = _kind(f);
    if (Lexicon.notice.hasMatch(f) && !Lexicon.confirmed.hasMatch(f)) {
      return const ParsedPayment.ignored('notice');
    }
    if (Lexicon.promo.hasMatch(f) &&
        (kind == null || !Lexicon.confirmed.hasMatch(f))) {
      return const ParsedPayment.ignored('promo');
    }

    final candidates = _amounts(text, f);
    final payments = candidates.where((c) => c.role == _Role.amount).toList();
    if (payments.isEmpty) return const ParsedPayment.ignored('no_amount');
    final main = payments.first;
    final booked = candidates
        .where((c) => c.role == _Role.equivalent)
        .firstOrNull;
    var balance = candidates.where((c) => c.role == _Role.balance).firstOrNull;
    var limit = candidates.where((c) => c.role == _Role.limit).firstOrNull;
    final intlLimit = candidates
        .where((c) => c.role == _Role.intlLimit)
        .firstOrNull;
    // On a credit card the "available balance" is the credit left.
    if (balance != null && _creditCard.hasMatch(f)) {
      limit = balance;
      balance = null;
    }
    final fee = candidates.where((c) => c.role == _Role.fee).firstOrNull;
    final issuer = Issuers.match(sender: message.sender, text: text);

    final direction = switch (kind) {
      'refund' || 'deposit' || 'transfer_in' || 'card_payment' => 'income',
      _ => 'expense',
    };
    final counterparty = switch (kind) {
      'transfer_out' => _name(text, f, Lexicon.toLead, after: main.end),
      'transfer_in' => _name(text, f, Lexicon.fromLead, after: 0),
      _ => null,
    };
    final merchant = switch (kind) {
      'transfer_out' ||
      'transfer_in' ||
      'deposit' ||
      'card_payment' ||
      'withdrawal' => null,
      'refund' =>
        _name(text, f, Lexicon.merchantLead, after: 0) ??
            _name(text, f, Lexicon.fromLead, after: main.end),
      // "لشراء من FAWRY": a purchase or bill names the shop after "from".
      _ =>
        _merchant(text, f, main) ??
            _name(text, f, Lexicon.fromLead, after: main.end),
    };
    final last4 = _last4(f);
    final occurredAt = _date(f, message.receivedAt);
    final reference = Lexicon.reference.firstMatch(f)?.group(1)?.toUpperCase();

    var confidence = 0.2 + 0.3;
    if (main.currency != null) confidence += 0.1;
    if (kind != null) confidence += 0.15;
    if (issuer != null) confidence += 0.1;
    if (last4 != null) confidence += 0.05;
    if (merchant != null || counterparty != null) confidence += 0.05;
    if (occurredAt != null) confidence += 0.05;

    return ParsedPayment(
      kind: kind,
      direction: direction,
      amount: main.value,
      currency: main.currency,
      bookedAmount: booked?.value,
      bookedCurrency: booked?.currency,
      fee: fee?.value,
      last4: last4,
      merchant: merchant,
      counterparty: counterparty == null ? null : redact(counterparty),
      reference: reference,
      issuerId: issuer?.id,
      occurredAt: occurredAt ?? message.receivedAt,
      balanceAfter: balance?.value,
      availableCredit: limit?.value,
      availableIntlCredit: intlLimit?.value,
      confidence: confidence > 0.99 ? 0.99 : confidence,
    );
  }

  static String? _kind(String f) {
    if (Lexicon.refund.hasMatch(f)) return 'refund';
    if (Lexicon.cardPayment.hasMatch(f)) return 'card_payment';
    if (Lexicon.withdrawal.hasMatch(f)) return 'withdrawal';
    if (Lexicon.salary.hasMatch(f) &&
        (Lexicon.deposit.hasMatch(f) || Lexicon.transferIn.hasMatch(f))) {
      return 'deposit';
    }
    if (Lexicon.transferIn.hasMatch(f)) return 'transfer_in';
    if (Lexicon.transferOut.hasMatch(f)) return 'transfer_out';
    if (Lexicon.bill.hasMatch(f)) return 'bill_payment';
    if (Lexicon.deposit.hasMatch(f)) return 'deposit';
    if (Lexicon.purchase.hasMatch(f)) return 'purchase';
    return null;
  }

  static bool _isLetter(String c) =>
      _latinLetter.hasMatch(c) || _arabicLetter.hasMatch(c);

  /// The currency written right before [start] or right after [end].
  static String? _currencyNear(String f, int start, int end) {
    final before = f.substring(start - 14 < 0 ? 0 : start - 14, start);
    final after = f.substring(end, end + 16 > f.length ? f.length : end + 16);
    for (final (token, code) in Lexicon.currencies) {
      final b = before.trimRight();
      if (b.endsWith(token)) {
        final at = b.length - token.length;
        final letterToken = _isLetter(token[0]);
        if (!letterToken || at == 0 || !_isLetter(b[at - 1])) return code;
      }
      final a = after.trimLeft();
      if (a.startsWith(token)) {
        final letterToken = _isLetter(token[token.length - 1]);
        if (!letterToken ||
            a.length == token.length ||
            !_isLetter(a[token.length])) {
          return code;
        }
      }
    }
    return null;
  }

  static List<_Candidate> _amounts(String text, String f) {
    final out = <_Candidate>[];
    for (final m in _number.allMatches(text)) {
      var raw = m.group(0)!;
      // A sentence's full stop or comma is not part of the number.
      raw = raw.replaceAll(RegExp(r'[.,]+$'), '');
      if (raw.isEmpty) continue;
      final start = m.start;
      var end = m.start + raw.length;
      final prev = start > 0 ? text[start - 1] : '';
      final next = end < text.length ? text[end] : '';
      final next2 = end + 1 < text.length ? text[end + 1] : '';
      // Dates, times, masked cards and phone numbers are never amounts.
      if ('/-:'.contains(next) && RegExp(r'\d').hasMatch(next2)) continue;
      if ('/-:'.contains(prev) &&
          start > 1 &&
          RegExp(r'\d').hasMatch(text[start - 2])) {
        continue;
      }
      if ('x*•#X'.contains(prev) && prev.isNotEmpty) continue;
      if (RegExp(r'^0?1[0125]\d{8}$').hasMatch(raw)) continue;
      final window = f.substring(start - 40 < 0 ? 0 : start - 40, start);
      if (RegExp(r'^\d{4}$').hasMatch(raw) && _cardBefore.hasMatch(window)) {
        continue;
      }
      // "1.5k EGP": thousands suffix.
      final k = _thousands.firstMatch(f.substring(end));
      if (k != null) end += k.end;
      final currency = _currencyNear(f, start, end);
      if (currency == null && !_amountWord.hasMatch(window)) continue;
      final parsed = AmountParser.parse(
        raw,
        currency: currency ?? 'EGP',
        lenient: true,
      );
      if (!parsed.isValid) continue;
      var value = parsed.value!;
      if (k != null) value = value * Amount('1000');
      final balance = Lexicon.balanceLabel.firstMatch(window);
      final spentAfterBalance =
          balance != null &&
          Lexicon.spendVerb.hasMatch(window.substring(balance.start));
      final role = Lexicon.equivalentLabel.hasMatch(window)
          ? _Role.equivalent
          : Lexicon.feeLabel.hasMatch(window)
          ? _Role.fee
          : balance != null && !spentAfterBalance
          ? (Lexicon.intlLabel.hasMatch(_clause(_label(window)))
                ? _Role.intlLimit
                : _limitWord.hasMatch(_label(window))
                ? _Role.limit
                : _Role.balance)
          : _Role.amount;
      out.add(_Candidate(value, currency, start, end, role));
    }
    return out;
  }

  /// The words since the previous number, at most 40 characters.
  static String _label(String window) {
    final label = window.split(RegExp(r'\d')).last;
    return label.length > 40 ? label.substring(label.length - 40) : label;
  }

  /// The last clause of [label]: "international purchase at X. available
  /// limit" is about the local limit.
  static String _clause(String label) => label
      .replaceAllMapped(RegExp(r'\b(intl|avail|int)\.'), (m) => m[1]!)
      .split(RegExp(r'[.!;،,؛\n]'))
      .last;

  static String? _last4(String f) {
    for (final pattern in Lexicon.last4) {
      final m = pattern.firstMatch(f);
      if (m != null) return m.group(1);
    }
    return null;
  }

  static String? _merchant(String text, String f, _Candidate main) {
    final named = _name(text, f, Lexicon.merchantLead, after: 0);
    if (named != null) return named;
    // "Purchase USD 12.99 NETFLIX.COM": the name right after the amount.
    var at = main.end;
    final rest = f.substring(at);
    final skip = RegExp(
      r'^\s*([a-z$€£.]{1,4}\s+|[؀-ۿ.]{1,6}\s+)?',
    ).firstMatch(rest);
    if (main.currency != null && skip != null) at += skip.end;
    return _cut(text, f, at);
  }

  static String? _name(
    String text,
    String f,
    RegExp lead, {
    required int after,
  }) {
    for (final m in lead.allMatches(f)) {
      if (m.end < after) continue;
      final name = _cut(text, f, m.end);
      if (name != null) return name;
    }
    return null;
  }

  static final _chargeCode = RegExp(r'\s*\*\s*(?=[A-Z0-9]*\d)[A-Z0-9]{5,}$');
  static final _leading = RegExp(
    r'^(?:from|to|at|for|من|الي|الى|إلى|لدى|لدي|عند|في|على|علي)\s+',
    caseSensitive: false,
  );
  static final _notName = RegExp(
    r'^(?:your|the|a|an|due|on|for|to|from|of|account|card|'
    r'بطاقتك|حسابك|لحسابك|حساب|ماكينه|ماكينة|الصراف|رقم|مبلغ|بتاريخ|يوم)(?=\s|$|[.,])',
    caseSensitive: false,
  );

  /// The name starting at [at], up to the next delimiter.
  static String? _cut(String text, String f, int at) {
    if (at >= text.length) return null;
    // Skip one leading preposition ("from B.TECH", "من حسابك").
    while (at < text.length && text[at] == ' ') {
      at++;
    }
    final lead = _leading.firstMatch(text.substring(at));
    if (lead != null) at += lead.end;
    final end = Lexicon.nameEnd.firstMatch(f.substring(at));
    var name = text
        .substring(at, end == null ? text.length : at + end.start)
        .trim();
    if (_notName.hasMatch(name)) return null;
    // "FACEBK *Q9AWVA6": the processor's per-charge code is not the name.
    name = name.replaceFirst(_chargeCode, '');
    if (name.length > 40) name = name.substring(0, 40).trim();
    final phone = RegExp(r'^\+?\d{10,15}$').hasMatch(name);
    if (name.length < 2 ||
        (!phone && RegExp(r'^[\d\s.,]+$').hasMatch(name)) ||
        _currencyNear(MessageNormalizer.fold(' $name'), 1, 1) != null &&
            name.length <= 4) {
      return null;
    }
    // "your card", "your account" are not merchants.
    if (RegExp(
      r'^(your|the|a|an|بطاقتك|حسابك)\b',
      caseSensitive: false,
    ).hasMatch(name)) {
      return null;
    }
    return name;
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    'يناير': 1, 'فبراير': 2, 'مارس': 3, 'ابريل': 4, 'مايو': 5, 'يونيو': 6,
    'يوليو': 7, 'اغسطس': 8, 'سبتمبر': 9, 'اكتوبر': 10, 'نوفمبر': 11,
    'ديسمبر': 12,
  };

  static DateTime? _date(String f, DateTime received) {
    int? day, month, year;
    final iso = RegExp(
      r'(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)',
    ).firstMatch(f);
    final numeric = RegExp(
      r'(?<!\d)(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?(?!\d)',
    ).firstMatch(f);
    final named = RegExp(
      '(?<!\\d)(\\d{1,2})[\\s-]*(${_months.keys.join('|')})[a-z]*'
      r'(?:[\s,-]*(\d{4}))?',
    ).firstMatch(f);
    if (iso != null) {
      year = int.parse(iso.group(1)!);
      month = int.parse(iso.group(2)!);
      day = int.parse(iso.group(3)!);
    } else if (numeric != null) {
      day = int.parse(numeric.group(1)!);
      month = int.parse(numeric.group(2)!);
      final y = numeric.group(3);
      year = y == null
          ? null
          : (y.length == 2 ? 2000 + int.parse(y) : int.parse(y));
    } else if (named != null) {
      day = int.parse(named.group(1)!);
      month = _months[named.group(2)!];
      year = named.group(3) == null ? null : int.parse(named.group(3)!);
    }
    if (day == null ||
        month == null ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return null;
    }
    var hour = received.hour, minute = received.minute;
    final time = RegExp(
      r'(?<!\d)(\d{1,2}):(\d{2})(?::\d{2})?\s*(am|pm|ص|م)?(?![a-z؀-ۿ])',
    ).firstMatch(f);
    if (time != null) {
      hour = int.parse(time.group(1)!);
      minute = int.parse(time.group(2)!);
      final half = time.group(3);
      if ((half == 'pm' || half == 'م') && hour < 12) hour += 12;
      if ((half == 'am' || half == 'ص') && hour == 12) hour = 0;
      if (hour > 23 || minute > 59) {
        hour = received.hour;
        minute = received.minute;
      }
    }
    var date = DateTime(year ?? received.year, month, day, hour, minute);
    // "15/12" read in January belongs to the previous year.
    if (year == null && date.isAfter(received.add(const Duration(days: 1)))) {
      date = DateTime(received.year - 1, month, day, hour, minute);
    }
    if (date.month != month) return null;
    return date;
  }
}

enum _Role { amount, balance, limit, intlLimit, fee, equivalent }

class _Candidate {
  final Amount value;
  final String? currency;
  final int start, end;
  final _Role role;
  const _Candidate(this.value, this.currency, this.start, this.end, this.role);
}
