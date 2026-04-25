import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:bastasaving/core/theme/app_colors.dart';
import 'package:bastasaving/core/theme/app_text_styles.dart';
import 'package:bastasaving/core/utils/currency_formatter.dart';
import 'package:bastasaving/data/database/database.dart';
import 'package:bastasaving/presentation/providers/transaction_providers.dart';
import 'package:bastasaving/presentation/providers/category_providers.dart';
import 'package:bastasaving/presentation/providers/theme_providers.dart';
import 'package:bastasaving/shared/widgets/glass_card.dart';
import 'package:bastasaving/shared/widgets/category_icon_widget.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _period = 'month';

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(defaultCurrencyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PeriodSelector(
            period: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 20),
          _SummaryIndicators(period: _period, currency: currency),
          const SizedBox(height: 20),
          _ExpensePieChart(period: _period, currency: currency),
          const SizedBox(height: 20),
          _IncomeExpenseBarChart(period: _period),
          const SizedBox(height: 20),
          _TopCategories(period: _period, currency: currency),
          const SizedBox(height: 20),
          _MonthlyComparison(period: _period, currency: currency),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final String period;
  final ValueChanged<String> onChanged;

  const _PeriodSelector({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PeriodChip(label: 'Week', value: 'week', selected: period == 'week', onTap: () => onChanged('week')),
        const SizedBox(width: 8),
        _PeriodChip(label: 'Month', value: 'month', selected: period == 'month', onTap: () => onChanged('month')),
        const SizedBox(width: 8),
        _PeriodChip(label: 'Year', value: 'year', selected: period == 'year', onTap: () => onChanged('year')),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : (Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08)),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 13,
            color: selected ? Colors.white : null,
          ),
        ),
      ),
    );
  }
}

class _SummaryIndicators extends ConsumerWidget {
  final String period;
  final String currency;

