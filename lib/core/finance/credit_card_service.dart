import 'package:drift/drift.dart';
import '../../data/database/database.dart';
import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';
import '../utils/currency_formatter.dart';
import 'contract_service.dart';
import 'financial_ledger_service.dart';

/// A figure the bank stated in a message, e.g. "Available limit EGP 5,000".
class ReportedLimit {
  final Amount value;
  final DateTime at;
  const ReportedLimit(this.value, this.at);
}

/// Where a credit card stands today. Amounts are in the card's currency;
/// [owed] is positive when money is owed.
class CreditStatus {
  final String currency;
  final Amount owed, available, overLimitBy;
  final Amount? limit;

  /// Share of the limit in use, 0–1+ (null without a limit).
  final double? utilization;

  /// Balance at the last statement closing and what is still unpaid of it.
  final Amount statementBalance, statementRemaining;
  final Amount minimumDue, paymentsSinceClosing;

  /// Interest likely charged next statement if [statementRemaining] is not
  /// paid by the due date, plus interest on cash advances. An estimate.
  final Amount interestEstimate;
  final Amount cashAdvanceBalance;
  final DateTime? closing, due;
  final CardTerms? terms;

  /// The international limit, what of it is in use (unpaid spending in
  /// other currencies and its fees) and what is left of it; null without
  /// an international limit. [intlAvailable] never exceeds [available].
  final Amount? intlLimit, intlUsed, intlAvailable;
  final Amount intlOverLimitBy;

  /// The latest available limits a bank message stated, if any.
  final ReportedLimit? bankAvailable, bankIntlAvailable;
  CreditStatus({
    required this.currency,
    required this.owed,
    required this.available,
    required this.overLimitBy,
    required this.limit,
    required this.utilization,
    required this.statementBalance,
    required this.statementRemaining,
    required this.minimumDue,
    required this.paymentsSinceClosing,
    required this.interestEstimate,
    required this.cashAdvanceBalance,
    required this.closing,
    required this.due,
    required this.terms,
    this.intlLimit,
    this.intlUsed,
    this.intlAvailable,
    Amount? intlOverLimitBy,
    this.bankAvailable,
    this.bankIntlAvailable,
  }) : intlOverLimitBy = intlOverLimitBy ?? Amount.zero;
  bool get hasTerms => terms != null;

  /// How far spending [spend] more would go over a limit, or null when it
  /// fits (or the card has no limit). [foreign] spending also counts against
  /// the international limit; [international] says which limit it breaks.
  ({Amount by, bool international})? overAfter(
    Amount spend, {
    bool foreign = false,
  }) {
    final total = limit != null && spend > available ? spend - available : null;
    final intl = foreign && intlAvailable != null && spend > intlAvailable!
        ? spend - intlAvailable!
        : null;
    if (intl != null && (total == null || intl > total)) {
      return (by: intl, international: true);
    }
    return total == null ? null : (by: total, international: false);
  }
}

/// Credit card setup and status, built on the card's billing contract so
/// statements, reminders and backups keep working as before.
class CreditCardService {
  final FinancialLedgerService ledger;
  CreditCardService(this.ledger);
  AppDatabase get db => ledger.db;
  FinanceStore get store => ledger.store;

  static const reportsCollection = 'cardLimitReports';

  /// Keeps the available limits a bank message stated at [at], unless a
  /// newer message already said otherwise.
  Future<void> recordBankLimits(
    int accountId, {
    Amount? available,
    Amount? intlAvailable,
    required DateTime at,
  }) async {
    if (available == null && intlAvailable == null) return;
    final j = {...?await store.get(reportsCollection, '$accountId')};
    void keep(String key, Amount? value) {
      if (value == null) return;
      final old = j[key] as Map?;
      if (old != null && dateOf(old['at']).isAfter(at)) return;
      j[key] = {'value': '$value', 'at': at.toIso8601String()};
    }

    keep('available', available);
    keep('intlAvailable', intlAvailable);
    await store.put(reportsCollection, '$accountId', j);
  }

  Future<FinanceContract?> contractFor(int accountId) async {
    for (final j in await store.list('contracts')) {
      if (j['kind'] == 'creditCard' && j['cardAccountId'] == accountId) {
        return FinanceContract.fromJson(j);
      }
    }
    return null;
  }

