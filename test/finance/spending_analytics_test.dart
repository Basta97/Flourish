import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/core/finance/spending_analytics_service.dart';
import 'package:flourish/core/finance/valuation_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/domain/finance/models.dart';

void main() {
  late AppDatabase db;
  late FinancialLedgerService ledger;
  late SpendingAnalyticsService analytics;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = FinancialLedgerService(db);
    analytics = SpendingAnalyticsService(
      ledger.store,
      ValuationService(ledger.store),
    );
  });
  tearDown(() => db.close());

  Future<int> account(String name, {String type = 'bank'}) => db.insertAccount(
    AccountsCompanion.insert(
      name: name,
      type: type,
      color: 0,
      icon: 'account_balance',
      currency: const Value('EGP'),
      balance: const Value(10000),
    ),
  );
  Future<int> category(String name) async =>
      (await db.getAllCategories()).firstWhere((c) => c.name == name).id;
  Future<void> spend(
    int accountId,
    String amount,
    DateTime date, {
    String categoryName = 'Food & Drinks',
    String? merchant,
  }) async => ledger.recordCash(
    accountId: accountId,
    amount: Amount(amount),
    type: 'expense',
    categoryId: await category(categoryName),
    date: date,
    merchant: merchant,
  );
  Future<SpendingPeriod> period(
    DateTime month, {
    int day = 1,
    DateTime? now,
  }) async => analytics.period(
    await db.getAllTransactions(),
    month,
    'EGP',
    day: day,
    now: now ?? DateTime(month.year, month.month + 1, 1),
  );

  test('transfers and card payments stay out of spending', () async {
    final bank = await account('Bank'),
        card = await account('Card', type: 'credit');
    await spend(card, '300', DateTime(2026, 10, 3));
    await ledger.transfer(
      fromAccountId: bank,
      toAccountId: card,
      amount: Amount('300'),
      date: DateTime(2026, 10, 20),
    );
    final p = await period(DateTime(2026, 10));
    expect(p.spending, Amount('300'));
    expect(p.income, Amount.zero);
    expect(p.daily[2], Amount('300'));
  });

  test('refunds reduce spending and fees count', () async {
    final bank = await account('Bank');
    await spend(bank, '500', DateTime(2026, 10, 5), merchant: 'Carrefour');
    await spend(bank, '100', DateTime(2026, 10, 6), merchant: 'carrefour ');
    await ledger.recordRefund(
      accountId: bank,
      amount: Amount('50'),
      expenseCategoryId: await category('Food & Drinks'),
      date: DateTime(2026, 10, 7),
    );
    await ledger.transfer(
      fromAccountId: bank,
      toAccountId: await account('Savings'),
      amount: Amount('1000'),
      fee: Amount('5'),
      date: DateTime(2026, 10, 8),
    );
    final p = await period(DateTime(2026, 10));
    expect(p.spending, Amount('555'));
    expect(p.categories.first.amount, Amount('550'));
    expect(p.merchants.single.name.toLowerCase(), 'carrefour');
    expect(p.merchants.single.amount, Amount('600'));
    expect(p.merchants.single.count, 2);
    expect(p.fees.values.fold(Amount.zero, (a, b) => a + b), Amount('5'));
  });

  test('custom month start day shifts the window', () async {
    final bank = await account('Bank');
    await spend(bank, '10', DateTime(2026, 10, 14));
    await spend(bank, '20', DateTime(2026, 10, 15));
    await spend(bank, '40', DateTime(2026, 11, 14));
    final p = await period(DateTime(2026, 10), day: 15);
    expect(p.start, DateTime(2026, 10, 15));
    expect(p.spending, Amount('60'));
    expect(p.previousSpending, Amount('10'));
    expect(
      SpendingAnalyticsService.monthOf(DateTime(2026, 11, 3), 15),
      DateTime(2026, 10),
    );
  });

  test('average, projection and comparison', () async {
    final bank = await account('Bank');
    await spend(bank, '200', DateTime(2026, 9, 10));
    await spend(bank, '100', DateTime(2026, 10, 1));
    await spend(bank, '100', DateTime(2026, 10, 10));
    final p = await period(DateTime(2026, 10), now: DateTime(2026, 10, 10, 12));
    expect(p.elapsedDays(DateTime(2026, 10, 10, 12)), 10);
    expect(p.averageDaily(DateTime(2026, 10, 10, 12)), Amount('20'));
    // Last month's spending fell before day 10, so nothing more is expected.
    expect(p.projected(DateTime(2026, 10, 10, 12)), Amount('200'));
    expect(p.changeVsPrevious(), 0);
  });

  test('projects from pace without a previous month', () async {
    final bank = await account('Bank');
    await spend(bank, '100', DateTime(2026, 10, 1));
    final p = await period(DateTime(2026, 10), now: DateTime(2026, 10, 5, 9));
    // 20 a day for the remaining 26 days.
    expect(p.projected(DateTime(2026, 10, 5, 9)), Amount('620'));
  });

  test('budget compares only budgeted categories', () async {
    final bank = await account('Bank');
    final food = await category('Food & Drinks');
    final id = await db.insertBudget(
      BudgetsCompanion.insert(
        categoryId: food,
        amount: 500,
        period: 'monthly',
        startDate: DateTime(2026, 10, 1),
      ),
    );
    await ledger.store.put('budgetCurrencies', '$id', {'currency': 'EGP'});
    await spend(bank, '300', DateTime(2026, 10, 2));
    await spend(bank, '900', DateTime(2026, 10, 3), categoryName: 'Shopping');
    final p = await period(DateTime(2026, 10));
    expect(p.budget, Amount('500'));
    expect(p.budgetSpent, Amount('300'));
    expect(p.spending, Amount('1200'));
  });

  test('series buckets each month once', () async {
    final bank = await account('Bank');
    await spend(bank, '10', DateTime(2026, 8, 2));
    await spend(bank, '20', DateTime(2026, 9, 2));
    await spend(bank, '30', DateTime(2026, 10, 2));
    final s = await analytics.series(
      await db.getAllTransactions(),
      DateTime(2026, 10),
      'EGP',
      count: 3,
    );
    expect(
      [for (final p in s) p.spending],
      [Amount('10'), Amount('20'), Amount('30')],
    );
  });
}
