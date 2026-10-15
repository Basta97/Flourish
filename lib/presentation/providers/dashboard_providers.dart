import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import 'account_providers.dart';
import 'category_providers.dart';
import 'transaction_providers.dart';

/// Combined dashboard data provider that flattens nested AsyncValue.when chains
/// into a single async provider. This prevents cascading rebuilds and makes
/// the dashboard build method much simpler.
final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final transactions = await ref.watch(transactionsProvider.future);
  final accounts = await ref.watch(accountsProvider.future);
  final categories = await ref.watch(categoriesProvider.future);
  return DashboardData(
    transactions: transactions,
    accounts: accounts,
    categories: categories,
  );
});

/// Memoized dashboard stats computation. Only recomputes when the underlying
/// transaction/account/category data changes.
final dashboardStatsProvider = Provider.family<DashboardStats, String>((
  ref,
  currency,
) {
  final data = ref.watch(dashboardDataProvider).valueOrNull;
  if (data == null) {
    return DashboardStats.empty(currency);
  }

  final now = DateTime.now();
  final categoryById = {
    for (final category in data.categories) category.id: category,
  };
  final accountById = {
    for (final account in data.accounts) account.id: account,
  };

  return DashboardStats.from(
    now: now,
    transactions: data.transactions,
    categoriesById: categoryById,
    accountsById: accountById,
    currency: currency,
  );
});

class DashboardData {
  const DashboardData({
    required this.transactions,
    required this.accounts,
    required this.categories,
  });

  final List<Transaction> transactions;
  final List<Account> accounts;
  final List<Category> categories;
}

class DashboardStats {
  const DashboardStats({
    required this.monthTransactionsCount,
    required this.income,
    required this.expense,
    required this.burnRate,
    required this.topExpenseCategory,
    required this.topExpenseAmount,
    required this.topSpendingAccount,
    required this.topSpendingAccountAmount,
  });

  final int monthTransactionsCount;
  final double income;
  final double expense;
  final double burnRate;
  final String topExpenseCategory;
  final String topExpenseAmount;
  final String topSpendingAccount;
  final String topSpendingAccountAmount;

  factory DashboardStats.empty(String currency) => DashboardStats(
    monthTransactionsCount: 0,
    income: 0,
    expense: 0,
    burnRate: 0,
    topExpenseCategory: 'Balanced',
    topExpenseAmount: 'No spending yet',
    topSpendingAccount: 'No heavy spender yet',
    topSpendingAccountAmount: 'Accounts are quiet this month',
  );

  factory DashboardStats.from({
    required DateTime now,
    required List<Transaction> transactions,
    required Map<int, Category> categoriesById,
    required Map<int, Account> accountsById,
    required String currency,
  }) {
    var monthCount = 0;
    var income = 0.0;
    var expense = 0.0;
    final categoryTotals = <int, double>{};
    final accountTotals = <int, double>{};

    for (final tx in transactions) {
      if (tx.transactionDate.year != now.year ||
          tx.transactionDate.month != now.month) {
        continue;
      }
      monthCount++;

      final category = categoriesById[tx.categoryId];
      if (_isTransfer(tx, category)) continue;

      if (tx.type == 'income') {
        income += tx.amount;
      } else if (tx.type == 'expense') {
        expense += tx.amount;
        categoryTotals.update(
          tx.categoryId,
          (value) => value + tx.amount,
          ifAbsent: () => tx.amount,
        );
        accountTotals.update(
          tx.accountId,
          (value) => value + tx.amount,
          ifAbsent: () => tx.amount,
        );
      }
    }

    final topCategory = _topEntry(categoryTotals);
    final topAccount = _topEntry(accountTotals);

    return DashboardStats(
      monthTransactionsCount: monthCount,
      income: income,
      expense: expense,
      burnRate: expense / now.day,
      topExpenseCategory: topCategory == null
          ? 'Balanced'
          : categoriesById[topCategory.key]?.name ?? 'Other',
      topExpenseAmount: topCategory == null
          ? 'No spending yet'
          : CurrencyFormatter.formatCompact(
              topCategory.value,
              currency: currency,
            ),
      topSpendingAccount: topAccount == null
          ? 'No heavy spender yet'
          : accountsById[topAccount.key]?.name ?? 'Main account',
      topSpendingAccountAmount: topAccount == null
          ? 'Accounts are quiet this month'
          : '${CurrencyFormatter.formatCompact(topAccount.value, currency: currency)} spent',
    );
  }

  static bool _isTransfer(Transaction tx, Category? category) {
    final categoryName = category?.name.toLowerCase() ?? '';
    final note = tx.note?.toLowerCase() ?? '';
    return categoryName.startsWith('transfer ') || note.startsWith('transfer:');
  }

  static MapEntry<int, double>? _topEntry(Map<int, double> totals) {
    if (totals.isEmpty) return null;
    return totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
  }
}