  /// Creates a credit card account with its terms in one step. [owed] is the
  /// current debt (0 for a new or paid-off card).
  Future<int> createCard({
    required String name,
    required String currency,
    required Amount owed,
    required CardTerms terms,
    required Amount purchaseApr,
    required int statementDay,
    required int paymentDay,
    int color = 0xFFEF4444,
    String icon = 'credit_card',
    String issuer = '',
  }) => db.transaction(() async {
    final id = await db.insertAccount(
      AccountsCompanion.insert(
        name: name,
        type: 'credit',
        currency: Value(currency),
        balance: Value(owed.toDouble()),
        color: color,
        icon: icon,
      ),
    );
    await saveTerms(
      id,
      terms: terms,
      purchaseApr: purchaseApr,
      statementDay: statementDay,
      paymentDay: paymentDay,
      issuer: issuer,
    );
    return id;
  });

  /// Sets or updates the terms of an existing credit card account.
  Future<void> saveTerms(
    int accountId, {
    required CardTerms terms,
    required Amount purchaseApr,
    required int statementDay,
    required int paymentDay,
    String issuer = '',
  }) => db.transaction(() async {
    final account = await db.getAccountById(accountId);
    if (account == null || account.type != 'credit') {
      throw ArgumentError('Choose a credit card account');
    }
    if (statementDay < 1 ||
        statementDay > 31 ||
        paymentDay < 1 ||
        paymentDay > 31) {
      throw ArgumentError('Statement and due days must be 1–31');
    }
    if (purchaseApr < Amount.zero || purchaseApr > Amount('100')) {
      throw ArgumentError('Enter an APR between 0% and 100%');
    }
    terms.validate();
    final existing = await contractFor(accountId);
    final today = DateTime.now();
    final contract = FinanceContract(
      id: existing?.id ?? ledger.newId(),
      name: existing?.name ?? account.name,
      kind: ContractKind.creditCard,
      currency: account.currency,
      principal: Amount.zero,
      annualRate: purchaseApr,
      start: existing?.start ?? DateTime(today.year, today.month, today.day),
      maturity:
          existing?.maturity ??
          DateTime(today.year + 50, today.month, today.day),
      counterparty: issuer.isEmpty ? existing?.counterparty ?? '' : issuer,
      interestMethod: 'manual',
      cardAccountId: accountId,
      accountId: existing?.accountId,
      statementDay: statementDay,
      paymentDay: paymentDay,
      card: terms,
    );
    if (existing == null) {
      await ContractService(ledger).create(contract);
    } else {
      await ContractRepository(store).save(contract);
    }
  });

