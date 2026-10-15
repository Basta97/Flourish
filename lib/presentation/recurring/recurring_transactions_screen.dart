import 'package:flourish/shared/widgets/spring_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/shared/widgets/shimmer_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/core/utils/date_formatter.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/providers/recurring_provider.dart';
import 'package:flourish/presentation/providers/category_providers.dart';
import 'package:flourish/presentation/providers/account_providers.dart';
import 'package:flourish/presentation/providers/theme_providers.dart';
import 'package:flourish/shared/widgets/animated_list_item.dart';
import 'package:flourish/shared/widgets/category_icon_widget.dart';
import 'package:flourish/shared/widgets/empty_state.dart';
import 'package:flourish/shared/widgets/app_card.dart';
import 'package:flourish/shared/widgets/bottom_sheet_scaffold.dart';
import 'package:flourish/shared/widgets/liquid_page.dart';
import 'package:drift/drift.dart' hide Column;

class RecurringTransactionsScreen extends ConsumerWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringTransactionsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSpringBottomSheet(
          context: context,
          builder: (_) => const _AddRecurringSheet(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Recurring payment'),
      ),
      appBar: AppBar(title: const Text('Recurring Transactions')),
      body: LiquidPageBackground(
        child: recurringAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.repeat,
                title: 'No recurring transactions',
                subtitle: 'Set up automatic transactions',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(Sp.xl),
              itemCount: items.length,
              itemBuilder: (context, index) => AnimatedListItem(
                index: index,
                child: _RecurringCard(recurring: items[index]),
              ),
            );
          },
          loading: () => const ShimmerList(),
          error: (error, stackTrace) =>
              const EmptyState(icon: Icons.error, title: 'Error loading'),
        ),
      ),
    );
  }

  // Add recurring via center nav FAB now
  // void _showAddSheet(BuildContext context) { ... }
}

class _RecurringCard extends ConsumerWidget {
  final RecurringTransaction recurring;
  const _RecurringCard({required this.recurring});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catAsync = ref.watch(categoryByIdProvider(recurring.categoryId));
    final currency = ref.watch(defaultCurrencyProvider);
    final isIncome = recurring.type == 'income';

