import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/core/finance/recurring_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/data/finance/finance_store.dart';
import 'package:flourish/domain/finance/models.dart';

void main() {
  late AppDatabase db;
  late FinancialLedgerService ledger;
  late RecurringService recurring;
  late FinanceStore store;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = FinancialLedgerService(db);
    recurring = RecurringService(ledger);
    store = ledger.store;
  });
  tearDown(() => db.close());

  Future<int> account(
    String name, {
    String balance = '1000',
    String type = 'bank',
    String currency = 'EGP',
  }) => db.insertAccount(
    AccountsCompanion.insert(
      name: name,
      type: type,
      color: 0xFF000000,
      icon: 'account_balance',
      currency: Value(currency),
      balance: Value(Amount(balance).toDouble()),
    ),
  );
  Future<int> category(String type) async =>
      (await db.getAllCategories()).firstWhere((c) => c.type == type).id;
  Future<int> rule(
    int accountId,
    DateTime next, {
    String frequency = 'monthly',
    double amount = 10,
  }) async => db.insertRecurringTransaction(
    RecurringTransactionsCompanion.insert(
      accountId: accountId,
      categoryId: await category('expense'),
      amount: amount,
      type: 'expense',
      frequency: frequency,
      nextDate: next,
    ),
  );

  group('recurring', () {
    test('posts through the ledger with a conversion snapshot', () async {
      final id = await account('Bank');
      await rule(id, DateTime(2026, 1, 5));
      await recurring.processDue(now: DateTime(2026, 1, 5, 12));
      final tx = (await db.getAllTransactions()).single;
      final details = await store.transactionDetails(tx.id);
      expect(details?['currency'], 'EGP');
      expect(tx.source, 'recurring');
      expect(details?['recurringId'], isNotNull);
      expect(await store.balance(id), Amount('990'));
    });

    test(
      'a rule that cannot post is skipped without blocking others',
      () async {
        final archived = await account('Old bank');
        final active = await account('Bank');
        await store.put(
          'accountDetails',
          '$archived',
          AccountDetails(archived, archived: true).toJson(),
        );
        final broken = await rule(archived, DateTime(2026, 1, 5));
        await rule(active, DateTime(2026, 1, 5));
        await recurring.processDue(now: DateTime(2026, 1, 6));
        expect(await store.balance(active), Amount('990'));
        expect(await store.balance(archived), Amount('1000'));
        expect((await recurring.warnings())[broken], contains('Unarchive'));
      },
    );

    test('resuming a paused rule does not back-fill skipped periods', () async {
      final id = await account('Bank');
      final ruleId = await rule(id, DateTime(2026, 1, 10));
      final r = (await db.getActiveRecurringTransactions()).single;
      await recurring.setActive(r, false);
      final paused = (await db.getDueRecurringTransactions(
        DateTime(2027),
      )).where((x) => x.id == ruleId);
      expect(paused, isEmpty);
      final stored = await (db.select(
        db.recurringTransactions,
      )..where((t) => t.id.equals(ruleId))).getSingle();
      await recurring.setActive(stored, true, now: DateTime(2026, 4, 20));
      await recurring.processDue(now: DateTime(2026, 4, 20));
      expect(await db.getAllTransactions(), isEmpty);
      expect(
        (await db.getActiveRecurringTransactions()).single.nextDate,
        DateTime(2026, 5, 10),
      );
    });

    test('a past start date posts missed payments only when asked', () async {
      final id = await account('Bank');
      final entry = RecurringTransactionsCompanion.insert(
        accountId: id,
        categoryId: await category('expense'),
        amount: 10,
        type: 'expense',
        frequency: 'monthly',
        nextDate: DateTime(2026, 1, 31),
      );
      final skipped = await recurring.create(entry, now: DateTime(2026, 3, 15));
      final caught = await recurring.create(
        entry,
        catchUp: true,
        now: DateTime(2026, 3, 15),
      );
      await recurring.processDue(now: DateTime(2026, 3, 15));
      final rules = {
        for (final r in await db.getActiveRecurringTransactions()) r.id: r,
      };
      expect(rules[skipped]!.nextDate, DateTime(2026, 3, 31));
      expect(rules[caught]!.nextDate, DateTime(2026, 3, 31));
      expect((await db.getAllTransactions()).length, 2);
      expect(
        RecurringService.occurrences(
          DateTime(2026, 1, 31),
          'monthly',
          DateTime(2026, 3, 15),
        ),
        [DateTime(2026, 1, 31), DateTime(2026, 2, 28)],
      );
    });
  });

  test('auto income catches up missed months exactly once', () async {
    final id = await account('Salary', balance: '0');
    final income = await category('income');
    Future<void> run() => recurring.processAutoIncome(
      amount: Amount('5000'),
      accountId: id,
      categoryId: income,
      day: 25,
      lastPostedMonth: '2026-1',
      now: DateTime(2026, 4, 2),
    );
    await run();
    await run();
    final rows = await db.getAllTransactions();
    expect(rows.map((t) => t.transactionDate).toSet(), {
      DateTime(2026, 2, 25),
      DateTime(2026, 3, 25),
    });
    expect(await store.balance(id), Amount('10000'));
  });

  group('undo', () {
    test('restores a cash entry with its id, snapshot and balance', () async {
      final id = await account('Bank');
      final tx = await ledger.recordCash(
        accountId: id,
        amount: Amount('12.345'),
        type: 'expense',
        date: DateTime(2026, 2, 1),
      );
      final before = await store.transactionDetails(tx);
      final deleted = await ledger.deleteWithUndo(tx);
      expect(await store.balance(id), Amount('1000'));
      await ledger.restore(deleted!);
      expect((await db.getTransactionById(tx))?.amount, 12.345);
      expect(await store.transactionDetails(tx), before);
      expect(await store.balance(id), Amount('987.655'));
    });

    test('restores both transfer legs and the fee', () async {
      final from = await account('Bank');
      final to = await account('Wallet', balance: '0', type: 'ewallet');
      await ledger.transfer(
        fromAccountId: from,
        toAccountId: to,
        amount: Amount('100'),
        fee: Amount('5'),
      );
      final ids = (await db.getAllTransactions()).map((t) => t.id).toSet();
      final out = (await db.getAllTransactions()).firstWhere(
        (t) => t.accountId == from && t.linkedTransactionId != null,
      );
      final deleted = await ledger.deleteWithUndo(out.id);
      expect(await db.getAllTransactions(), isEmpty);
      expect(await store.balance(from), Amount('1000'));
      await ledger.restore(deleted!);
      final rows = await db.getAllTransactions();
      expect(rows.map((t) => t.id).toSet(), ids);
      expect(
        rows.firstWhere((t) => t.id == out.id).linkedTransactionId,
        out.linkedTransactionId,
      );
      expect(await store.balance(from), Amount('895'));
      expect(await store.balance(to), Amount('100'));
    });
  });

  test('account edits never touch the balance', () async {
    final id = await account('Bank');
    final a = (await db.getAccountById(id))!;
    await db.updateAccount(a.copyWith(name: 'Renamed', balance: 1));
    final updated = (await db.getAccountById(id))!;
    expect(updated.name, 'Renamed');
    expect(updated.balance, 1000);
    expect(await store.balance(id), Amount('1000'));
  });

  test('accounts with history cannot be deleted', () async {
    final id = await account('Bank');
    await ledger.recordCash(
      accountId: id,
      amount: Amount('1'),
      type: 'expense',
    );
    await expectLater(
      db.deleteAccount(id),
      throwsA(isA<TransactionLogicException>()),
    );
  });

  group('currency guards', () {
    test('amounts entered in another currency are refused', () async {
      final usd = await account('Dollar card', currency: 'USD');
      await expectLater(
        ledger.recordCash(
          accountId: usd,
          amount: Amount('100'),
          type: 'expense',
          expectCurrency: 'EGP',
        ),
        throwsA(isA<TransactionLogicException>()),
      );
      final egp = await account('Bank');
      final tx = await ledger.recordCash(
        accountId: egp,
        amount: Amount('100'),
        type: 'expense',
        expectCurrency: 'EGP',
      );
      await expectLater(
        ledger.updateCash(
          tx,
          accountId: usd,
          amount: Amount('100'),
          type: 'expense',
          categoryId: (await db.getTransactionById(tx))!.categoryId,
          date: DateTime.now(),
          expectCurrency: 'EGP',
        ),
        throwsA(isA<TransactionLogicException>()),
      );
      expect(await store.balance(egp), Amount('900'));
      expect(await store.balance(usd), Amount('1000'));
    });

    test('same-currency transfers must arrive in full', () async {
      final a = await account('A'), b = await account('B');
      await expectLater(
        ledger.transfer(
          fromAccountId: a,
          toAccountId: b,
          amount: Amount('100'),
          received: Amount('90'),
        ),
        throwsArgumentError,
      );
      expect(await db.getAllTransactions(), isEmpty);
    });

    test('currency is editable only until the account has history', () async {
      final id = await account('Fresh', currency: 'USD');
      await db.changeAccountCurrency(id, 'EGP');
      expect((await db.getAccountById(id))!.currency, 'EGP');
      await ledger.recordCash(
        accountId: id,
        amount: Amount('1'),
        type: 'expense',
      );
      await expectLater(
        db.changeAccountCurrency(id, 'USD'),
        throwsA(isA<TransactionLogicException>()),
      );
    });

    test('accounts without a currency use the app default', () async {
      final id = await db.insertAccount(
        AccountsCompanion.insert(
          name: 'Plain',
          type: 'cash',
          color: 0,
          icon: 'wallet',
        ),
      );
      expect((await db.getAccountById(id))!.currency, 'EGP');
      final seeded = await db.getAllAccounts();
      expect(seeded.where((a) => a.name == 'Cash').single.currency, 'EGP');
    });
  });

  test('databases upgraded through v5 stay readable', () async {
    await db.close();
    final folder = await Directory.systemTemp.createTemp('flourish-v4');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/legacy.db');
    final legacy = AppDatabase.forTesting(NativeDatabase(file));
    await legacy.getAllAccounts();
    for (final table in FinanceStore.tables) {
      await legacy.customStatement('DROP TABLE $table');
    }
    await legacy.customStatement('PRAGMA user_version=4');
    await legacy.close();

    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    // The v5 rebuild leaves a TEXT default on created_at; rows that rely on
    // it used to make the whole table unreadable.
    await upgraded.customStatement(
      "INSERT INTO accounts (name, type, color, icon) VALUES ('Raw', 'cash', 0, 'wallet')",
    );
    await upgraded.customStatement(
      "INSERT INTO transactions (account_id, category_id, amount, type, transaction_date) "
      "SELECT id, NULL, 1, 'expense', 1767225600 FROM accounts WHERE name = 'Raw'",
    );
    await upgraded.close();

    final reopened = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(reopened.close);
    final accounts = await reopened.getAllAccounts();
    expect(accounts.map((a) => a.name), contains('Raw'));
    final orphan = (await reopened.getAllTransactions()).single;
    expect(
      (await reopened.getCategoryById(orphan.categoryId))?.type,
      'expense',
    );
    final id = await reopened.insertAccount(
      AccountsCompanion.insert(
        name: 'New',
        type: 'bank',
        color: 0,
        icon: 'account_balance',
        currency: const Value('EGP'),
      ),
    );
    expect((await reopened.getAccountById(id))?.createdAt, isNotNull);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
}
