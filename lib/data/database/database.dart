import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables/accounts_table.dart';
import 'tables/transactions_table.dart';
import 'tables/categories_table.dart';
import 'tables/budgets_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Accounts, Transactions, Categories, Budgets],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _seedDefaults();
      },
    );
  }

  Future<void> _seedDefaults() async {
    await batch((b) {
      b.insertAll(categories, [
        CategoriesCompanion.insert(name: 'Salary', icon: 'payments', color: 0xFF10B981, type: 'income', isDefault: const Value(true), sortOrder: const Value(0)),
        CategoriesCompanion.insert(name: 'Freelance', icon: 'laptop', color: 0xFF3B82F6, type: 'income', isDefault: const Value(true), sortOrder: const Value(1)),
        CategoriesCompanion.insert(name: 'Investment', icon: 'trending_up', color: 0xFF8B5CF6, type: 'income', isDefault: const Value(true), sortOrder: const Value(2)),
        CategoriesCompanion.insert(name: 'Food & Drinks', icon: 'restaurant', color: 0xFFEF4444, type: 'expense', isDefault: const Value(true), sortOrder: const Value(3)),
        CategoriesCompanion.insert(name: 'Transport', icon: 'directions_car', color: 0xFFF59E0B, type: 'expense', isDefault: const Value(true), sortOrder: const Value(4)),
        CategoriesCompanion.insert(name: 'Shopping', icon: 'shopping_bag', color: 0xFFEC4899, type: 'expense', isDefault: const Value(true), sortOrder: const Value(5)),
        CategoriesCompanion.insert(name: 'Bills & Utilities', icon: 'receipt_long', color: 0xFF6366F1, type: 'expense', isDefault: const Value(true), sortOrder: const Value(6)),
        CategoriesCompanion.insert(name: 'Entertainment', icon: 'movie', color: 0xFF14B8A6, type: 'expense', isDefault: const Value(true), sortOrder: const Value(7)),
        CategoriesCompanion.insert(name: 'Health', icon: 'favorite', color: 0xFFE11D48, type: 'expense', isDefault: const Value(true), sortOrder: const Value(8)),
        CategoriesCompanion.insert(name: 'Education', icon: 'school', color: 0xFF0EA5E9, type: 'expense', isDefault: const Value(true), sortOrder: const Value(9)),
        CategoriesCompanion.insert(name: 'Housing', icon: 'home', color: 0xFFD97706, type: 'expense', isDefault: const Value(true), sortOrder: const Value(10)),
        CategoriesCompanion.insert(name: 'Other', icon: 'more_horiz', color: 0xFF6B7280, type: 'expense', isDefault: const Value(true), sortOrder: const Value(11)),
      ]);
      b.insertAll(accounts, [
        AccountsCompanion.insert(name: 'Cash', type: 'cash', color: 0xFF10B981, icon: 'account_balance_wallet'),
        AccountsCompanion.insert(name: 'Bank Account', type: 'bank', color: 0xFF3B82F6, icon: 'account_balance'),
      ]);
    });
  }

  // ========== Accounts ==========

  Future<List<Account>> getAllAccounts() =>
      (select(accounts)..orderBy([(a) => OrderingTerm(expression: a.name)])).get();

  Stream<List<Account>> watchAllAccounts() =>
      (select(accounts)..orderBy([(a) => OrderingTerm(expression: a.name)])).watch();

  Future<Account?> getAccountById(int id) =>
      (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<int> insertAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<bool> updateAccount(Account entry) =>
      update(accounts).replace(entry);

  Future<int> deleteAccount(int id) =>
      (delete(accounts)..where((a) => a.id.equals(id))).go();

  Future<double> getNetWorth() async {
    final all = await (select(accounts)).get();
    double total = 0;
    for (final a in all) {
      total += a.type == 'credit' ? -a.balance : a.balance;
    }
    return total;
  }

  // ========== Transactions ==========

  Future<List<Transaction>> getAllTransactions() =>
      (select(transactions)..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)])).get();

  Stream<List<Transaction>> watchAllTransactions() =>
      (select(transactions)..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)])).watch();

  Future<List<Transaction>> getTransactionsByAccount(int accountId) =>
      (select(transactions)
            ..where((t) => t.accountId.equals(accountId))
            ..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)]))
          .get();

  Stream<List<Transaction>> watchTransactionsByAccount(int accountId) =>
      (select(transactions)
            ..where((t) => t.accountId.equals(accountId))
            ..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)]))
          .watch();

  Future<int> insertTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  Future<int> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Stream<List<Transaction>> watchTransactionsByDateRange(DateTime start, DateTime end) =>
      (select(transactions)
            ..where((t) => t.transactionDate.isBetween(Variable(start), Variable(end)))
            ..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)]))
          .watch();

  Future<double> sumTransactionsByType(String type, DateTime start, DateTime end) async {
    final rows = await (select(transactions)
          ..where((t) => t.type.equals(type) & t.transactionDate.isBetween(Variable(start), Variable(end))))
        .get();
    return rows.fold<double>(0, (s, t) => s + t.amount);
  }

  // ========== Categories ==========

  Future<List<Category>> getAllCategories() =>
      (select(categories)..orderBy([(c) => OrderingTerm(expression: c.sortOrder)])).get();

  Stream<List<Category>> watchAllCategories() =>
      (select(categories)..orderBy([(c) => OrderingTerm(expression: c.sortOrder)])).watch();

  Future<Category?> getCategoryById(int id) =>
      (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<int> insertCategory(CategoriesCompanion entry) =>
      into(categories).insert(entry);

  Future<int> deleteCategory(int id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  // ========== Budgets ==========

  Future<List<Budget>> getAllBudgets() =>
      (select(budgets)..orderBy([(b) => OrderingTerm(expression: b.startDate, mode: OrderingMode.desc)])).get();

  Stream<List<Budget>> watchAllBudgets() =>
      (select(budgets)..orderBy([(b) => OrderingTerm(expression: b.startDate, mode: OrderingMode.desc)])).watch();

  Future<int> insertBudget(BudgetsCompanion entry) =>
      into(budgets).insert(entry);

  Future<int> deleteBudget(int id) =>
      (delete(budgets)..where((b) => b.id.equals(id))).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'bastasaving.db'));
    return NativeDatabase(file);
  });
}