    final palette = FlourishPalette.of(context);
    final cat = catAsync.valueOrNull;
    final tone = isIncome ? palette.income : palette.textHigh;

    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      // Paused schedules recede rather than disappear.
      child: AnimatedOpacity(
        opacity: recurring.isActive ? 1 : 0.55,
        duration: Motion.of(context, Motion.base),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.xs, Sp.md),
          child: Row(
            children: [
              CategoryIconWidget(
                iconName: cat?.icon ?? 'more_horiz',
                color: Color(cat?.color ?? AppColors.fallbackColor),
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            cat?.name ?? _frequencyLabel(recurring.frequency),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: palette.textHigh,
                            ),
                          ),
                        ),
                        if (!recurring.isActive) ...[
                          const SizedBox(width: 6),
                          _Tag('PAUSED', palette.warning),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_frequencyLabel(recurring.frequency)} · next ${DateFormatter.format(recurring.nextDate)}',
                      style: AppTextStyles.caption.copyWith(
                        color: palette.textLow,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (recurring.note != null && recurring.note!.isNotEmpty)
                      Text(
                        recurring.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: palette.textLow,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : '−'}${CurrencyFormatter.format(recurring.amount, currency: currency)}',
                style: AppTextStyles.numberSmall.copyWith(color: tone),
              ),
              PopupMenuButton<String>(
                tooltip: 'Recurring options',
                icon: Icon(Icons.more_vert_rounded, color: palette.textLow),
                onSelected: (action) async {
                  Haptics.select();
                  final db = ref.read(databaseProvider);
                  if (action == 'toggle') {
                    await db.updateRecurringTransaction(
                      recurring.copyWith(isActive: !recurring.isActive),
                    );
                  } else if (action == 'delete') {
                    await db.deleteRecurringTransaction(recurring.id);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(recurring.isActive ? 'Pause' : 'Resume'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _frequencyLabel(String freq) {
    switch (freq) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      default:
        return freq;
    }
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(Rad.full),
    ),
    child: Text(
      text,
      style: AppTextStyles.caption.copyWith(fontSize: 10, color: color),
    ),
  );
}

class _AddRecurringSheet extends ConsumerStatefulWidget {
  const _AddRecurringSheet();

  @override
  ConsumerState<_AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends ConsumerState<_AddRecurringSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'expense';
  String _frequency = 'monthly';
  int? _accountId;
  int? _categoryId;
  DateTime _nextDate = DateTime.now().add(const Duration(days: 1));
  bool _isSubmitting = false;
  String? _amountError;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final currency = ref.watch(defaultCurrencyProvider);

    return BottomSheetScaffold(
      title: 'New Recurring Transaction',
      children: [
        Row(
          children: [
            Expanded(
              child: _TypeBtn(
                label: 'Expense',
                selected: _type == 'expense',
                color: AppColors.expense,
                onTap: () => setState(() {
                  _type = 'expense';
                  _categoryId = null;
                }),
              ),
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: _TypeBtn(
                label: 'Income',
                selected: _type == 'income',
                color: AppColors.income,
                onTap: () => setState(() {
                  _type = 'income';
                  _categoryId = null;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: Sp.lg),
        TextField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: 'Amount',
            prefixText: '${CurrencyFormatter.symbolFor(currency)} ',
            hintText: '0.00',
            errorText: _amountError,
          ),
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() => _amountError = null),
        ),
        const SizedBox(height: Sp.md),
        accountsAsync.when(
          data: (accounts) {
            if (_accountId == null && accounts.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _accountId == null) {
                  setState(() => _accountId = accounts.first.id);
                }
              });
            }
            return DropdownButtonFormField<int>(
              key: ValueKey('recurring-account-$_accountId-${accounts.length}'),
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Account'),
              items: accounts
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _accountId = v);
                }
              },
            );
          },
          loading: () => const SizedBox(height: 60),
          error: (error, stackTrace) => const SizedBox(height: 60),
        ),
        const SizedBox(height: Sp.md),
        categoriesAsync.when(
          data: (cats) {
            final filtered = cats.where((c) => c.type == _type).toList();
            if (filtered.isNotEmpty && _categoryId == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _categoryId == null) {
                  setState(() => _categoryId = filtered.first.id);
                }
              });
            }
            final effectiveCat =
                _categoryId != null && filtered.any((c) => c.id == _categoryId)
                ? _categoryId
                : (filtered.isNotEmpty ? filtered.first.id : null);
            return DropdownButtonFormField<int>(
              key: ValueKey('recurring-category-$_type-$effectiveCat'),
              initialValue: effectiveCat,
              decoration: const InputDecoration(labelText: 'Category'),
              items: filtered
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          CategoryIconWidget(
                            iconName: c.icon,
                            color: Color(c.color),
                            size: 28,
                            iconSize: 14,
                          ),
                          const SizedBox(width: Sp.sm),
                          Text(c.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _categoryId = v);
                }
              },
            );
          },
          loading: () => const SizedBox(height: 60),
          error: (error, stackTrace) => const SizedBox(height: 60),
        ),
        const SizedBox(height: Sp.md),
        DropdownButtonFormField<String>(
          initialValue: _frequency,
          decoration: const InputDecoration(labelText: 'Frequency'),
          items: const [
            DropdownMenuItem(value: 'daily', child: Text('Daily')),
            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => _frequency = v);
            }
          },
        ),
        const SizedBox(height: Sp.md),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _nextDate,
              firstDate: DateTime.now(),
              lastDate: DateTime(2035),
            );
            if (picked != null) setState(() => _nextDate = picked);
          },
          borderRadius: BorderRadius.circular(Rad.md),
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'First Occurrence'),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: Sp.sm),
                Text(DateFormatter.formatFull(_nextDate)),
              ],
            ),
          ),
        ),
        const SizedBox(height: Sp.md),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
          maxLines: 1,
        ),
        const SizedBox(height: Sp.xxl),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: Sp.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Rad.md),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create Recurring', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Enter a valid amount');
      return;
    }
    if (_accountId == null || _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select account and category')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final db = ref.read(databaseProvider);
      await db.insertRecurringTransaction(
        RecurringTransactionsCompanion.insert(
          accountId: _accountId!,
          categoryId: _categoryId!,
          amount: amount,
          type: _type,
          frequency: _frequency,
          nextDate: _nextDate,
          note: Value(
            _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          ),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeBtn({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Sp.md),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(Rad.md),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: selected ? color : null,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