  Future<CreditStatus> status(int accountId, {DateTime? now}) async {
    final account = await db.getAccountById(accountId);
    if (account == null) throw StateError('Account no longer exists');
    final today = now ?? DateTime.now();
    final contract = await contractFor(accountId);
    final terms = contract?.card;
    final owed = await store.balance(accountId);
    final digits = CurrencyFormatter.decimalsFor(account.currency);
    final limit = terms?.creditLimit;
    final hasLimit = limit != null && limit > Amount.zero;

    DateTime? closing, due;
    var atClosing = Amount.zero,
        paidSince = Amount.zero,
        cashAdvance = Amount.zero,
        intlUsed = Amount.zero;
    if (contract != null) {
      final dates = ContractService.statementDates(contract, today);
      closing = dates.closing;
      due = dates.due;
      final opening = await db
          .customSelect(
            'SELECT opening FROM exact_balances WHERE account_id = ?',
            variables: [Variable(accountId)],
          )
          .get();
      atClosing = opening.isEmpty
          ? Amount.zero
          : amountOf(opening.single.read<String>('opening'));
      final rows = [...await db.getTransactionsByAccount(accountId)]
        ..sort((a, b) {
          final byDate = a.transactionDate.compareTo(b.transactionDate);
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
      final details = await store.transactionDetailsFor(rows.map((t) => t.id));
      Amount amountOfRow(Transaction t) => details[t.id]?['amount'] == null
          ? Amount.fromNum(t.amount)
          : amountOf(details[t.id]!['amount']);
      // Payments clear the oldest debt first; what is left of spending in
      // other currencies is what uses the international limit.
      final debts = _DebtQueue();
      var net = Amount.zero;
      for (final t in rows) {
        net += t.type == 'expense' ? amountOfRow(t) : -amountOfRow(t);
      }
      debts.add(owed - net, foreign: false);
      for (final t in rows) {
        if (t.transactionDate.isAfter(today)) continue;
        final d = details[t.id];
        final amount = amountOfRow(t);
        final debt = t.type == 'expense' ? amount : -amount;
        debts.add(debt, foreign: _isForeign(d, account.currency));
        if (t.transactionDate.isBefore(closing)) {
          atClosing += debt;
        } else if (t.type == 'income') {
          paidSince += amount;
        }
        if (d?['cashAdvance'] == true && t.type == 'expense') {
          cashAdvance += amount;
        }
      }
      intlUsed = debts.foreign;
    }
    // Payments reduce the oldest debt first, so advances cannot exceed it.
    if (cashAdvance > owed) {
      cashAdvance = owed > Amount.zero ? owed : Amount.zero;
    }

    final statement = atClosing > Amount.zero ? atClosing : Amount.zero;
    final remaining = statement - paidSince > Amount.zero
        ? statement - paidSince
        : Amount.zero;
    var minimum = Amount.zero;
    if (terms != null && statement > Amount.zero) {
      final pct = (statement * terms.minPaymentPercent / Amount('100')).rounded(
        digits,
      );
      final base = pct > terms.minPaymentFloor ? pct : terms.minPaymentFloor;
      final overAtClosing = hasLimit && statement > limit
          ? statement - limit
          : Amount.zero;
      final atStatement = base + overAtClosing < statement
          ? base + overAtClosing
          : statement;
      minimum = atStatement - paidSince > Amount.zero
          ? atStatement - paidSince
          : Amount.zero;
    }
    final intlLimit = terms?.intlLimit;
    Amount? intlAvailable;
    if (intlLimit != null) {
      intlAvailable = intlLimit - intlUsed;
      if (hasLimit && limit - owed < intlAvailable) {
        intlAvailable = limit - owed;
      }
      if (intlAvailable < Amount.zero) intlAvailable = Amount.zero;
    }
    final reports = await store.get(reportsCollection, '$accountId');
    ReportedLimit? reported(String key) {
      final r = reports?[key] as Map?;
      return r == null
          ? null
          : ReportedLimit(amountOf(r['value']), dateOf(r['at']));
    }

    final monthly = Amount('1200');
    final interest =
        (remaining * (contract?.annualRate ?? Amount.zero) / monthly +
                cashAdvance * (terms?.cashAdvanceApr ?? Amount.zero) / monthly)
            .rounded(digits);
    return CreditStatus(
      currency: account.currency,
      owed: owed,
      limit: hasLimit ? limit : null,
      available: hasLimit ? limit - owed : Amount.zero,
      overLimitBy: hasLimit && owed > limit ? owed - limit : Amount.zero,
      utilization: hasLimit
          ? (owed > Amount.zero ? (owed / limit).toDouble() : 0)
          : null,
      statementBalance: statement,
      statementRemaining: remaining,
      minimumDue: minimum,
      paymentsSinceClosing: paidSince,
      interestEstimate: interest,
      cashAdvanceBalance: cashAdvance,
      closing: closing,
      due: due,
      terms: terms,
      intlLimit: intlLimit,
      intlUsed: intlLimit == null ? null : intlUsed,
      intlAvailable: intlAvailable,
      intlOverLimitBy: intlLimit != null && intlUsed > intlLimit
          ? intlUsed - intlLimit
          : Amount.zero,
      bankAvailable: reported('available'),
      bankIntlAvailable: reported('intlAvailable'),
    );
  }

  /// Spending booked in another currency than the card's, or its FX fee.
  static bool _isForeign(Json? d, String currency) {
    final original = d?['original'] as Map?;
    return (original != null && original['currency'] != currency) ||
        d?['feeType'] == 'fx';
  }

  /// Warns before a purchase would push the card over its limit (or, for
  /// [foreign] spending, its international limit); returns the amount over,
  /// or null when it fits (or no limit is set).
  Future<Amount?> overLimitAfter(
    int accountId,
    Amount spend, {
    bool foreign = false,
  }) async => (await status(accountId)).overAfter(spend, foreign: foreign)?.by;
}

/// Unpaid card debt, oldest first, split into local and foreign spending.
class _DebtQueue {
  final _chunks = <(Amount, bool)>[];
  var _credit = Amount.zero;

  /// Adds spending (positive) or a payment (negative).
  void add(Amount debt, {required bool foreign}) {
    if (debt > Amount.zero) {
      final used = _credit < debt ? _credit : debt;
      _credit -= used;
      if (debt - used > Amount.zero) _chunks.add((debt - used, foreign));
      return;
    }
    var pay = -debt;
    while (pay > Amount.zero && _chunks.isNotEmpty) {
      final (amount, isForeign) = _chunks.first;
      if (amount > pay) {
        _chunks[0] = (amount - pay, isForeign);
        pay = Amount.zero;
      } else {
        _chunks.removeAt(0);
        pay -= amount;
      }
    }
    _credit += pay;
  }

  Amount get foreign =>
      _chunks.where((c) => c.$2).fold(Amount.zero, (sum, c) => sum + c.$1);
}
