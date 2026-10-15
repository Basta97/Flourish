import 'dart:io';
import 'dart:async';
import '../finance/finance_store.dart';
import '../../domain/finance/amount.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/finance/system_categories.dart';
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
        await _ensureIndexes();
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
        await _ensureIndexes();
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA journal_mode = WAL');
        if (!details.wasCreated) await repairLegacyData();
      },
    );
  }

  Future<void> _ensureIndexes() async {
    for (final statement in const [
      'CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions(account_id)',
      'CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON transactions(category_id)',
      'CREATE INDEX IF NOT EXISTS idx_transactions_transaction_date ON transactions(transaction_date)',
      'CREATE INDEX IF NOT EXISTS idx_transactions_type_date ON transactions(type, transaction_date)',
      'CREATE INDEX IF NOT EXISTS idx_transactions_linked ON transactions(linked_transaction_id)',
      'CREATE INDEX IF NOT EXISTS idx_budgets_category_id ON budgets(category_id)',
      'CREATE INDEX IF NOT EXISTS idx_categories_type ON categories(type)',
    ]) {
      await customStatement(statement);
    }
  }

  /// Repairs rows written while an upgraded database still used the v5
  /// rebuild's column defaults. Safe to run repeatedly.
  ///
  /// * `created_at` received SQLite's TEXT `CURRENT_TIMESTAMP`, which Drift
  ///   cannot read back as a unix timestamp, so whole tables failed to load.
  /// * `category_id` was nullable there, so deleting a category could leave
  ///   rows that crash every read.
  Future<void> repairLegacyData() async {
    for (final table in const [
      'accounts',
      'transactions',
      'recurring_transactions',
      'budgets',
      'goals',
    ]) {
      await customStatement(
        "UPDATE $table SET created_at = COALESCE(CAST(strftime('%s', created_at) AS INTEGER), CAST(strftime('%s', 'now') AS INTEGER)) WHERE typeof(created_at) = 'text'",
      );
    }
    for (final table in const ['transactions', 'recurring_transactions']) {
      final orphans = await customSelect(
        'SELECT DISTINCT type FROM $table WHERE category_id IS NULL',
      ).get();
      for (final row in orphans) {
        final type = row.read<String>('type') == 'income'
            ? 'income'
            : 'expense';
        final fallback = await fallbackCategoryFor(type);
        await customStatement(
          'UPDATE $table SET category_id = ? WHERE category_id IS NULL AND type = ?',
          [fallback.id, row.read<String>('type')],
        );
      }
    }
  }

  /// The catch-all category for [type], created when missing.
  Future<Category> fallbackCategoryFor(String type) async {
    final id = await SystemCategories.idFor(
      this,
      type == 'income' ? 'other_income' : 'other_expense',
    );
    return (await getCategoryById(id))!;
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
          currency: const Value(AppConstants.defaultCurrency),
          color: 0xFF10B981,
          icon: 'account_balance_wallet',
        ),
        AccountsCompanion.insert(
          name: 'Bank Account',
          type: 'bank',
          currency: const Value(AppConstants.defaultCurrency),
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
    // Upgraded databases still carry the old 'USD' column default, so never
    // rely on it.
    if (!entry.currency.present) {
      entry = entry.copyWith(
        currency: const Value(AppConstants.defaultCurrency),
      );
    }
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

  /// Updates presentation fields only. Balances change exclusively through
  /// [FinancialLedgerService], which keeps `exact_balances` in step.
  Future<void> updateAccount(Account entry) async {
    await (update(accounts)..where((a) => a.id.equals(entry.id))).write(
      AccountsCompanion(
        name: Value(entry.name),
        color: Value(entry.color),
        icon: Value(entry.icon),
      ),
    );
    notifyFinanceChanged();
  }

  /// Whether anything references the account's currency: transactions,
  /// recurring rules, goals, contracts or holdings bought through it.
  Future<bool> accountHasHistory(int id) async {
    final tx =
        await (select(transactions)
              ..where((t) => t.accountId.equals(id))
              ..limit(1))
            .get();
    if (tx.isNotEmpty) return true;
    final rules =
        await (select(recurringTransactions)
              ..where((r) => r.accountId.equals(id))
              ..limit(1))
            .get();
    final linkedGoals =
        await (select(goals)
              ..where((g) => g.accountId.equals(id))
              ..limit(1))
            .get();
    if (rules.isNotEmpty || linkedGoals.isNotEmpty) return true;
    final store = FinanceStore(this);
    final contracts = await store.list('contracts');
    return contracts.any(
      (c) => c['accountId'] == id || c['cardAccountId'] == id,
    );
  }

  Future<void> changeAccountCurrency(int id, String currency) =>
      transaction(() async {
        if (await accountHasHistory(id)) {
          throw const TransactionLogicException(
            'The currency of an account with history cannot change.',
          );
        }
        await (update(accounts)..where((a) => a.id.equals(id))).write(
          AccountsCompanion(currency: Value(currency)),
        );
        notifyFinanceChanged();
      });

  Future<int> deleteAccount(int id) => transaction(() async {
    final contracts = await FinanceStore(this).list('contracts');
    if (contracts.any(
      (c) => c['accountId'] == id || c['cardAccountId'] == id,
    )) {
      throw const TransactionLogicException(
        'This account is linked to a contract. Archive it instead.',
      );
    }
    final history =
        await (select(transactions)
              ..where((t) => t.accountId.equals(id))
              ..limit(1))
            .get();
    if (history.isNotEmpty) {
      throw const TransactionLogicException(
        'This account has financial history. Archive it through Manage account instead.',
      );
    }
    final result = await (delete(accounts)..where((a) => a.id.equals(id))).go();
    await FinanceStore(this).remove('accountDetails', '$id');
    notifyFinanceChanged();
    return result;
  });

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

  // Row primitives: callers outside FinancialLedgerService must not use these,
  // because they do not adjust balances (see test/architecture_test.dart).
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
      readsFrom: {transactions, accounts, categories},
    ).get();

    return Future.wait(rows.map((row) => transactions.mapFromRow(row)));
  }

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

  /// Deletes a user category, moving its entries and recurring rules to the
  /// catch-all "Other"/"Other income". System categories cannot be deleted.
  Future<void> deleteCategoryAndReassignTransactions(int id) async {
    await transaction(() async {
      final category = await getCategoryById(id);
      if (category == null) return;
      if (SystemCategories.isSystem(category)) {
        throw const TransactionLogicException(
          'This category is used for automatic entries and cannot be deleted.',
        );
      }
      final fallback = await fallbackCategoryFor(category.type);
      await (update(transactions)..where((t) => t.categoryId.equals(id))).write(
        TransactionsCompanion(categoryId: Value(fallback.id)),
      );
      await (update(
        recurringTransactions,
      )..where((r) => r.categoryId.equals(id))).write(
        RecurringTransactionsCompanion(categoryId: Value(fallback.id)),
      );
      final store = FinanceStore(this);
      for (final link in await store.list('categoryParents')) {
        if (link['child'] == id || link['parent'] == id) {
          await store.remove('categoryParents', '${link['child']}');
        }
      }
      for (final template in await store.list('templates')) {
        if (template['category'] == '$id') {
          await store.put('templates', template['id'], {
            ...template,
            'category': '${fallback.id}',
          });
        }
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

  Future<void> contributeToGoal(int goalId, double amount) => transaction(
    () async {
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
    },
  );

  Future<Account> _requireAccount(int id) async {
    final account = await getAccountById(id);
    if (account == null) {
      throw const TransactionLogicException(
        'The selected account no longer exists.',
      );
    }
    return account;
  }
}

class TransactionLogicException implements Exception {
  const TransactionLogicException(this.message);

  final String message;

  @override
  String toString() => message;
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
