import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/core/finance/recurring_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/core/services/transaction_notification_parser.dart';

void main() {
  test(
    'parses an Apple Pay spending notification into a draft transaction',
    () {
      final parsed = TransactionNotificationParser.parse(
        'Apple Pay: Card 1234 spent 24.90 USD at Starbucks',
      );

      expect(parsed.type, 'expense');
      expect(parsed.amount, 24.90);
      expect(parsed.merchant, 'Starbucks');
      expect(parsed.confidence, greaterThan(0.5));
    },
  );

  test('detects income-style notification wording', () {
    final parsed = TransactionNotificationParser.parse(
      'Your salary account was credited with 3500 USD from Payroll',
    );

    expect(parsed.type, 'income');
    expect(parsed.amount, 3500);
    expect(parsed.merchant, 'Payroll');
  });

  test('clamps monthly recurring dates at month end', () {
    final next = AppDatabase.nextRecurringDate(
      current: DateTime(2026, 1, 31, 10, 15),
      frequency: 'monthly',
    );

    expect(next.year, 2026);
    expect(next.month, 2);
    expect(next.day, 28);
    expect(next.hour, 10);
    expect(next.minute, 15);
  });

  test('clamps leap-day yearly recurring dates', () {
    final next = AppDatabase.nextRecurringDate(
      current: DateTime(2024, 2, 29, 8, 0),
      frequency: 'yearly',
    );

    expect(next.year, 2025);
    expect(next.month, 2);
    expect(next.day, 28);
  });

  test('expense lowers bank balance and delete restores it', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final accountId = await db.insertAccount(
      AccountsCompanion.insert(
        name: 'Checking',
        type: 'bank',
        color: 0xFF000000,
        icon: 'account_balance',
        balance: Value(1000),
      ),
    );
    final categoryId = await db.insertCategory(
      CategoriesCompanion.insert(
        name: 'Dining',
        icon: 'restaurant',
        color: 0xFF111111,
        type: 'expense',
        sortOrder: Value(100),
      ),
    );

    await FinancialLedgerService(db).insertTransactionAndUpdateBalance(
      TransactionsCompanion.insert(
        accountId: accountId,
        categoryId: categoryId,
        amount: 125,
        type: 'expense',
        transactionDate: DateTime(2026, 5, 4),
      ),
    );

    final savedTransaction = (await db.getAllTransactions()).single;
    expect((await db.getAccountById(accountId))!.balance, 875);

    await FinancialLedgerService(
      db,
    ).deleteTransactionAndUpdateBalance(savedTransaction.id);
    expect((await db.getAccountById(accountId))!.balance, 1000);
  });

  test('expense on credit account increases debt balance', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final accountId = await db.insertAccount(
      AccountsCompanion.insert(
        name: 'Credit Card',
        type: 'credit',
        color: 0xFF000000,
        icon: 'credit_card',
        balance: Value(400),
      ),
    );
    final categoryId = await db.insertCategory(
      CategoriesCompanion.insert(
        name: 'Travel',
        icon: 'flight',
        color: 0xFF111111,
        type: 'expense',
        sortOrder: Value(101),
      ),
    );

    await FinancialLedgerService(db).insertTransactionAndUpdateBalance(
      TransactionsCompanion.insert(
        accountId: accountId,
        categoryId: categoryId,
        amount: 60,
        type: 'expense',
        transactionDate: DateTime(2026, 5, 4),
      ),
    );

    expect((await db.getAccountById(accountId))!.balance, 460);
  });

  test(
    'updating a transaction rebalances old and new accounts correctly',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final cashAccountId = await db.insertAccount(
        AccountsCompanion.insert(
          name: 'Cash',
          type: 'cash',
          color: 0xFF000000,
          icon: 'account_balance_wallet',
          balance: Value(500),
        ),
      );
      final savingsAccountId = await db.insertAccount(
        AccountsCompanion.insert(
          name: 'Savings',
          type: 'bank',
          color: 0xFF000000,
          icon: 'savings',
          balance: Value(800),
        ),
      );
      final expenseCategoryId = await db.insertCategory(
        CategoriesCompanion.insert(
          name: 'Groceries',
          icon: 'shopping_cart',
          color: 0xFF111111,
          type: 'expense',
          sortOrder: Value(102),
        ),
      );
      final incomeCategoryId = await db.insertCategory(
        CategoriesCompanion.insert(
          name: 'Bonus',
          icon: 'payments',
          color: 0xFF222222,
          type: 'income',
          sortOrder: Value(103),
        ),
      );

      await FinancialLedgerService(db).insertTransactionAndUpdateBalance(
        TransactionsCompanion.insert(
          accountId: cashAccountId,
          categoryId: expenseCategoryId,
          amount: 50,
          type: 'expense',
          transactionDate: DateTime(2026, 5, 4),
        ),
      );

      final existing = (await db.getAllTransactions()).single;
      await FinancialLedgerService(db).updateTransactionAndUpdateBalance(
        existing.copyWith(
          accountId: savingsAccountId,
          categoryId: incomeCategoryId,
          amount: 120,
          type: 'income',
          note: const Value('Updated'),
        ),
      );

      expect((await db.getAccountById(cashAccountId))!.balance, 500);
      expect((await db.getAccountById(savingsAccountId))!.balance, 920);
    },
  );

  test(
    'transfers create matching in and out transactions and move balances',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final fromAccountId = await db.insertAccount(
        AccountsCompanion.insert(
          name: 'Wallet',
          type: 'cash',
          color: 0xFF000000,
          icon: 'account_balance_wallet',
          balance: Value(300),
        ),
      );
      final toAccountId = await db.insertAccount(
        AccountsCompanion.insert(
          name: 'Bank',
          type: 'bank',
          color: 0xFF000000,
          icon: 'account_balance',
          balance: Value(700),
        ),
      );

      await FinancialLedgerService(db).transferBetweenAccounts(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: 80,
        date: DateTime(2026, 5, 4),
      );

      final transactions = await db.getAllTransactions();
      expect(transactions, hasLength(2));
      expect(transactions.where((t) => t.type == 'expense'), hasLength(1));
      expect(transactions.where((t) => t.type == 'income'), hasLength(1));
      expect((await db.getAccountById(fromAccountId))!.balance, 220);
      expect((await db.getAccountById(toAccountId))!.balance, 780);

      final categories = await db.getAllCategories();
      expect(
        categories.any((c) => c.name == 'Transfer Out' && c.type == 'expense'),
        isTrue,
      );
      expect(
        categories.any((c) => c.name == 'Transfer In' && c.type == 'income'),
        isTrue,
      );
    },
  );

  test(
    'deleting one side of a transfer deletes the linked side and restores balances',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final fromAccountId = await db.insertAccount(
        AccountsCompanion.insert(
          name: 'Wallet',
          type: 'cash',
          color: 0xFF000000,
          icon: 'account_balance_wallet',
          balance: Value(300),
        ),
      );
      final toAccountId = await db.insertAccount(
        AccountsCompanion.insert(
          name: 'Bank',
          type: 'bank',
          color: 0xFF000000,
          icon: 'account_balance',
          balance: Value(700),
        ),
      );

      await FinancialLedgerService(db).transferBetweenAccounts(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: 80,
        date: DateTime(2026, 5, 4),
      );

      final transferSide = (await db.getAllTransactions()).first;
      await FinancialLedgerService(
        db,
      ).deleteTransactionAndUpdateBalance(transferSide.id);

      expect(await db.getAllTransactions(), isEmpty);
      expect((await db.getAccountById(fromAccountId))!.balance, 300);
      expect((await db.getAccountById(toAccountId))!.balance, 700);
    },
  );

  test(
    'processing due recurring transactions creates one transaction and advances next date',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final accountId = await db.insertAccount(
        AccountsCompanion.insert(
          name: 'Checking',
          type: 'bank',
          color: 0xFF000000,
          icon: 'account_balance',
          balance: Value(1000),
        ),
      );
      final categoryId = await db.insertCategory(
        CategoriesCompanion.insert(
          name: 'Salary',
          icon: 'payments',
          color: 0xFF10B981,
          type: 'income',
          sortOrder: Value(0),
        ),
      );

      await db.insertRecurringTransaction(
        RecurringTransactionsCompanion.insert(
          accountId: accountId,
          categoryId: categoryId,
          amount: 250,
          type: 'income',
          frequency: 'monthly',
          nextDate: DateTime(2026, 1, 31),
        ),
      );

      await RecurringService(
        FinancialLedgerService(db),
      ).processDue(now: DateTime(2026, 1, 31));

      final transactions = await db.getAllTransactions();
      final recurring = await db.getActiveRecurringTransactions();
      expect(transactions, hasLength(1));
      expect((await db.getAccountById(accountId))!.balance, 1250);
      expect(recurring.single.nextDate, DateTime(2026, 2, 28));
    },
  );
}
