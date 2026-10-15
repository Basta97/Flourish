import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/detection/detection_service.dart';
import 'package:flourish/core/detection/parsed_payment.dart';
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
}
