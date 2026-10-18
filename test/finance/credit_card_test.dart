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

  CardTerms terms({
    String limit = '20000',
    String floor = '300',
    String? intl,
  }) => CardTerms(
    creditLimit: Amount(limit),
    intlLimit: intl == null ? null : Amount(intl),
    minPaymentPercent: Amount('5'),
    minPaymentFloor: Amount(floor),
    fxFeePercent: Amount('3'),
    cashAdvanceFeePercent: Amount('3'),
    cashAdvanceFeeMin: Amount('50'),
    cashAdvanceApr: Amount('48'),
  );
  Future<int> card({String limit = '20000', String owed = '0', String? intl}) =>
      cards.createCard(
        name: 'CIB Visa',
        currency: 'EGP',
        owed: Amount(owed),
        terms: terms(limit: limit, intl: intl),
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

  group('international limit', () {
    Future<void> abroad(int id, String egp, String usd, DateTime date) async {
      final food = (await db.getAllCategories()).firstWhere(
        (c) => c.name == 'Food & Drinks',
      );
      await ledger.recordPurchase(
        accountId: id,
        amount: Amount(egp),
        categoryId: food.id,
        original: Money(usd, 'USD'),
        date: date,
      );
    }

    test('foreign spending and its fee use the international limit', () async {
      final id = await card(owed: '1000', intl: '5000');
      await abroad(id, '1000', '20', DateTime(2026, 3, 1));
      await spend(id, '500', DateTime(2026, 3, 2));
      final s = await cards.status(id, now: now);
      expect(s.intlLimit, Amount('5000'));
      // 1000 plus the card's 3% FX fee.
      expect(s.intlUsed, Amount('1030'));
      expect(s.intlAvailable, Amount('3970'));
      expect(s.available, Amount('17470'));
      expect(s.intlOverLimitBy, Amount.zero);
    });

    test('payments clear the oldest debt first', () async {
      final id = await card(owed: '1000', intl: '5000');
      await abroad(id, '1000', '20', DateTime(2026, 3, 1));
      await pay(id, '1500', DateTime(2026, 3, 2));
      var s = await cards.status(id, now: now);
      expect(s.intlUsed, Amount('530'));
      await pay(id, '1000', DateTime(2026, 3, 3));
      s = await cards.status(id, now: now);
      expect(s.intlUsed, Amount.zero);
      expect(s.intlAvailable, Amount('5000'));
      // The overpayment is credit that absorbs the next foreign purchase.
      await abroad(id, '800', '16', DateTime(2026, 3, 4));
      s = await cards.status(id, now: now);
      // 824 with the fee, less the 470 overpaid.
      expect(s.intlUsed, Amount('354'));
    });

    test('what is left abroad never exceeds the credit left', () async {
      final id = await card(limit: '5000', owed: '3000', intl: '4000');
      final s = await cards.status(id, now: now);
      expect(s.intlUsed, Amount.zero);
      expect(s.intlAvailable, Amount('2000'));
    });

    test('warns about the limit a purchase would break', () async {
      final id = await card(owed: '1000', intl: '5000');
      await abroad(id, '1000', '20', DateTime(2026, 3, 1));
      final s = await cards.status(id, now: now);
      final over = s.overAfter(Amount('4500'), foreign: true)!;
      expect(over.international, isTrue);
      expect(over.by, Amount('530'));
      expect(s.overAfter(Amount('4500')), isNull);
      expect(s.overAfter(Amount('19000'))!.by, Amount('1030'));
      expect(
        await cards.overLimitAfter(id, Amount('4000'), foreign: true),
        Amount('30'),
      );
    });

    test('over the international limit', () async {
      final id = await card(intl: '500');
      await abroad(id, '1000', '20', DateTime(2026, 3, 1));
      final s = await cards.status(id, now: now);
      expect(s.intlOverLimitBy, Amount('530'));
      expect(s.intlAvailable, Amount.zero);
    });

    test('without one, cards work as before', () async {
      final id = await card(owed: '1000');
      await abroad(id, '1000', '20', DateTime(2026, 3, 1));
      final s = await cards.status(id, now: now);
      expect(s.intlLimit, isNull);
      expect(s.intlAvailable, isNull);
      expect(s.overAfter(Amount('18000'), foreign: true)!.international, false);
      expect(
        CardTerms(creditLimit: Amount('1'), intlLimit: Amount.zero).intlLimit,
        isNull,
      );
    });

    test('is stored with the terms and validated', () async {
      final t = terms(intl: '7500');
      expect(CardTerms.fromJson(t.toJson()).intlLimit, Amount('7500'));
      expect(CardTerms.fromJson(terms().toJson()).intlLimit, isNull);
      expect(
        () => terms(limit: '5000', intl: '6000').validate(),
        throwsArgumentError,
      );
      expect(() => terms(intl: '-1').validate(), throwsArgumentError);
    });

    test('keeps the newest limits a bank message stated', () async {
      final id = await card(intl: '5000');
      await cards.recordBankLimits(
        id,
        available: Amount('15000'),
        intlAvailable: Amount('4200'),
        at: DateTime(2026, 3, 2),
      );
      await cards.recordBankLimits(
        id,
        intlAvailable: Amount('9999'),
        at: DateTime(2026, 3, 1),
      );
      await cards.recordBankLimits(
        id,
        available: Amount('14000'),
        at: DateTime(2026, 3, 3),
      );
      final s = await cards.status(id, now: now);
      expect(s.bankAvailable!.value, Amount('14000'));
      expect(s.bankIntlAvailable!.value, Amount('4200'));
      expect(s.bankIntlAvailable!.at, DateTime(2026, 3, 2));
    });
  });
}
