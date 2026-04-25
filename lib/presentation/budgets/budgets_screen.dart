import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bastasaving/core/theme/app_colors.dart';
import 'package:bastasaving/core/theme/app_text_styles.dart';
import 'package:bastasaving/core/utils/currency_formatter.dart';
import 'package:bastasaving/data/database/database.dart';
import 'package:bastasaving/presentation/providers/budget_providers.dart';
import 'package:bastasaving/presentation/providers/category_providers.dart';
import 'package:bastasaving/presentation/providers/transaction_providers.dart';
import 'package:bastasaving/presentation/providers/theme_providers.dart';
import 'package:bastasaving/shared/widgets/glass_card.dart';
import 'package:bastasaving/shared/widgets/empty_state.dart';
import 'package:bastasaving/shared/widgets/section_header.dart';
import 'package:bastasaving/shared/widgets/category_icon_widget.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(budgetsProvider.future),
        child: budgetsAsync.when(
          data: (budgets) {
            if (budgets.isEmpty) {
              return const EmptyState(
                icon: Icons.track_changes,
                title: 'No budgets set',
                subtitle: 'Create a budget to track your spending limits',
                action: null,
              );
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                const SectionHeader(title: 'Active Budgets'),
                ...budgets.map((b) => _BudgetCard(
                  budget: b,
                  onDelete: () => _deleteBudget(b.id),
                )),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const EmptyState(icon: Icons.error, title: 'Error loading budgets'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBudgetSheet,
        icon: const Icon(Icons.add),
        label: const Text('Budget'),
      ),
    );
  }

  void _showAddBudgetSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddBudgetSheet(ref: ref),
    );
  }

  void _deleteBudget(int id) async {
    final dao = ref.read(budgetDaoProvider);
    await dao.deleteBudget(id);
  }
}

class _BudgetCard extends ConsumerWidget {
  final Budget budget;
  final VoidCallback onDelete;

  const _BudgetCard({required this.budget, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catAsync = ref.watch(categoryByIdProvider(budget.categoryId));
    final currency = ref.watch(defaultCurrencyProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: catAsync.when(
        data: (cat) {
          if (cat == null) return const SizedBox.shrink();
          return GlassCard(
            borderRadius: 14,
            child: Row(
              children: [
                CategoryIconWidget(
                  iconName: cat.icon,
                  color: Color(cat.color),
                  size: 44,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat.name, style: AppTextStyles.bodyMedium.copyWith(fontSize: 14)),
                      const SizedBox(height: 4),
                      _BudgetProgress(budget: budget, category: cat, currency: currency),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.danger.withValues(alpha: 0.6),
                  onPressed: onDelete,
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

class _BudgetProgress extends ConsumerWidget {
  final Budget budget;
  final Category category;
  final String currency;

  const _BudgetProgress({required this.budget, required this.category, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rangeStart = budget.startDate;
    DateTime rangeEnd;
    switch (budget.period) {
      case 'weekly':
        rangeEnd = rangeStart.add(const Duration(days: 7));
        break;
      case 'yearly':
        rangeEnd = DateTime(rangeStart.year + 1, rangeStart.month, rangeStart.day);
        break;
      default:
        rangeEnd = DateTime(rangeStart.year, rangeStart.month + 1, rangeStart.day);
    }

    final tRange = DateTimeRange(start: rangeStart, end: rangeEnd);
    final txAsync = ref.watch(transactionsByDateRangeProvider(tRange));

    return txAsync.when(
      data: (transactions) {
        final spent = transactions
            .where((t) => t.categoryId == budget.categoryId && t.type == 'expense')
            .fold<double>(0, (s, t) => s + t.amount);
        final progress = (spent / budget.amount).clamp(0.0, 1.0);
        final remaining = budget.amount - spent;
        final isOver = remaining < 0;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                color: isOver ? AppColors.danger : AppColors.accent,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${CurrencyFormatter.formatCompact(spent, currency: currency)} / ${CurrencyFormatter.formatCompact(budget.amount, currency: currency)}',
                  style: AppTextStyles.caption.copyWith(
                    color: isOver ? AppColors.danger : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  ),
                ),
                const Spacer(),
                Text(
                  isOver
                      ? 'over ${CurrencyFormatter.formatCompact(remaining.abs(), currency: currency)}'
                      : '${CurrencyFormatter.formatCompact(remaining, currency: currency)} left',
                  style: AppTextStyles.caption.copyWith(
                    color: isOver ? AppColors.danger : AppColors.accent,
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(value: 0),
      error: (_, __) => const LinearProgressIndicator(value: 0),
    );
  }
}

class _AddBudgetSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddBudgetSheet({required this.ref});

  @override
  State<_AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends State<_AddBudgetSheet> {
  final _amountController = TextEditingController();
  int? _categoryId;
  String _period = 'monthly';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = widget.ref.watch(categoriesProvider);
    final currency = widget.ref.read(defaultCurrencyProvider);

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondaryLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Create Budget', style: AppTextStyles.heading.copyWith(fontSize: 20)),
          const SizedBox(height: 20),
          categoriesAsync.when(
            data: (cats) {
              final expenseCats = cats.where((c) => c.type == 'expense').toList();
              return DropdownButtonFormField<int>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: expenseCats.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Row(
                    children: [
                      CategoryIconWidget(iconName: c.icon, color: Color(c.color), size: 28, iconSize: 14),
                      const SizedBox(width: 8),
                      Text(c.name),
                    ],
                  ),
                )).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _categoryId = v);
                },
              );
            },
            loading: () => const SizedBox(height: 60),
            error: (_, __) => const SizedBox(height: 60),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Budget Amount',
              prefixText: '${CurrencyFormatter.symbolFor(currency)} ',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _period,
            decoration: const InputDecoration(labelText: 'Period'),
            items: const [
              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _period = v);
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create Budget', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _submit() async {
    if (_categoryId == null) return;
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    final dao = widget.ref.read(budgetDaoProvider);
    await dao.insertBudget(BudgetsCompanion.insert(
      categoryId: _categoryId!,
      amount: amount,
      period: _period,
      startDate: DateTime.now(),
    ));
    if (mounted) Navigator.pop(context);
  }
}
