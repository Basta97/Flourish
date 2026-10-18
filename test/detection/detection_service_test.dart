import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/detection/detection_service.dart';
import 'package:flourish/core/detection/parsed_payment.dart';
import 'package:flourish/core/finance/credit_card_service.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/domain/finance/models.dart';

void main() {
  late AppDatabase db;
  late FinancialLedgerService ledger;
  late DetectionService detection;
  late int bank, cash, card;
  final at = DateTime(2026, 10, 15, 12);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = FinancialLedgerService(db);
    detection = DetectionService(ledger);
    // Seeded Cash/Bank Account are replaced with a clear setup.
    for (final a in await db.getAllAccounts()) {
      await (db.delete(db.accounts)..where((t) => t.id.equals(a.id))).go();
    }
    Future<int> account(String name, String type, String balance) =>
        db.insertAccount(
          AccountsCompanion.insert(
            name: name,
            type: type,
            color: 0,
            icon: 'account_balance',
            currency: const Value('EGP'),
            balance: Value(Amount(balance).toDouble()),
          ),
        );
    bank = await account('CIB', 'bank', '10000');
    cash = await account('Wallet', 'cash', '0');
    card = await db.savePaymentInstrument(
      PaymentInstrumentsCompanion.insert(
        accountId: bank,
        name: 'CIB',
        kind: 'debit_card',
        network: const Value('visa'),
        last4: const Value('1234'),
        issuer: const Value('cib'),
      ),
    );
  });
  tearDown(() => db.close());

  RawMessage sms(String text, {DateTime? when, String sender = 'CIB'}) =>
      RawMessage(
        text: text,
        sender: sender,
        receivedAt: when ?? at,
        source: 'android_notification',
      );

  test('ignores OTPs and the same message twice', () async {
    expect(
      await detection.ingest(sms('Your OTP is 123456. Do not share')),
      isNull,
    );
    const text = 'Card ending 1234 was charged EGP 250.00 at Talabat';
    final first = await detection.ingest(sms(text));
    expect(first, isNotNull);
    expect(await detection.ingest(sms(text)), isNull);
  });

  test('matches the card by its last 4 digits', () async {
    final row = await detection.ingest(
      sms('Card ending 1234 was charged EGP 250.00 at Talabat'),
    );
    expect(row!.accountId, bank);
    expect(row.instrumentId, card);
    expect(row.status, 'pending');
    final category = await db.getCategoryById(row.categoryId!);
    expect(category!.name, 'Food & Drinks');
  });

  test('the SMS and the bank-app alert of one payment count once', () async {
    final first = await detection.ingest(
      sms('Card ending 1234 was charged EGP 99.00 at Uber'),
    );
    final second = await detection.ingest(
      RawMessage(
        text: 'Purchase EGP 99.00 Uber card xx1234',
        sender: 'CIB',
        packageName: 'com.cib.mobile',
        receivedAt: at.add(const Duration(minutes: 2)),
        source: 'android_notification',
      ),
    );
    expect(second!.status, 'duplicate');
    expect(second.duplicateOfId, first!.id);
    // A genuinely second, identical purchase two hours later stays.
    final later = await detection.ingest(
      sms(
        'Card ending 1234 was charged EGP 99.00 at Uber',
        when: at.add(const Duration(hours: 2)),
      ),
    );
    expect(later!.status, 'pending');
  });

  test('confirming books it and teaches the merchant category', () async {
    final row = await detection.ingest(
      sms('Card ending 1234 was charged EGP 400.00 at Gym Nation'),
    );
    final health = (await db.getAllCategories()).firstWhere(
      (c) => c.name == 'Health',
    );
    final result = await detection.confirm(
      row!.id,
      draft: DetectionDraft(categoryId: health.id),
    );
    final tx = (await db.getTransactionById(result.transactionId))!;
    expect(tx.source, 'detected');
    expect(tx.merchant, 'Gym Nation');
    expect(tx.paymentInstrumentId, card);
    expect(tx.categoryId, health.id);
    expect(await ledger.store.balance(bank), Amount('9600'));
    final next = await detection.ingest(
      sms(
        'Card ending 1234 was charged EGP 400.00 at GYM NATION',
        when: at.add(const Duration(days: 30)),
      ),
    );
    expect(next!.categoryId, health.id);
  });

  test('flags a payment that was already entered by hand', () async {
    final manual = await ledger.recordCash(
      accountId: bank,
      amount: Amount('250'),
      type: 'expense',
      date: at,
    );
    final row = await detection.ingest(
      sms('Card ending 1234 was charged EGP 250.00 at Talabat'),
    );
    expect(row!.matchTransactionId, manual);
    await detection.link(row.id, manual);
    expect((await detection.get(row.id))!.status, 'confirmed');
    expect(await ledger.store.balance(bank), Amount('9750'));
  });

  group('auto-confirm', () {
    test(
      'only for a known card, a recognised bank and high confidence',
      () async {
        final sure = await detection.ingest(
          sms(
            'Your CIB card ending with 1234 was charged EGP 120.00 at Costa on 15/10/2026 11:58',
          ),
          autoConfirm: true,
        );
        expect(sure!.status, 'confirmed');
        expect(sure.autoConfirmed, isTrue);
        final unknownBank = await detection.ingest(
          sms(
            'Card ending 1234 was charged EGP 80.00 at Costa',
            sender: '19999',
          ),
          autoConfirm: true,
        );
        expect(unknownBank!.status, 'pending');
        await detection.undoConfirm(sure.id);
        expect((await detection.get(sure.id))!.status, 'pending');
        expect(await ledger.store.balance(bank), Amount('10000'));
      },
    );
  });

  test('a foreign purchase books the charged EGP and keeps the USD', () async {
    final row = await detection.ingest(
      sms(
        'Card xxxx1234 Purchase USD 12.99 NETFLIX.COM. Equivalent EGP 650.20',
      ),
    );
    final result = await detection.confirm(row!.id);
    final details = await ledger.store.transactionDetails(result.transactionId);
    expect(details!['original'], {'amount': '12.99', 'currency': 'USD'});
    expect(await ledger.store.balance(bank), Amount('9349.8'));
  });

  Future<void> rate(String from, String to, String value) => ledger.store.put(
    'fx',
    '$from/$to:${DateTime(2026, 10, 14)}:false',
    MarketObservation(
      key: '$from/$to',
      currency: to,
      source: 'test',
      value: Amount(value),
      effectiveAt: DateTime(2026, 10, 14),
      retrievedAt: DateTime(2026, 10, 14),
    ).toJson(),
  );

  group('a foreign purchase without the bank\'s EGP figure', () {
    setUp(
      () => (db.update(db.paymentInstruments)..where((i) => i.id.equals(card)))
          .write(
            const PaymentInstrumentsCompanion(
              terms: Value('{"fxFeePercent":"3"}'),
            ),
          ),
    );

    test('is converted at the day\'s rate plus the card fee', () async {
      await rate('USD', 'EGP', '50');
      final row = await detection.ingest(
        sms('Card xxxx1234 Purchase USD 20.00 at NETFLIX.COM'),
      );
      final estimate = await detection.charge(row!);
      expect(estimate!.amount, Amount('1000'));
      expect(estimate.fromRate, isTrue);
      expect(estimate.fee, Amount('30'));
      final result = await detection.confirm(row.id);
      final details = await ledger.store.transactionDetails(
        result.transactionId,
      );
      expect(details!['original'], {'amount': '20', 'currency': 'USD'});
      // 1,000 for the purchase and 30 for the card's 3% fee.
      expect(await ledger.store.balance(bank), Amount('8970'));
    });

    test('goes through USD when there is no direct rate', () async {
      await rate('USD', 'EGP', '50');
      await rate('USD', 'SAR', '3.75');
      final row = await detection.ingest(
        sms('Card xxxx1234 Purchase SAR 150.00 at JARIR'),
      );
      expect((await detection.charge(row!))!.amount, Amount('2000'));
    });

    test('asks for the amount when no rate is known', () async {
      final row = await detection.ingest(
        sms('Card xxxx1234 Purchase EUR 10.00 at ZARA'),
      );
      expect(await detection.charge(row!), isNull);
      await expectLater(detection.confirm(row.id), throwsArgumentError);
      final result = await detection.confirm(
        row.id,
        draft: DetectionDraft(amount: Amount('560')),
      );
      expect(result.transactionId, isPositive);
      expect(await ledger.store.balance(bank), Amount('9440'));
    });

    test('is never auto-confirmed', () async {
      await rate('USD', 'EGP', '50');
      final row = await detection.ingest(
        sms('Card xxxx1234 Purchase USD 20.00 at NETFLIX.COM'),
        autoConfirm: true,
      );
      expect((await detection.get(row!.id))!.status, 'pending');
    });
  });

  test('an ATM withdrawal moves money into cash', () async {
    final row = await detection.ingest(
      sms('ATM cash withdrawal of EGP 2,000.00 from card xx1234'),
    );
    await detection.confirm(row!.id);
    expect(await ledger.store.balance(bank), Amount('8000'));
    expect(await ledger.store.balance(cash), Amount('2000'));
  });

  test('a credit card payment message pays the card from the bank', () async {
    final creditCard = await db.insertAccount(
      AccountsCompanion.insert(
        name: 'Card',
        type: 'credit',
        color: 0,
        icon: 'credit_card',
        currency: const Value('EGP'),
        balance: const Value(5000),
      ),
    );
    final row = await detection.ingest(
      sms(
        'Your payment of EGP 3,000.00 towards your credit card was received.',
      ),
    );
    await detection.confirm(
      row!.id,
      draft: DetectionDraft(accountId: creditCard),
    );
    expect(await ledger.store.balance(creditCard), Amount('2000'));
    expect(await ledger.store.balance(bank), Amount('7000'));
  });

  test('message text is cleared after the retention period', () async {
    final row = await detection.ingest(
      sms('Card ending 1234 was charged EGP 250.00 at Talabat'),
    );
    expect(row!.rawText, contains('Talabat'));
    await detection.dismiss(row.id);
    await detection.purgeText(days: 7, now: at.add(const Duration(days: 8)));
    expect((await detection.get(row.id))!.rawText, isNull);
  });

  test('a v7 database gains the detection table', () async {
    await db.close();
    final folder = await Directory.systemTemp.createTemp('flourish-v7');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/v7.db');
    final v7 = AppDatabase.forTesting(NativeDatabase(file));
    await v7.getAllAccounts();
    await v7.customStatement('DROP TABLE detected_payments');
    await v7.customStatement('PRAGMA user_version = 7');
    await v7.close();
    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect(await upgraded.select(upgraded.detectedPayments).get(), isEmpty);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  test('a card alert keeps the limits it states and flags a gap', () async {
    final cards = CreditCardService(ledger);
    final visa = await cards.createCard(
      name: 'NBE Visa',
      currency: 'EGP',
      owed: Amount('1000'),
      terms: CardTerms(creditLimit: Amount('20000'), intlLimit: Amount('5000')),
      purchaseApr: Amount('30'),
      statementDay: 25,
      paymentDay: 10,
    );
    final row = await detection.ingest(
      sms(
        'Your credit card was charged EGP 500.00 at SPINNEYS. '
        'Available limit EGP 18,000.00. '
        'Available international limit EGP 4,200.00',
        sender: 'NBE',
      ),
    );
    final result = await detection.confirm(
      row!.id,
      draft: DetectionDraft(accountId: visa),
    );
    // Flourish shows 20000 - 1500 = 18500 available.
    expect(result.limitDifference, Amount('-500'));
    expect(result.balanceDifference, isNull);
    final s = await cards.status(visa);
    expect(s.bankAvailable!.value, Amount('18000'));
    expect(s.bankIntlAvailable!.value, Amount('4200'));
  });
}
