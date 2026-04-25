import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bastasaving/core/theme/app_colors.dart';
import 'package:bastasaving/core/theme/app_text_styles.dart';
import 'package:bastasaving/core/utils/date_formatter.dart';
import 'package:bastasaving/core/utils/currency_formatter.dart';
import 'package:bastasaving/data/database/database.dart';
import 'package:bastasaving/presentation/providers/account_providers.dart';
import 'package:bastasaving/presentation/providers/transaction_providers.dart';
import 'package:bastasaving/presentation/providers/category_providers.dart';
import 'package:bastasaving/presentation/providers/theme_providers.dart';
import 'package:bastasaving/shared/widgets/animated_counter.dart';
import 'package:bastasaving/shared/widgets/glass_card.dart';
import 'package:bastasaving/shared/widgets/section_header.dart';
import 'package:bastasaving/shared/widgets/empty_state.dart';
import 'package:bastasaving/shared/widgets/category_icon_widget.dart';
import 'package:bastasaving/presentation/transactions/widgets/add_transaction_sheet.dart';
import 'package:drift/drift.dart' hide Column;

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAutoIncome());
  }

  Future<void> _checkAutoIncome() async {
    final autoIncome = ref.read(monthlyAutoIncomeProvider);
    if (!autoIncome) return;

    final amount = ref.read(monthlyIncomeAmountProvider);
    if (amount <= 0) return;

    final accountId = ref.read(monthlyIncomeAccountIdProvider);
    final categoryId = ref.read(monthlyIncomeCategoryIdProvider);
    if (accountId == null || categoryId == null) return;

    final lastMonth = ref.read(lastAutoIncomeMonthProvider);
    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month}';
    if (lastMonth == currentMonthKey) return;

    final db = ref.read(transactionDaoProvider);
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    final existing = await db.sumTransactionsByType('income', monthStart, monthEnd);
    final hasAutoIncome = existing >= amount;
    if (hasAutoIncome) {
      ref.read(lastAutoIncomeMonthProvider.notifier).state = currentMonthKey;
      return;
    }

    final day = ref.read(monthlyIncomeDayProvider);
    if (now.day < day) return;

    await db.insertTransaction(TransactionsCompanion.insert(
      accountId: accountId,
      categoryId: categoryId,
      amount: amount,
      type: 'income',
      note: const Value('Auto monthly income'),
      transactionDate: DateTime(now.year, now.month, day),
    ));

    final account = await db.getAccountById(accountId);
    if (account != null) {
      await db.updateAccount(account.copyWith(balance: account.balance + amount));
    }

    ref.read(lastAutoIncomeMonthProvider.notifier).state = currentMonthKey;
    ref.invalidate(accountsProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(totalBalanceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(defaultCurrencyProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final totalBalanceAsync = ref.watch(totalBalanceProvider);

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = monthEnd.day;
    final dayOfMonth = now.day;
    final monthProgress = dayOfMonth / daysInMonth;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.gradientPrimary,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.savings, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text('BastaSaving', style: AppTextStyles.heading.copyWith(fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountsProvider);
          ref.invalidate(transactionsProvider);
          ref.invalidate(totalBalanceProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            _GreetingHeader(),
            const SizedBox(height: 12),
            _NetWorthHero(totalBalanceAsync: totalBalanceAsync, currency: currency),
            const SizedBox(height: 16),
            _IncomeExpenseRow(
              transactionsAsync: transactionsAsync,
              monthStart: monthStart,
              monthEnd: monthEnd,
              currency: currency,
            ),
            const SizedBox(height: 16),
            _MonthlyOverview(
              dayOfMonth: dayOfMonth,
              daysInMonth: daysInMonth,
              progress: monthProgress,
              transactionsAsync: transactionsAsync,
              monthStart: monthStart,
              monthEnd: monthEnd,
              currency: currency,
            ),
            const SizedBox(height: 16),
            _QuickActions(ref: ref, currency: currency),
            const SizedBox(height: 16),
            SectionHeader(title: 'Accounts'),
            _AccountSummaryList(accountsAsync: accountsAsync),
            const SizedBox(height: 8),
            SectionHeader(title: 'Recent Transactions'),
            _RecentTransactions(
              transactionsAsync: transactionsAsync,
              categoriesAsync: categoriesAsync,
              accountsAsync: accountsAsync,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  void _showAddTransactionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProviderScope(
        overrides: [],
        child: const AddTransactionSheet(),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _dateString() {
    final now = DateTime.now();
    return '${_dayName(now.weekday)}, ${DateFormatter.format(now)}';
  }

  String _dayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting(), style: AppTextStyles.headingBold.copyWith(fontSize: 24)),
                const SizedBox(height: 2),
                Text(
                  _dateString(),
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NetWorthHero extends ConsumerWidget {
  final AsyncValue<double> totalBalanceAsync;
  final String currency;

  const _NetWorthHero({required this.totalBalanceAsync, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        gradient: AppColors.gradientNetWorth,
        padding: const EdgeInsets.all(24),
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Net Worth',
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Icon(Icons.account_balance_wallet, color: Colors.white.withValues(alpha: 0.6), size: 20),
              ],
            ),
            const SizedBox(height: 8),
            totalBalanceAsync.when(
              data: (balance) => AnimatedCounter(
                value: balance,
                currency: currency,
                style: AppTextStyles.numberBold.copyWith(
                  fontSize: 38,
                  color: Colors.white,
                ),
              ),
              loading: () => const SizedBox(
                height: 46,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ),
              error: (_, __) => Text(
                CurrencyFormatter.format(0, currency: currency),
                style: AppTextStyles.numberBold.copyWith(fontSize: 38, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeExpenseRow extends ConsumerWidget {
  final AsyncValue<List<Transaction>> transactionsAsync;
  final DateTime monthStart;
  final DateTime monthEnd;
  final String currency;

  const _IncomeExpenseRow({
    required this.transactionsAsync,
    required this.monthStart,
    required this.monthEnd,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return transactionsAsync.when(
      data: (transactions) {
        final monthlyTx = transactions.where(
          (t) => t.transactionDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
              t.transactionDate.isBefore(monthEnd.add(const Duration(days: 1))),
        ).toList();

        final income = monthlyTx
            .where((t) => t.type == 'income')
            .fold<double>(0, (s, t) => s + t.amount);
        final expense = monthlyTx
            .where((t) => t.type == 'expense')
            .fold<double>(0, (s, t) => s + t.amount);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _SummaryMiniCard(
                  icon: Icons.arrow_upward,
                  label: 'Income',
                  amount: income,
                  currency: currency,
                  color: AppColors.income,
                  gradient: AppColors.gradientIncome,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryMiniCard(
                  icon: Icons.arrow_downward,
                  label: 'Expense',
                  amount: expense,
                  currency: currency,
                  color: AppColors.expense,
                  gradient: AppColors.gradientExpense,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 80),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _SummaryMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;
  final String currency;
  final Color color;
  final List<Color> gradient;

  const _SummaryMiniCard({
    required this.icon,
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradient: gradient,
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.formatCompact(amount, currency: currency),
            style: AppTextStyles.numberBold.copyWith(
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyOverview extends ConsumerWidget {
  final int dayOfMonth;
  final int daysInMonth;
  final double progress;
  final AsyncValue<List<Transaction>> transactionsAsync;
  final DateTime monthStart;
  final DateTime monthEnd;
  final String currency;

  const _MonthlyOverview({
    required this.dayOfMonth,
    required this.daysInMonth,
    required this.progress,
    required this.transactionsAsync,
    required this.monthStart,
    required this.monthEnd,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Monthly Overview', style: AppTextStyles.bodySemiBold.copyWith(fontSize: 15)),
                const Spacer(),
                Text(
                  '${DateFormatter.formatMonth(monthStart)}',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Day $dayOfMonth of $daysInMonth',
                  style: AppTextStyles.body.copyWith(fontSize: 13),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: AppTextStyles.numberMono.copyWith(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                color: AppColors.primary,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 14),
            transactionsAsync.when(
              data: (transactions) {
                final monthlyTx = transactions.where(
                  (t) => t.transactionDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
                      t.transactionDate.isBefore(monthEnd.add(const Duration(days: 1))),
                ).toList();

                final income = monthlyTx
                    .where((t) => t.type == 'income')
                    .fold<double>(0, (s, t) => s + t.amount);
                final expense = monthlyTx
                    .where((t) => t.type == 'expense')
                    .fold<double>(0, (s, t) => s + t.amount);
                final balance = income - expense;
                final dailyAvg = dayOfMonth > 0 ? expense / dayOfMonth : 0.0;

                return Row(
                  children: [
                    _OverviewStat(
                      label: 'Balance',
                      value: CurrencyFormatter.formatCompact(balance, currency: currency),
                      color: balance >= 0 ? AppColors.income : AppColors.expense,
                    ),
                    const SizedBox(width: 16),
                    _OverviewStat(
                      label: 'Daily Avg',
                      value: CurrencyFormatter.formatCompact(dailyAvg, currency: currency),
                      color: null,
                    ),
                    const SizedBox(width: 16),
                    _OverviewStat(
                      label: 'Tx Count',
                      value: '${monthlyTx.length}',
                      color: null,
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(height: 30),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _OverviewStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTextStyles.numberMono.copyWith(
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final WidgetRef ref;
  final String currency;

  const _QuickActions({required this.ref, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.arrow_upward,
              label: 'Income',
              color: AppColors.income,
              onTap: () => _openSheet(context, ref, 'income'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              icon: Icons.arrow_downward,
              label: 'Expense',
              color: AppColors.expense,
              onTap: () => _openSheet(context, ref, 'expense'),
            ),
          ),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context, WidgetRef ref, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProviderScope(
        overrides: [],
        child: AddTransactionSheet(initialType: type),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(label, style: AppTextStyles.bodyMedium.copyWith(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSummaryList extends ConsumerWidget {
  final AsyncValue<List<Account>> accountsAsync;

  const _AccountSummaryList({required this.accountsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: accounts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final account = accounts[index];
              final gradientIdx = AppColors.accountGradientIndex(account.icon);
              return _AccountMiniCard(account: account, gradientIdx: gradientIdx);
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 100),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _AccountMiniCard extends ConsumerWidget {
  final Account account;
  final int gradientIdx;

  const _AccountMiniCard({required this.account, required this.gradientIdx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = AppColors.accountGradients[gradientIdx % AppColors.accountGradients.length];
    return GlassCard(
      gradient: gradient,
      width: 160,
      height: 100,
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      onTap: () => context.push('/accounts/${account.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconData(account.icon),
                color: Colors.white.withValues(alpha: 0.9),
                size: 18,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  account.currency,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            account.name,
            style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.85)),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            CurrencyFormatter.formatCompact(account.balance, currency: account.currency),
            style: AppTextStyles.numberBold.copyWith(fontSize: 17, color: Colors.white),
          ),
        ],
      ),
    );
  }

  IconData _iconData(String name) {
    switch (name) {
      case 'account_balance': return Icons.account_balance;
      case 'account_balance_wallet': return Icons.account_balance_wallet;
      case 'credit_card': return Icons.credit_card;
      case 'savings': return Icons.savings;
      case 'wallet': return Icons.wallet;
      case 'payments': return Icons.payments;
      case 'currency_exchange': return Icons.currency_exchange;
      case 'monetization_on': return Icons.monetization_on;
      default: return Icons.account_balance_wallet;
    }
  }
}

class _RecentTransactions extends ConsumerWidget {
  final AsyncValue<List<Transaction>> transactionsAsync;
  final AsyncValue<List<Category>> categoriesAsync;
  final AsyncValue<List<Account>> accountsAsync;

  const _RecentTransactions({
    required this.transactionsAsync,
    required this.categoriesAsync,
    required this.accountsAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return transactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long,
            title: 'No transactions yet',
            subtitle: 'Tap + to add your first transaction',
          );
        }
        final recent = transactions.take(10).toList();
        return categoriesAsync.when(
          data: (categories) => accountsAsync.when(
            data: (accounts) => Column(
              children: recent.map((t) => _TransactionItem(
                transaction: t,
                category: categories.cast<Category?>().firstWhere(
                  (c) => c?.id == t.categoryId,
                  orElse: () => null,
                ),
                account: accounts.cast<Account?>().firstWhere(
                  (a) => a?.id == t.accountId,
                  orElse: () => null,
                ),
              )).toList(),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
      ),
    );
  }
}

class _TransactionItem extends ConsumerWidget {
  final Transaction transaction;
  final Category? category;
  final Account? account;

  const _TransactionItem({
    required this.transaction,
    this.category,
    this.account,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(defaultCurrencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = transaction.type == 'income';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              CategoryIconWidget(
                iconName: category?.icon ?? 'more_horiz',
                color: Color(category?.color ?? 0xFF6B7280),
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category?.name ?? 'Unknown',
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (account != null) ...[
                          Text(
                            account!.name,
                            style: AppTextStyles.caption.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          DateFormatter.format(transaction.transactionDate),
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isIncome ? AppColors.income : AppColors.expense).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${isIncome ? '+' : '-'}${CurrencyFormatter.formatCompact(transaction.amount, currency: account?.currency ?? currency)}',
                  style: AppTextStyles.numberMono.copyWith(
                    fontSize: 13,
                    color: isIncome ? AppColors.income : AppColors.expense,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
