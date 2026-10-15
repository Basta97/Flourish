import '../../core/finance/valuation_service.dart';
import 'dart:io';
import 'dart:async';
import '../finance/finance_store.dart';
import '../../domain/finance/amount.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables/accounts_table.dart';
import 'tables/transactions_table.dart';
import 'tables/categories_table.dart';
import 'tables/budgets_table.dart';
import 'tables/recurring_transactions_table.dart';
import 'tables/goals_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Transactions,
    Categories,
    Budgets,
    RecurringTransactions,
    Goals,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  static DateTime nextRecurringDate({
    required DateTime current,
    required String frequency,
  }) {
    switch (frequency) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'monthly':
        return _shiftMonthClamped(current, 1);
      case 'yearly':
        return _shiftYearClamped(current, 1);
      default:
        return current;
    }
  }

  @override
  int get schemaVersion => 6;

  final financeChanges = StreamController<void>.broadcast();
  void notifyFinanceChanged() {
    if (!financeChanges.isClosed) financeChanges.add(null);
  }

  @override
  Future<void> close() async {
    await financeChanges.close();
    await super.close();
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _seedDefaults();
        await FinanceStore.create(this);
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions(account_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON transactions(category_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_transactions_transaction_date ON transactions(transaction_date)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_transactions_type_date ON transactions(type, transaction_date)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_budgets_category_id ON budgets(category_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_categories_type ON categories(type)',
          );
        }
        if (from < 3) {
          await m.createTable(recurringTransactions);
          await m.createTable(goals);
        }
        // Note: The previous 'from < 4' migration was broken (recreating existing
        // tables which fails with 'table already exists'). It has been removed.
        // Schema version bumped to 5 for the proper migration below.
        if (from < 5) {
          await _migrateToV5();
        }
        if (from < 6) await FinanceStore.create(this);
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA journal_mode = WAL');
      },
    );
  }

  Future<void> _migrateToV5() async {
    await customStatement('PRAGMA foreign_keys = OFF');

    // Migrate transactions table: add linked_transaction_id + CHECK constraint
    await customStatement('''
      CREATE TABLE transactions_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense', 'transfer')),
        note TEXT,
        transaction_date DATETIME NOT NULL,
        linked_transaction_id INTEGER,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await customStatement('''
      INSERT INTO transactions_new
      (id, account_id, category_id, amount, type, note, transaction_date, linked_transaction_id, created_at)
      SELECT id, account_id, category_id, amount, type, note, transaction_date, NULL, created_at
      FROM transactions
    ''');
    await customStatement('DROP TABLE transactions');
    await customStatement(
      'ALTER TABLE transactions_new RENAME TO transactions',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions(account_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON transactions(category_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_transaction_date ON transactions(transaction_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_type_date ON transactions(type, transaction_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_linked ON transactions(linked_transaction_id)',
    );

    // Migrate accounts table: add CHECK constraint
    await customStatement('''
      CREATE TABLE accounts_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('bank', 'cash', 'ewallet', 'credit')),
        balance REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'USD',
        color INTEGER NOT NULL,
        icon TEXT NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await customStatement('''
      INSERT INTO accounts_new
      SELECT id, name, type, balance, currency, color, icon, created_at
      FROM accounts
    ''');
    await customStatement('DROP TABLE accounts');
    await customStatement('ALTER TABLE accounts_new RENAME TO accounts');

    // Migrate categories table: add CHECK constraint
    await customStatement('''
      CREATE TABLE categories_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        is_default INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await customStatement('''
      INSERT INTO categories_new
      SELECT id, name, icon, color, type, is_default, sort_order
      FROM categories
    ''');
    await customStatement('DROP TABLE categories');
    await customStatement('ALTER TABLE categories_new RENAME TO categories');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_categories_type ON categories(type)',
    );

    // Migrate recurring_transactions table: add CHECK constraint
    await customStatement('''
      CREATE TABLE recurring_transactions_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        note TEXT,
        frequency TEXT NOT NULL,
        next_date DATETIME NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await customStatement('''
      INSERT INTO recurring_transactions_new
      SELECT id, account_id, category_id, amount, type, note, frequency, next_date, is_active, created_at
      FROM recurring_transactions
    ''');
    await customStatement('DROP TABLE recurring_transactions');
    await customStatement(
      'ALTER TABLE recurring_transactions_new RENAME TO recurring_transactions',
    );

    // Migrate budgets table: add CHECK constraint
    await customStatement('''
      CREATE TABLE budgets_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        amount REAL NOT NULL,
        period TEXT NOT NULL CHECK(period IN ('weekly', 'monthly', 'yearly')),
        start_date DATETIME NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await customStatement('''
      INSERT INTO budgets_new
      SELECT id, category_id, amount, period, start_date, created_at
      FROM budgets
    ''');
    await customStatement('DROP TABLE budgets');
    await customStatement('ALTER TABLE budgets_new RENAME TO budgets');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_budgets_category_id ON budgets(category_id)',
    );

    await customStatement('PRAGMA foreign_keys = ON');
  }

  Future<void> _seedDefaults() async {
    await batch((b) {
      b.insertAll(categories, [
        CategoriesCompanion.insert(
          name: 'Salary',
          icon: 'payments',
          color: 0xFF10B981,
          type: 'income',
          isDefault: const Value(true),
          sortOrder: const Value(0),
        ),
        CategoriesCompanion.insert(
          name: 'Freelance',
          icon: 'laptop',
          color: 0xFF3B82F6,
          type: 'income',
          isDefault: const Value(true),
          sortOrder: const Value(1),
        ),
        CategoriesCompanion.insert(
          name: 'Investment',
          icon: 'trending_up',
          color: 0xFF8B5CF6,
          type: 'income',
          isDefault: const Value(true),
          sortOrder: const Value(2),
        ),
        CategoriesCompanion.insert(
          name: 'Food & Drinks',
          icon: 'restaurant',
          color: 0xFFEF4444,
          type: 'expense',
          isDefault: const Value(true),
          sortOrder: const Value(3),
        ),
        CategoriesCompanion.insert(
          name: 'Transport',
          icon: 'directions_car',
          color: 0xFFF59E0B,
          type: 'expense',
          isDefault: const Value(true),
          sortOrder: const Value(4),
        ),
        CategoriesCompanion.insert(
          name: 'Shopping',
          icon: 'shopping_bag',
          color: 0xFFEC4899,
          type: 'expense',
          isDefault: const Value(true),
          sortOrder: const Value(5),
        ),
        CategoriesCompanion.insert(
          name: 'Bills & Utilities',
          icon: 'receipt_long',
          color: 0xFF6366F1,
          type: 'expense',
          isDefault: const Value(true),
          sortOrder: const Value(6),
        ),
        CategoriesCompanion.insert(
          name: 'Entertainment',
          icon: 'movie',
          color: 0xFF14B8A6,
          type: 'expense',
          isDefault: const Value(true),
          sortOrder: const Value(7),
        ),
        CategoriesCompanion.insert(
          name: 'Health',
          icon: 'favorite',
          color: 0xFFE11D48,
          type: 'expense',
          isDefault: const Value(true),
          sortOrder: const Value(8),
        ),
        CategoriesCompanion.insert(
          name: 'Education',
          icon: 'school',
          color: 0xFF0EA5E9,
          type: 'expense',
          isDefault: const Value(true),
          sortOrder: const Value(9),
        ),
        CategoriesCompanion.insert(
          name: 'Housing',
          icon: 'home',
          color: 0xFFD97706,
          type: 'expense',
          isDefault: const Value(true),
          sortOrder: const Value(10),
        ),
        CategoriesCompanion.insert(
          name: 'Other',
          icon: 'more_horiz',
          color: 0xFF6B7280,
          type: 'expense',
          isDefault: const Value(true),
          sortOrder: const Value(11),
        ),
      ]);
      b.insertAll(accounts, [
        AccountsCompanion.insert(
          name: 'Cash',
          type: 'cash',
          color: 0xFF10B981,
          icon: 'account_balance_wallet',
        ),
        AccountsCompanion.insert(
          name: 'Bank Account',
          type: 'bank',
          color: 0xFF3B82F6,
          icon: 'account_balance',
        ),
      ]);
    });
  }

  // ========== Accounts ==========

  Future<List<Account>> getAllAccounts() => (select(
    accounts,
  )..orderBy([(a) => OrderingTerm(expression: a.name)])).get();

  Stream<List<Account>> watchAllAccounts() => (select(
    accounts,
  )..orderBy([(a) => OrderingTerm(expression: a.name)])).watch();

  Future<Account?> getAccountById(int id) =>
      (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<int> insertAccount(AccountsCompanion entry) => transaction(() async {
    final id = await into(accounts).insert(entry);
    final balance = entry.balance.present
        ? Amount.fromNum(entry.balance.value)
        : Amount.zero;
    await customStatement('INSERT INTO exact_balances VALUES (?, ?, ?)', [
      id,
      '$balance',
      '$balance',
    ]);
    notifyFinanceChanged();
    return id;
  });

  Future<bool> updateAccount(Account entry) async {
    final result = await update(accounts).replace(entry);
    notifyFinanceChanged();
    return result;
  }

  Future<int> deleteAccount(int id) => transaction(() async {
    final contracts = await FinanceStore(this).list('contracts');
    if (contracts.any(
      (c) => c['accountId'] == id || c['cardAccountId'] == id,
    )) {
      throw const TransactionLogicException(
        'This account is linked to a contract. Archive it instead.',
      );
    }
    final result = await (delete(accounts)..where((a) => a.id.equals(id))).go();
    await FinanceStore(this).remove('accountDetails', '$id');
    notifyFinanceChanged();
    return result;
  });

  Future<double> getNetWorth({String currency = 'EGP'}) async {
    final wealth = await ValuationService(FinanceStore(this)).summary(currency);
    if (!wealth.complete) {
      throw StateError(
        'Cannot total holdings without all required prices and exchange rates',
      );
    }
    return wealth.netWorth.toDouble();
  }

  // ========== Transactions ==========

  Future<List<Transaction>> getAllTransactions() =>
      (select(transactions)..orderBy([
            (t) => OrderingTerm(
              expression: t.transactionDate,
              mode: OrderingMode.desc,
            ),
          ]))
          .get();

  Stream<List<Transaction>> watchAllTransactions() =>
      (select(transactions)..orderBy([
            (t) => OrderingTerm(
              expression: t.transactionDate,
              mode: OrderingMode.desc,
            ),
          ]))
          .watch();

  Future<List<Transaction>> getTransactionsByAccount(int accountId) =>
      (select(transactions)
            ..where((t) => t.accountId.equals(accountId))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.transactionDate,
                mode: OrderingMode.desc,
              ),
            ]))
          .get();

  Stream<List<Transaction>> watchTransactionsByAccount(int accountId) =>
      (select(transactions)
            ..where((t) => t.accountId.equals(accountId))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.transactionDate,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  Future<Transaction?> getTransactionById(int id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  Future<bool> updateTransaction(Transaction entry) =>
      update(transactions).replace(entry);

  Future<int> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Stream<List<Transaction>> watchTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) =>
      (select(transactions)
            ..where(
              (t) =>
                  t.transactionDate.isBetween(Variable(start), Variable(end)),
            )
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.transactionDate,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  Future<double> sumTransactionsByType(
    String type,
    DateTime start,
    DateTime end,
  ) async {
    final rows =
        await (select(transactions)..where(
              (t) =>
                  t.type.equals(type) &
                  t.transactionDate.isBetween(Variable(start), Variable(end)),
            ))
            .get();
    return rows.fold<double>(0, (s, t) => s + t.amount);
  }

  Future<void> insertTransactionAndUpdateBalance(
    TransactionsCompanion entry,
  ) async {
    await transaction(() async {
      final accountId = entry.accountId.value;
      final amount = entry.amount.value;
      final type = entry.type.value;
      final categoryId = entry.categoryId.value;

      _requirePositiveAmount(amount);
      final account = await _requireAccount(accountId);
      await _requireCategoryForType(categoryId, type);

      await into(transactions).insert(entry);
      await _applyTransactionImpact(
        account: account,
        type: type,
        amount: amount,
      );
    });
  }

  Future<void> deleteTransactionAndUpdateBalance(int transactionId) async {
    await transaction(() async {
      final tx = await getTransactionById(transactionId);
      if (tx == null) return;

      final metadata = await FinanceStore(this).transactionDetails(tx.id);
      final feeId = metadata?['feeId'] as int?;
      if (feeId != null) {
        final fee = await getTransactionById(feeId);
        if (fee != null) await _deleteSingleTransactionAndRevert(fee);
      }
      final linkedTx = tx.linkedTransactionId == null
          ? null
          : await getTransactionById(tx.linkedTransactionId!);

      await _deleteSingleTransactionAndRevert(tx);
      if (linkedTx != null) {
        await _deleteSingleTransactionAndRevert(linkedTx);
      }
    });
  }

  Future<void> _deleteSingleTransactionAndRevert(Transaction tx) async {
    final details = await FinanceStore(this).transactionDetails(tx.id);
    final account = await getAccountById(tx.accountId);
    if (account != null) {
      final amount = details?['amount'] == null
          ? Amount.fromNum(tx.amount)
          : Amount(details!['amount'].toString());
      final sign = (tx.type == 'income') != (account.type == 'credit')
          ? Amount.one
          : -Amount.one;
      await FinanceStore(this).changeBalance(account.id, -(amount * sign));
    }
    await deleteTransaction(tx.id);
  }

  Future<void> updateTransactionAndUpdateBalance(Transaction updated) async {
    await transaction(() async {
      final existing = await getTransactionById(updated.id);
      if (existing == null) return;
      if (existing.linkedTransactionId != null) {
        throw const TransactionLogicException(
          'Edit this transfer using the transfer form.',
        );
      }
      _requirePositiveAmount(updated.amount);

      await _requireAccount(updated.accountId);
      await _requireCategoryForType(updated.categoryId, updated.type);

      final oldAccount = await getAccountById(existing.accountId);
      if (oldAccount != null) {
        await _revertTransactionImpact(
          account: oldAccount,
          type: existing.type,
          amount: existing.amount,
        );
      }

      await updateTransaction(updated);
      await _applyTransactionImpact(
        account: await _requireAccount(updated.accountId),
        type: updated.type,
        amount: updated.amount,
      );
    });
  }

  Future<void> transferBetweenAccounts({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    await transaction(() async {
      _requirePositiveAmount(amount);
      if (fromAccountId == toAccountId) {
        throw const TransactionLogicException(
          'Choose two different accounts for a transfer.',
        );
      }

      final fromAccount = await _requireAccount(fromAccountId);
      final toAccount = await _requireAccount(toAccountId);
      final expenseCategory = await _ensureTransferCategory(type: 'expense');
      final incomeCategory = await _ensureTransferCategory(type: 'income');
      final txDate = date ?? DateTime.now();
      final transferNote = _transferNote(
        note,
        fromAccount.name,
        toAccount.name,
      );

      final fromTxId = await into(transactions).insert(
        TransactionsCompanion.insert(
          accountId: fromAccountId,
          categoryId: expenseCategory.id,
          amount: amount,
          type: 'expense',
          note: Value(transferNote),
          transactionDate: txDate,
        ),
      );

      final toTxId = await into(transactions).insert(
        TransactionsCompanion.insert(
          accountId: toAccountId,
          categoryId: incomeCategory.id,
          amount: amount,
          type: 'income',
          note: Value(transferNote),
          transactionDate: txDate,
          linkedTransactionId: Value(fromTxId),
        ),
      );

      // Link the two transactions bidirectionally
      await (update(transactions)..where((t) => t.id.equals(fromTxId))).write(
        TransactionsCompanion(linkedTransactionId: Value(toTxId)),
      );

      await _applyTransactionImpact(
        account: fromAccount,
        type: 'expense',
        amount: amount,
      );
      await _applyTransactionImpact(
        account: toAccount,
        type: 'income',
        amount: amount,
      );
    });
  }

  Future<List<Transaction>> searchTransactions(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    final q = '%$normalized%';

    final rows = await customSelect(
      '''
      SELECT t.* FROM transactions t
      LEFT JOIN accounts a ON t.account_id = a.id
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE
        LOWER(t.note) LIKE ?1 OR
        LOWER(t.type) LIKE ?1 OR
        LOWER(a.name) LIKE ?1 OR
        LOWER(c.name) LIKE ?1
      ORDER BY t.transaction_date DESC
      LIMIT 50
      ''',
      variables: [Variable<String>(q)],
    ).get();

    return rows.map((row) => _transactionFromRow(row)).toList();
  }

  Transaction _transactionFromRow(QueryRow row) => Transaction(
    id: row.read<int>('id'),
    accountId: row.read<int>('account_id'),
    categoryId: row.read<int>('category_id'),
    amount: row.read<double>('amount'),
    type: row.read<String>('type'),
    note: row.readNullable<String>('note'),
    transactionDate: row.read<DateTime>('transaction_date'),
    linkedTransactionId: row.readNullable<int>('linked_transaction_id'),
    createdAt: row.read<DateTime>('created_at'),
  );

  // ========== Categories ==========

  Future<List<Category>> getAllCategories() => (select(
    categories,
  )..orderBy([(c) => OrderingTerm(expression: c.sortOrder)])).get();

  Stream<List<Category>> watchAllCategories() => (select(
    categories,
  )..orderBy([(c) => OrderingTerm(expression: c.sortOrder)])).watch();

  Future<Category?> getCategoryById(int id) =>
      (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<int> insertCategory(CategoriesCompanion entry) =>
      into(categories).insert(entry);

  Future<bool> updateCategory(Category entry) =>
      update(categories).replace(entry);

  Future<int> deleteCategory(int id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  Future<void> deleteCategoryAndReassignTransactions(int id) async {
    await transaction(() async {
      final category = await getCategoryById(id);
      if (category == null) return;

      final fallbackCategory = await _resolveFallbackCategory(category);
      if (fallbackCategory != null) {
        await (update(
          transactions,
        )..where((t) => t.categoryId.equals(id))).write(
          TransactionsCompanion(categoryId: Value(fallbackCategory.id)),
        );
        await (update(
          recurringTransactions,
        )..where((r) => r.categoryId.equals(id))).write(
          RecurringTransactionsCompanion(
            categoryId: Value(fallbackCategory.id),
          ),
        );
      }

      await deleteCategory(id);
    });
  }

  Future<int> getCategoryTransactionCount(int id) {
    final countExpr = transactions.id.count();
    return (selectOnly(transactions)
          ..addColumns([countExpr])
          ..where(transactions.categoryId.equals(id)))
        .map((row) => row.read(countExpr) ?? 0)
        .getSingle();
  }

  Future<Category?> _resolveFallbackCategory(Category category) async {
    final sameType =
        await (select(categories)
              ..where(
                (c) =>
                    c.type.equals(category.type) & c.id.isNotValue(category.id),
              )
              ..orderBy([
                (c) => OrderingTerm(
                  expression: c.isDefault,
                  mode: OrderingMode.desc,
                ),
                (c) => OrderingTerm(expression: c.sortOrder),
              ]))
            .get();

    if (sameType.isEmpty) return null;

    for (final candidate in sameType) {
      if (candidate.name.toLowerCase() == 'other') return candidate;
    }

    return sameType.first;
  }

  // ========== Budgets ==========

  Future<List<Budget>> getAllBudgets() =>
      (select(budgets)..orderBy([
            (b) =>
                OrderingTerm(expression: b.startDate, mode: OrderingMode.desc),
          ]))
          .get();

  Stream<List<Budget>> watchAllBudgets() =>
      (select(budgets)..orderBy([
            (b) =>
                OrderingTerm(expression: b.startDate, mode: OrderingMode.desc),
          ]))
          .watch();

  Future<int> insertBudget(BudgetsCompanion entry) =>
      into(budgets).insert(entry);

  Future<bool> updateBudget(Budget entry) => update(budgets).replace(entry);

  Future<int> deleteBudget(int id) =>
      (delete(budgets)..where((b) => b.id.equals(id))).go();

  // ========== Recurring Transactions ==========

  Stream<List<RecurringTransaction>> watchAllRecurringTransactions() => (select(
    recurringTransactions,
  )..orderBy([(r) => OrderingTerm(expression: r.nextDate)])).watch();

  Future<List<RecurringTransaction>> getActiveRecurringTransactions() =>
      (select(
        recurringTransactions,
      )..where((r) => r.isActive.equals(true))).get();

  Future<List<RecurringTransaction>> getDueRecurringTransactions(
    DateTime date,
  ) =>
      (select(recurringTransactions)..where(
            (r) =>
                r.isActive.equals(true) &
                r.nextDate.isSmallerOrEqualValue(date),
          ))
          .get();

  Future<int> insertRecurringTransaction(
    RecurringTransactionsCompanion entry,
  ) => into(recurringTransactions).insert(entry);

  Future<bool> updateRecurringTransaction(RecurringTransaction entry) =>
      update(recurringTransactions).replace(entry);

  Future<int> deleteRecurringTransaction(int id) =>
      (delete(recurringTransactions)..where((r) => r.id.equals(id))).go();

  Future<void> processDueRecurringTransactions({DateTime? now}) async {
    final until = now ?? DateTime.now();
    await transaction(() async {
      final due = await getDueRecurringTransactions(until);
      for (final original in due) {
        var r = original;
        if (!['daily', 'weekly', 'monthly', 'yearly'].contains(r.frequency)) {
          throw const TransactionLogicException(
            'Unsupported recurring frequency.',
          );
        }
        // Re-read inside the serialized transaction to prevent concurrent duplicates.
        final current = await (select(
          recurringTransactions,
        )..where((t) => t.id.equals(r.id))).getSingle();
        r = current;
        final store = FinanceStore(this);
        final anchorData = await store.get('recurringAnchors', '${r.id}');
        final anchor = anchorData == null
            ? r.nextDate
            : DateTime.parse(anchorData['date'] as String);
        if (anchorData == null) {
          await store.put('recurringAnchors', '${r.id}', {
            'date': anchor.toIso8601String(),
          });
        }
        while (r.isActive && !r.nextDate.isAfter(until)) {
          await insertTransactionAndUpdateBalance(
            TransactionsCompanion.insert(
              accountId: r.accountId,
              categoryId: r.categoryId,
              amount: r.amount,
              type: r.type,
              note: Value(r.note ?? 'Recurring: ${r.frequency}'),
              transactionDate: r.nextDate,
            ),
          );
          var next = nextRecurringDate(
            current: r.nextDate,
            frequency: r.frequency,
          );
          if (r.frequency == 'monthly' || r.frequency == 'yearly') {
            final last = DateTime(next.year, next.month + 1, 0).day;
            next = DateTime(
              next.year,
              next.month,
              anchor.day > last ? last : anchor.day,
              anchor.hour,
              anchor.minute,
            );
          }
          if (!next.isAfter(r.nextDate)) {
            throw StateError('Recurring date did not advance');
          }
          r = r.copyWith(nextDate: next);
          await updateRecurringTransaction(r);
        }
      }
    });
  }

  // ========== Goals ==========

  Stream<List<Goal>> watchAllGoals() => (select(
    goals,
  )..orderBy([(g) => OrderingTerm(expression: g.deadline)])).watch();

  Future<Goal?> getGoalById(int id) =>
      (select(goals)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<int> insertGoal(GoalsCompanion entry) => into(goals).insert(entry);

  Future<bool> updateGoal(Goal entry) => update(goals).replace(entry);

  Future<int> deleteGoal(int id) =>
      (delete(goals)..where((g) => g.id.equals(id))).go();

  Future<void> contributeToGoal(int goalId, double amount) async {
    final goal = await getGoalById(goalId);
    if (goal != null) {
      if (!amount.isFinite || amount <= 0) {
        throw const TransactionLogicException('Enter a positive allocation');
      }
      final account = await _requireAccount(goal.accountId);
      final allocated =
          (await (select(
                goals,
              )..where((g) => g.accountId.equals(goal.accountId))).get())
              .fold<double>(0, (s, g) => s + g.currentAmount);
      if (account.type == 'credit' || allocated + amount > account.balance) {
        throw const TransactionLogicException(
          'Allocations cannot exceed available account cash',
        );
      }
      await updateGoal(
        goal.copyWith(currentAmount: goal.currentAmount + amount),
      );
    }
  }

  Future<Account> _requireAccount(int id) async {
    final account = await getAccountById(id);
    if (account == null) {
      throw const TransactionLogicException(
        'The selected account no longer exists.',
      );
    }
    return account;
  }

  Future<Category> _requireCategoryForType(int id, String type) async {
    final category = await getCategoryById(id);
    if (category == null) {
      throw const TransactionLogicException(
        'The selected category no longer exists.',
      );
    }
    if (category.type != type) {
      throw TransactionLogicException(
        'The selected category does not match a $type transaction.',
      );
    }
    return category;
  }

  void _requirePositiveAmount(double amount) {
    if (!amount.isFinite || amount <= 0) {
      throw const TransactionLogicException(
        'Transaction amount must be greater than zero.',
      );
    }
  }

  Future<void> _applyTransactionImpact({
    required Account account,
    required String type,
    required double amount,
  }) async {
    final delta = _balanceDeltaForTransaction(
      accountType: account.type,
      transactionType: type,
      amount: amount,
    );
    await FinanceStore(this).changeBalance(account.id, Amount.fromNum(delta));
  }

  Future<void> _revertTransactionImpact({
    required Account account,
    required String type,
    required double amount,
  }) async {
    final delta = _balanceDeltaForTransaction(
      accountType: account.type,
      transactionType: type,
      amount: amount,
    );
    await FinanceStore(this).changeBalance(account.id, -Amount.fromNum(delta));
  }

  Future<Category> _ensureTransferCategory({required String type}) async {
    final targetName = type == 'income' ? 'Transfer In' : 'Transfer Out';
    final existing =
        await (select(categories)
              ..where((c) => c.type.equals(type) & c.name.equals(targetName)))
            .getSingleOrNull();
    if (existing != null) return existing;

    final maxSortOrder = categories.sortOrder.max();
    final maxValue = await (selectOnly(categories)..addColumns([maxSortOrder]))
        .map((row) => row.read(maxSortOrder))
        .getSingleOrNull();

    final id = await into(categories).insert(
      CategoriesCompanion.insert(
        name: targetName,
        icon: type == 'income' ? 'south_west' : 'north_east',
        color: type == 'income' ? 0xFF0EA5E9 : 0xFF8B5CF6,
        type: type,
        sortOrder: Value((maxValue ?? 0) + 1),
      ),
    );

    return (await getCategoryById(id))!;
  }

  String _transferNote(
    String? note,
    String fromAccountName,
    String toAccountName,
  ) {
    final trimmed = note?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return 'Transfer: $fromAccountName -> $toAccountName';
  }
}

class TransactionLogicException implements Exception {
  const TransactionLogicException(this.message);

  final String message;

  @override
  String toString() => message;
}

double _balanceDeltaForTransaction({
  required String accountType,
  required String transactionType,
  required double amount,
}) {
  final isCredit = accountType == 'credit';
  if (transactionType == 'income') {
    return isCredit ? -amount : amount;
  }
  return isCredit ? amount : -amount;
}

DateTime _shiftMonthClamped(DateTime value, int monthDelta) {
  final shiftedMonth = value.month + monthDelta;
  final shiftedYear = value.year + ((shiftedMonth - 1) ~/ 12);
  final normalizedMonth = ((shiftedMonth - 1) % 12) + 1;
  final lastDay = DateTime(shiftedYear, normalizedMonth + 1, 0).day;
  final clampedDay = value.day > lastDay ? lastDay : value.day;
  return DateTime(
    shiftedYear,
    normalizedMonth,
    clampedDay,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}

DateTime _shiftYearClamped(DateTime value, int yearDelta) {
  final shiftedYear = value.year + yearDelta;
  final lastDay = DateTime(shiftedYear, value.month + 1, 0).day;
  final clampedDay = value.day > lastDay ? lastDay : value.day;
  return DateTime(
    shiftedYear,
    value.month,
    clampedDay,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final oldFile = File(p.join(dbFolder.path, 'bastasaving.db'));
    final newFile = File(p.join(dbFolder.path, 'flourish.db'));
    if (await oldFile.exists() && !await newFile.exists()) {
      await oldFile.rename(newFile.path);
    }
    return NativeDatabase(newFile);
  });
}
