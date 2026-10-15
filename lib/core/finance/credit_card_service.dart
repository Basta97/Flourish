import 'package:drift/drift.dart';
import '../../data/database/database.dart';
import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';
import '../utils/currency_formatter.dart';
import 'contract_service.dart';
import 'financial_ledger_service.dart';

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
  const CreditStatus({
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
  });
  bool get hasTerms => terms != null;
}

/// Credit card setup and status, built on the card's billing contract so
/// statements, reminders and backups keep working as before.
class CreditCardService {
  final FinancialLedgerService ledger;
  CreditCardService(this.ledger);
  AppDatabase get db => ledger.db;
  FinanceStore get store => ledger.store;

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
        cashAdvance = Amount.zero;
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
      final rows = await db.getTransactionsByAccount(accountId);
      final details = await store.transactionDetailsFor(rows.map((t) => t.id));
      for (final t in rows) {
        if (t.transactionDate.isAfter(today)) continue;
        final d = details[t.id];
        final amount = d?['amount'] == null
            ? Amount.fromNum(t.amount)
            : amountOf(d!['amount']);
        final debt = t.type == 'expense' ? amount : -amount;
        if (t.transactionDate.isBefore(closing)) {
          atClosing += debt;
        } else if (t.type == 'income') {
          paidSince += amount;
        }
        if (d?['cashAdvance'] == true && t.type == 'expense') {
          cashAdvance += amount;
        }
      }
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
    );
  }

  /// Warns before a purchase would push the card over its limit; returns
  /// the amount over, or null when it fits (or no limit is set).
  Future<Amount?> overLimitAfter(int accountId, Amount spend) async {
    final s = await status(accountId);
    if (s.limit == null) return null;
    final after = s.owed + spend;
    return after > s.limit! ? after - s.limit! : null;
  }
}
