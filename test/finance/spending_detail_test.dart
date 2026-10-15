import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/core/finance/recurring_service.dart';
import 'package:flourish/core/finance/system_categories.dart';
import 'package:flourish/core/finance/transaction_classifier.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/data/finance/finance_store.dart';
import 'package:flourish/domain/finance/models.dart';

void main() {
  late AppDatabase db;
  late FinancialLedgerService ledger;
  late FinanceStore store;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = FinancialLedgerService(db);
    store = ledger.store;
  });
  tearDown(() => db.close());

  Future<int> account(
    String name, {
    String type = 'bank',
    String currency = 'EGP',
    String balance = '10000',
  }) => db.insertAccount(
    AccountsCompanion.insert(
      name: name,
      type: type,
      color: 0,
      icon: 'account_balance',
      currency: Value(currency),
      balance: Value(Amount(balance).toDouble()),
    ),
  );
  Future<int> card(
    int accountId, {
    String kind = 'debit_card',
    String? last4 = '1234',
    String? terms,
  }) => db.savePaymentInstrument(
    PaymentInstrumentsCompanion.insert(
      accountId: accountId,
      name: 'CIB',
      kind: kind,
      network: const Value('visa'),
      last4: Value(last4),
      terms: Value(terms),
    ),
  );
  Future<int> food() async => (await db.getAllCategories())
      .firstWhere((c) => c.name == 'Food & Drinks')
      .id;

  test('upgrades a v6 database to v7 without losing data', () async {
    await db.close();
    final folder = await Directory.systemTemp.createTemp('flourish-v6');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/v6.db');
    final raw = NativeDatabase(file);
    final legacy = AppDatabase.forTesting(raw);
    // Build the exact v6 layout from the fixture, then add v6-era rows.
    await legacy.customStatement('PRAGMA user_version = 6');
    await legacy.close();
    final setup = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (sqlite) {
          if (sqlite.userVersion != 6) return;
          final tables = sqlite.select(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
          );
          for (final t in tables) {
            sqlite.execute('DROP TABLE "${t['name']}"');
          }
          for (final statement in File(
            'test/fixtures/schema_v6.sql',
          ).readAsStringSync().split(';\n')) {
            final sql = statement
                .split('\n')
                .where((l) => !l.startsWith('--'))
                .join('\n')
                .trim();
            if (sql.isNotEmpty) sqlite.execute(sql);
          }
          sqlite.execute('''
            INSERT INTO categories (id, name, icon, color, type) VALUES
              (1, 'Other', 'more_horiz', 0, 'expense'),
              (2, 'Salary', 'payments', 0, 'income');
            INSERT INTO accounts (id, name, type, currency, color, icon, created_at)
              VALUES (1, 'Bank', 'bank', 'EGP', 0, 'account_balance', 0);
            INSERT INTO transactions (id, account_id, category_id, amount, type, transaction_date, created_at)
              VALUES (1, 1, 1, 50, 'expense', 1767225600, 0);
            INSERT INTO recurring_transactions (id, account_id, category_id, amount, type, frequency, next_date, created_at)
              VALUES (1, 1, 2, 9000, 'income', 'monthly', 1767225600, 0);
          ''');
          sqlite.userVersion = 6;
        },
      ),
    );
    addTearDown(setup.close);
    final tx = (await setup.getAllTransactions()).single;
    expect(tx.amount, 50);
    expect(tx.paymentMethod, isNull);
    final rule = (await setup.getActiveRecurringTransactions()).single;
    expect(rule.amount, 9000);
    expect(rule.toAccountId, isNull);
    final other = (await setup.getCategoryById(1))!;
    expect(other.systemKey, 'other_expense');
    final transfer = await setup.insertRecurringTransaction(
      RecurringTransactionsCompanion.insert(
        accountId: 1,
        categoryId: 1,
        amount: 100,
        type: 'transfer',
        frequency: 'monthly',
        nextDate: DateTime(2026, 2, 1),
        toAccountId: const Value(1),
      ),
    );
    expect(transfer, greaterThan(1));
    await setup.savePaymentInstrument(
      PaymentInstrumentsCompanion.insert(
        accountId: 1,
        name: 'Card',
        kind: 'debit_card',
      ),
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  group('payment instruments', () {
    test('cards must fit their account and pay only from it', () async {
      final bank = await account('Bank');
      final creditAccount = await account('Card', type: 'credit', balance: '0');
      await expectLater(
        card(bank, kind: 'credit_card'),
        throwsA(isA<TransactionLogicException>()),
      );
      await expectLater(
        card(bank, last4: '12a4'),
        throwsA(isA<TransactionLogicException>()),
      );
      final debit = await card(bank);
      await expectLater(
        ledger.recordCash(
          accountId: creditAccount,
          amount: Amount('5'),
          type: 'expense',
          instrumentId: debit,
        ),
        throwsArgumentError,
      );
      final tx = await ledger.recordCash(
        accountId: bank,
        amount: Amount('5'),
        type: 'expense',
        instrumentId: debit,
        merchant: '  Carrefour Maadi ',
      );
      final row = (await db.getTransactionById(tx))!;
      expect(row.paymentMethod, 'debit_card');
      expect(row.merchant, 'Carrefour Maadi');
      await expectLater(
        ledger.recordCash(
          accountId: bank,
          amount: Amount('5'),
          type: 'expense',
          paymentMethod: 'cash',
        ),
        throwsArgumentError,
      );
    });

    test('deleting a card keeps its history without a dangling link', () async {
      final bank = await account('Bank');
      final debit = await card(bank);
      final tx = await ledger.recordCash(
        accountId: bank,
        amount: Amount('5'),
        type: 'expense',
        instrumentId: debit,
      );
      await (db.delete(
        db.paymentInstruments,
      )..where((i) => i.id.equals(debit))).go();
      final row = (await db.getTransactionById(tx))!;
      expect(row.paymentInstrumentId, isNull);
      expect(row.paymentMethod, 'debit_card');
    });
  });

  group('foreign currency purchases', () {
    test('books the charged amount and a separate FX fee', () async {
      final bank = await account('Bank');
      final debit = await card(bank, terms: '{"fxFeePercent": "3"}');
      final id = await ledger.recordPurchase(
        accountId: bank,
        amount: Amount('1000'),
        categoryId: await food(),
        original: Money('20', 'USD'),
        instrumentId: debit,
        merchant: 'Netflix.com',
      );
      final details = (await store.transactionDetails(id))!;
      expect(details['original'], {'amount': '20', 'currency': 'USD'});
      expect(amountOf(details['bookedRate']), Amount('50'));
      final fee = (await db.getTransactionById(details['feeId'] as int))!;
      expect(fee.amount, 30);
      expect(
        (await db.getCategoryById(fee.categoryId))!.systemKey,
        'bank_fees',
      );
      expect(await store.balance(bank), Amount('8970'));

      // The fee follows the purchase when its amount changes…
      await ledger.updateCash(
        id,
        accountId: bank,
        amount: Amount('2000'),
        type: 'expense',
        categoryId: await food(),
        date: DateTime.now(),
      );
      expect((await db.getTransactionById(fee.id))!.amount, 60);
      expect(await store.balance(bank), Amount('7940'));
      // …cannot be removed on its own…
      await expectLater(
        ledger.deleteTransactionAndUpdateBalance(fee.id),
        throwsStateError,
      );
      // …and goes with the purchase.
      await ledger.deleteTransactionAndUpdateBalance(id);
      expect(await db.getAllTransactions(), isEmpty);
      expect(await store.balance(bank), Amount('10000'));
    });

    test('splits a charge that already includes the fee', () async {
      final bank = await account('Bank');
      final id = await ledger.recordPurchase(
        accountId: bank,
        amount: Amount('1030'),
        categoryId: await food(),
        original: Money('20', 'USD'),
        fxFeePercent: Amount('3'),
        feeIncluded: true,
      );
      final feeId = (await store.transactionDetails(id))!['feeId'] as int;
      expect((await db.getTransactionById(id))!.amount, 1000);
      expect((await db.getTransactionById(feeId))!.amount, 30);
      expect(await store.balance(bank), Amount('8970'));
    });
  });

  test('refunds reduce spending in their category', () async {
    final bank = await account('Bank');
    final buy = await ledger.recordCash(
      accountId: bank,
      amount: Amount('300'),
      type: 'expense',
      categoryId: await food(),
    );
    final refund = await ledger.recordRefund(
      accountId: bank,
      amount: Amount('100'),
      expenseCategoryId: await food(),
      refundOf: buy,
    );
    final row = (await db.getTransactionById(refund))!;
    expect(row.type, 'income');
    expect(
      TransactionClassifier.classify(
        row,
        await store.transactionDetails(refund),
        await db.getCategoryById(row.categoryId),
      ),
      FlowClass.refund,
    );
    expect(await store.balance(bank), Amount('9800'));
  });

  test(
    'withdrawing cash from a credit card is a cash advance with its fee',
    () async {
      final creditAccount = await account('Card', type: 'credit', balance: '0');
      final cash = await account('Wallet', type: 'cash', balance: '0');
      await store.put('contracts', 'c1', {
        'id': 'c1',
        'kind': 'creditCard',
        'cardAccountId': creditAccount,
        'card': {'cashAdvanceFeePercent': '3', 'cashAdvanceFeeMin': '50'},
      });
      await ledger.transfer(
        fromAccountId: creditAccount,
        toAccountId: cash,
        amount: Amount('1000'),
      );
      // max(50, 3% of 1000) = 50 fee, owed on the card with the advance.
      expect(await store.balance(creditAccount), Amount('1050'));
      expect(await store.balance(cash), Amount('1000'));
      final out = (await db.getAllTransactions()).firstWhere(
        (t) => t.accountId == creditAccount && t.linkedTransactionId != null,
      );
      expect((await store.transactionDetails(out.id))!['cashAdvance'], isTrue);
    },
  );

  test(
    'recurring transfers post both legs and stop after their end date',
    () async {
      final bank = await account('Bank');
      final savings = await account('Savings', balance: '0');
      final service = RecurringService(ledger);
      await service.create(
        RecurringTransactionsCompanion.insert(
          accountId: bank,
          categoryId: await SystemCategories.idFor(db, 'transfer_out'),
          amount: 500,
          type: 'transfer',
          frequency: 'monthly',
          nextDate: DateTime(2026, 1, 5),
          toAccountId: Value(savings),
          endDate: Value(DateTime(2026, 2, 28)),
        ),
        now: DateTime(2026, 1, 1),
      );
      await service.processDue(now: DateTime(2026, 6, 1));
      expect(await store.balance(savings), Amount('1000'));
      expect(await store.balance(bank), Amount('9000'));
      expect(await db.getActiveRecurringTransactions(), isEmpty);
    },
  );
}
