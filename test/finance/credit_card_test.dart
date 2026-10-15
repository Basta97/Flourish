import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/finance/credit_card_service.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/domain/finance/models.dart';

void main() {
  late AppDatabase db;
  late FinancialLedgerService ledger;
  late CreditCardService cards;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = FinancialLedgerService(db);
    cards = CreditCardService(ledger);
  });
  tearDown(() => db.close());

  CardTerms terms({String limit = '20000', String floor = '300'}) => CardTerms(
    creditLimit: Amount(limit),
    minPaymentPercent: Amount('5'),
    minPaymentFloor: Amount(floor),
    fxFeePercent: Amount('3'),
    cashAdvanceFeePercent: Amount('3'),
    cashAdvanceFeeMin: Amount('50'),
    cashAdvanceApr: Amount('48'),
  );
  Future<int> card({String limit = '20000', String owed = '0'}) =>
      cards.createCard(
        name: 'CIB Visa',
        currency: 'EGP',
        owed: Amount(owed),
        terms: terms(limit: limit),
        purchaseApr: Amount('36'),
        statementDay: 25,
        paymentDay: 10,
      );
  Future<void> spend(int id, String amount, DateTime date) => ledger.recordCash(
    accountId: id,
    amount: Amount(amount),
    type: 'expense',
    date: date,
  );
  Future<void> pay(int card, String amount, DateTime date) async {
    final bank = await db.insertAccount(
      AccountsCompanion.insert(
        name: 'Bank $amount',
        type: 'bank',
        color: 0,
        icon: 'account_balance',
        currency: const Value('EGP'),
        balance: const Value(100000),
      ),
    );
    await ledger.transfer(
      fromAccountId: bank,
      toAccountId: card,
      amount: Amount(amount),
      date: date,
    );
  }

  final now = DateTime(2026, 3, 5);

  test('limit, available credit and utilization', () async {
    final id = await card(owed: '5000');
    final s = await cards.status(id, now: now);
    expect(s.limit, Amount('20000'));
    expect(s.owed, Amount('5000'));
    expect(s.available, Amount('15000'));
    expect(s.utilization, closeTo(0.25, 1e-9));
    expect(s.closing, DateTime(2026, 2, 25));
    expect(s.due, DateTime(2026, 3, 10));
  });

  test('an overpaid card has more than its limit available', () async {
    final id = await card(owed: '-500');
    final s = await cards.status(id, now: now);
    expect(s.available, Amount('20500'));
    expect(s.utilization, 0);
  });

  test('minimum due uses the percentage, the floor and the balance', () async {
    final big = await card();
    await spend(big, '10000', DateTime(2026, 2, 10));
    expect((await cards.status(big, now: now)).minimumDue, Amount('500'));

    final small = await card();
    await spend(small, '1000', DateTime(2026, 2, 10));
    expect((await cards.status(small, now: now)).minimumDue, Amount('300'));

    final tiny = await card();
    await spend(tiny, '200', DateTime(2026, 2, 10));
    expect((await cards.status(tiny, now: now)).minimumDue, Amount('200'));
  });

  test('purchases after closing wait for the next statement', () async {
    final id = await card();
    await spend(id, '10000', DateTime(2026, 2, 10));
    await spend(id, '4000', DateTime(2026, 3, 1));
    final s = await cards.status(id, now: now);
    expect(s.statementBalance, Amount('10000'));
    expect(s.owed, Amount('14000'));
  });

  test('payments since closing reduce what is due', () async {
    final id = await card();
    await spend(id, '10000', DateTime(2026, 2, 10));
    await pay(id, '400', DateTime(2026, 3, 1));
    var s = await cards.status(id, now: now);
    expect(s.minimumDue, Amount('100'));
    expect(s.statementRemaining, Amount('9600'));
    // 36% a year on the unpaid statement is roughly 288 next month.
    expect(s.interestEstimate, Amount('288'));
    await pay(id, '9600', DateTime(2026, 3, 2));
    s = await cards.status(id, now: now);
    expect(s.minimumDue, Amount.zero);
    expect(s.statementRemaining, Amount.zero);
    expect(s.interestEstimate, Amount.zero);
  });

  test('an over-limit statement adds the excess to the minimum', () async {
    final id = await card(limit: '5000');
    await spend(id, '6000', DateTime(2026, 2, 10));
    final s = await cards.status(id, now: now);
    expect(s.overLimitBy, Amount('1000'));
    expect(s.minimumDue, Amount('1300'));
    expect(await cards.overLimitAfter(id, Amount('1')), Amount('1001'));
  });

  test('foreign purchases use the card terms for the FX fee', () async {
    final id = await card();
    final food = (await db.getAllCategories()).firstWhere(
      (c) => c.name == 'Food & Drinks',
    );
    final tx = await ledger.recordPurchase(
      accountId: id,
      amount: Amount('500'),
      categoryId: food.id,
      original: Money('10', 'USD'),
    );
    final details = (await ledger.store.transactionDetails(tx))!;
    expect(details['fxFeePercent'], '3');
    expect(await ledger.store.balance(id), Amount('515'));
  });

  test('terms are validated', () async {
    final id = await card();
    expect(
      () => cards.saveTerms(
        id,
        terms: CardTerms(creditLimit: Amount('-1')),
        purchaseApr: Amount('30'),
        statementDay: 1,
        paymentDay: 20,
      ),
      throwsArgumentError,
    );
    await expectLater(
      cards.saveTerms(
        id,
        terms: terms(),
        purchaseApr: Amount('30'),
        statementDay: 32,
        paymentDay: 20,
      ),
      throwsArgumentError,
    );
  });
}