  const _SummaryIndicators({required this.period, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final range = _getRange(period, now);
    final tRange = DateTimeRange(start: range.start, end: range.end);
    final transactionsAsync = ref.watch(transactionsByDateRangeProvider(tRange));

    return transactionsAsync.when(
      data: (transactions) {
        final income = transactions.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount);
        final expense = transactions.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount);
        final balance = income - expense;
        final savingsRate = income > 0 ? (balance / income * 100) : 0.0;
        final days = range.end.difference(range.start).inDays + 1;
        final dailyAvg = expense / (days > 0 ? days : 1);

        return Row(
          children: [
            Expanded(
              child: _IndicatorCard(
                icon: Icons.savings,
                label: 'Savings Rate',
                value: '${savingsRate.toStringAsFixed(1)}%',
                color: savingsRate >= 0 ? AppColors.income : AppColors.expense,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _IndicatorCard(
                icon: Icons.trending_up,
                label: 'Balance',
                value: CurrencyFormatter.formatCompact(balance, currency: currency),
                color: balance >= 0 ? AppColors.income : AppColors.expense,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _IndicatorCard(
                icon: Icons.calendar_today,
                label: 'Daily Avg',
                value: CurrencyFormatter.formatCompact(dailyAvg, currency: currency),
                color: null,
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(height: 100),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _IndicatorCard({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      borderRadius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.numberBold.copyWith(
              fontSize: 18,
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

class _ExpensePieChart extends ConsumerWidget {
  final String period;
  final String currency;

  const _ExpensePieChart({required this.period, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final now = DateTime.now();
    final range = _getRange(period, now);
    final tRange = DateTimeRange(start: range.start, end: range.end);
    final transactionsAsync = ref.watch(transactionsByDateRangeProvider(tRange));

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending Breakdown', style: AppTextStyles.bodySemiBold.copyWith(fontSize: 16)),
          const SizedBox(height: 16),
          transactionsAsync.when(
            data: (transactions) {
              return categoriesAsync.when(
                data: (categories) {
                  final expenses = transactions.where((t) => t.type == 'expense').toList();
                  if (expenses.isEmpty) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: Text('No expenses this period')),
                    );
                  }
                  final total = expenses.fold<double>(0, (s, t) => s + t.amount);
                  final grouped = <int, double>{};
                  for (final t in expenses) {
                    grouped[t.categoryId] = (grouped[t.categoryId] ?? 0) + t.amount;
                  }
                  final sorted = grouped.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

                  return Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sections: sorted.map((e) {
                              final cat = categories.cast<Category?>().firstWhere(
                                (c) => c?.id == e.key,
                                orElse: () => null,
                              );
                              final color = Color(cat?.color ?? 0xFF6B7280);
                              final percentage = (e.value / total * 100);
                              return PieChartSectionData(
                                value: e.value,
                                color: color,
                                radius: 60,
                                title: percentage >= 5 ? '${percentage.toStringAsFixed(0)}%' : '',
                                titleStyle: AppTextStyles.label.copyWith(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              );
                            }).toList(),
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...sorted.take(5).map((e) {
                        final cat = categories.cast<Category?>().firstWhere(
                          (c) => c?.id == e.key,
                          orElse: () => null,
                        );
                        final color = Color(cat?.color ?? 0xFF6B7280);
                        final pct = (e.value / total * 100);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                              const SizedBox(width: 8),
                              Expanded(child: Text(cat?.name ?? 'Unknown', style: AppTextStyles.body.copyWith(fontSize: 13))),
                              Text('${pct.toStringAsFixed(0)}%', style: AppTextStyles.caption),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.formatCompact(e.value, currency: currency),
                                style: AppTextStyles.numberMono.copyWith(fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
                loading: () => const SizedBox(height: 200),
                error: (_, __) => const SizedBox(height: 200),
              );
            },
            loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox(height: 200),
          ),
        ],
      ),
    );
  }
}

class _IncomeExpenseBarChart extends ConsumerWidget {
  final String period;
  const _IncomeExpenseBarChart({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final range = _getRange(period, now);

    Future<List<BarChartGroupData>> _loadBars() async {
      final db = ref.read(transactionDaoProvider);
      final bars = <BarChartGroupData>[];
      final days = range.end.difference(range.start).inDays;
      final step = days > 30 ? 7 : 1;

      for (var d = range.start; d.isBefore(range.end) || d.isAtSameMomentAs(range.start); ) {
        final endDay = d.add(Duration(days: step));
        final income = await db.sumTransactionsByType('income', d, endDay);
        final expense = await db.sumTransactionsByType('expense', d, endDay);
        bars.add(BarChartGroupData(
          x: d.millisecondsSinceEpoch ~/ (1000 * 60 * 60 * 24),
          barRods: [
            BarChartRodData(toY: income, color: AppColors.income, width: step > 1 ? 12 : 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            BarChartRodData(toY: expense, color: AppColors.expense, width: step > 1 ? 12 : 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          ],
        ));
        d = endDay;
      }
      return bars;
    }

    return GlassCard(
      child: FutureBuilder<List<BarChartGroupData>>(
        future: _loadBars(),
        builder: (context, snapshot) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Income vs Expense', style: AppTextStyles.bodySemiBold.copyWith(fontSize: 16)),
              const SizedBox(height: 16),
              if (snapshot.hasData && snapshot.data!.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: snapshot.data!.expand((g) => g.barRods.map((r) => r.toY)).reduce((a, b) => a > b ? a : b) * 1.2,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(show: false),
                      barGroups: snapshot.data!,
                    ),
                  ),
                )
              else
                const SizedBox(height: 200, child: Center(child: Text('No data yet'))),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Legend(color: AppColors.income, label: 'Income'),
                  const SizedBox(width: 24),
                  _Legend(color: AppColors.expense, label: 'Expense'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopCategories extends ConsumerWidget {
  final String period;
  final String currency;

  const _TopCategories({required this.period, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final now = DateTime.now();
    final range = _getRange(period, now);
    final tRange = DateTimeRange(start: range.start, end: range.end);
    final transactionsAsync = ref.watch(transactionsByDateRangeProvider(tRange));

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Spending Categories', style: AppTextStyles.bodySemiBold.copyWith(fontSize: 16)),
          const SizedBox(height: 16),
          transactionsAsync.when(
            data: (transactions) {
              return categoriesAsync.when(
                data: (categories) {
                  final expenses = transactions.where((t) => t.type == 'expense').toList();
                  if (expenses.isEmpty) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: Text('No expenses')),
                    );
                  }
                  final total = expenses.fold<double>(0, (s, t) => s + t.amount);
                  final grouped = <int, double>{};
                  for (final t in expenses) {
                    grouped[t.categoryId] = (grouped[t.categoryId] ?? 0) + t.amount;
                  }
                  final sorted = grouped.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

                  return Column(
                    children: sorted.take(5).map((e) {
                      final cat = categories.cast<Category?>().firstWhere(
                        (c) => c?.id == e.key,
                        orElse: () => null,
                      );
                      final color = Color(cat?.color ?? 0xFF6B7280);
                      final pct = (e.value / total * 100);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            CategoryIconWidget(iconName: cat?.icon ?? 'more_horiz', color: color, size: 36, iconSize: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cat?.name ?? 'Unknown', style: AppTextStyles.body.copyWith(fontSize: 13)),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: pct / 100,
                                      backgroundColor: color.withValues(alpha: 0.1),
                                      color: color,
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.formatCompact(e.value, currency: currency),
                                  style: AppTextStyles.numberMono.copyWith(fontSize: 13),
                                ),
                                Text(
                                  '${pct.toStringAsFixed(0)}%',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const SizedBox(height: 100),
                error: (_, __) => const SizedBox(height: 100),
              );
            },
            loading: () => const SizedBox(height: 100),
            error: (_, __) => const SizedBox(height: 100),
          ),
        ],
      ),
    );
  }
}

class _MonthlyComparison extends ConsumerWidget {
  final String period;
  final String currency;

  const _MonthlyComparison({required this.period, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();

    final currentRange = _getRange(period, now);
    DateTime prevStart;
    DateTime prevEnd;

    switch (period) {
      case 'week':
        prevStart = currentRange.start.subtract(const Duration(days: 7));
        prevEnd = currentRange.end.subtract(const Duration(days: 7));
        break;
      case 'year':
        prevStart = DateTime(currentRange.start.year - 1, currentRange.start.month, currentRange.start.day);
        prevEnd = DateTime(currentRange.end.year - 1, currentRange.end.month, currentRange.end.day);
        break;
      default:
        prevStart = DateTime(currentRange.start.year, currentRange.start.month - 1, currentRange.start.day);
        prevEnd = DateTime(currentRange.end.year, currentRange.end.month - 1, currentRange.end.day);
    }

    final currTRange = DateTimeRange(start: currentRange.start, end: currentRange.end);
    final prevTRange = DateTimeRange(start: prevStart, end: prevEnd);

    final currTx = ref.watch(transactionsByDateRangeProvider(currTRange));
    final prevTx = ref.watch(transactionsByDateRangeProvider(prevTRange));

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Period Comparison', style: AppTextStyles.bodySemiBold.copyWith(fontSize: 16)),
          const SizedBox(height: 16),
          currTx.when(
            data: (current) {
              return prevTx.when(
                data: (previous) {
                  final currIncome = current.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount);
                  final currExpense = current.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount);
                  final prevIncome = previous.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount);
                  final prevExpense = previous.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount);

                  final incomeChange = prevIncome > 0 ? ((currIncome - prevIncome) / prevIncome * 100) : 0.0;
                  final expenseChange = prevExpense > 0 ? ((currExpense - prevExpense) / prevExpense * 100) : 0.0;

                  return Column(
                    children: [
                      _ComparisonRow(
                        label: 'Income',
                        current: currIncome,
                        previous: prevIncome,
                        change: incomeChange,
                        currency: currency,
                      ),
                      const SizedBox(height: 12),
                      _ComparisonRow(
                        label: 'Expense',
                        current: currExpense,
                        previous: prevExpense,
                        change: expenseChange,
                        isExpense: true,
                        currency: currency,
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(height: 80),
                error: (_, __) => const SizedBox(height: 80),
              );
            },
            loading: () => const SizedBox(height: 80),
            error: (_, __) => const SizedBox(height: 80),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final double current;
  final double previous;
  final double change;
  final bool isExpense;
  final String currency;

  const _ComparisonRow({
    required this.label,
    required this.current,
    required this.previous,
    required this.change,
    this.isExpense = false,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final changeColor = change > 0
        ? (isExpense ? AppColors.expense : AppColors.income)
        : (change < 0 ? (isExpense ? AppColors.income : AppColors.expense) : null);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: AppTextStyles.body.copyWith(fontSize: 14)),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatCompact(current, currency: currency),
                style: AppTextStyles.numberMono.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 12,
                    color: changeColor ?? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${change.abs().toStringAsFixed(1)}%',
                    style: AppTextStyles.caption.copyWith(
                      color: changeColor ?? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'vs prev',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.body.copyWith(fontSize: 13)),
      ],
    );
  }
}

DateTimeRange _getRange(String period, DateTime now) {
  switch (period) {
    case 'week':
      return DateTimeRange(
        start: now.subtract(Duration(days: now.weekday - 1)),
        end: now.add(Duration(days: 7 - now.weekday)),
      );
    case 'month':
      return DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      );
    case 'year':
      return DateTimeRange(
        start: DateTime(now.year, 1, 1),
        end: DateTime(now.year, 12, 31),
      );
    default:
      return DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      );
  }
}
