import '../../core/constants/app_constants.dart';
import '../providers/finance_providers.dart';
import '../wealth/finance_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/providers/budget_providers.dart';
import 'package:flourish/presentation/providers/category_providers.dart';
import 'package:flourish/presentation/providers/transaction_providers.dart';
import 'package:flourish/presentation/providers/theme_providers.dart';
import 'package:flourish/shared/widgets/animated_list_item.dart';
import 'package:flourish/shared/widgets/app_card.dart';
import 'package:flourish/shared/widgets/bottom_sheet_scaffold.dart';
import 'package:flourish/shared/widgets/empty_state.dart';
import 'package:flourish/shared/widgets/category_icon_widget.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/core/utils/icon_utils.dart';
import 'package:flourish/shared/widgets/pressable.dart';
import 'package:flourish/shared/widgets/progress.dart';
import 'package:flourish/shared/widgets/shimmer_loading.dart';
import 'package:flourish/shared/widgets/spring_bottom_sheet.dart';
import 'package:intl/intl.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final palette = FlourishPalette.of(context);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar.large(title: const Text('Budgets')),
          ...budgetsAsync.when(
            data: (budgets) {
              if (budgets.isEmpty) {
                return [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.track_changes_rounded,
                      title: 'No budgets set',
                      subtitle:
                          'Create a budget to track your spending limits.',
                      action: FilledButton.icon(
                        onPressed: () => showSpringBottomSheet(
                          context: context,
                          builder: (_) => const AddBudgetSheet(),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create a budget'),
                      ),
                    ),
                  ),
                ];
              }
              return [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Sp.screenH,
                    0,
                    Sp.screenH,
                    Sp.md,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      '${budgets.length} ACTIVE ${budgets.length == 1 ? 'BUDGET' : 'BUDGETS'}',
                      style: AppTextStyles.eyebrow.copyWith(
                        color: palette.textLow,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Sp.screenH,
                    0,
                    Sp.screenH,
                    Sp.bottomNavClear + Sp.lg,
                  ),
                  sliver: SliverList.separated(
                    itemCount: budgets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Sp.md),
                    itemBuilder: (context, index) {
                      final b = budgets[index];
                      return AnimatedListItem(
                        key: ValueKey(b.id),
                        index: index,
                        child: _BudgetCard(
                          budget: b,
                          onDelete: () => _confirmDeleteBudget(b.id),
                        ),
                      );
                    },
                  ),
                ),
              ];
            },
            loading: () => [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.screenH),
                sliver: SliverList.list(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Sp.md),
                        child: ShimmerLoading.card(height: 112),
                      ),
                  ],
                ),
              ),
            ],
            error: (error, stackTrace) => [
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Error loading budgets',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBudget(int id) {
    Haptics.warning();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget'),
        content: const Text('Are you sure you want to delete this budget?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final dao = ref.read(budgetDaoProvider);
              await dao.deleteBudget(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// One budget: a progress ring around the category icon that tints amber then
/// coral as spending nears and passes the limit, the amounts, and a stepper
/// for moving between budget periods.
class _BudgetCard extends ConsumerStatefulWidget {
  final Budget budget;
  final VoidCallback onDelete;

  const _BudgetCard({required this.budget, required this.onDelete});

  @override
  ConsumerState<_BudgetCard> createState() => _BudgetCardState();
}

class _BudgetCardState extends ConsumerState<_BudgetCard> {
  int offset = 0;
  Budget get budget => widget.budget;
  String get currency => ref.read(defaultCurrencyProvider);

  // Totals walk transactions through valuation; cache per input set.
  Future<(Amount, Amount, String, int)>? _future;
  Object? _futureKey;

  DateTime rangeStart() {
    final anchor = DateTime(
          budget.startDate.year,
          budget.startDate.month,
          budget.startDate.day,
        ),
        now = DateTime.now();
    if (budget.period == 'weekly') {
      final index = now.isBefore(anchor)
          ? 0
          : now.difference(anchor).inDays ~/ 7;
      return anchor.add(Duration(days: (index + offset) * 7));
    }
    if (budget.period == 'yearly') {
      var index = now.year - anchor.year;
      if (_shiftYearClamped(anchor, index).isAfter(now)) index--;
      return _shiftYearClamped(anchor, (index < 0 ? 0 : index) + offset);
    }
    var index = (now.year - anchor.year) * 12 + now.month - anchor.month;
    if (_shiftMonthClamped(anchor, index).isAfter(now)) index--;
    return _shiftMonthClamped(anchor, (index < 0 ? 0 : index) + offset);
  }

  DateTime _rangeEnd(DateTime start) => budget.period == 'weekly'
      ? start.add(const Duration(days: 7))
      : budget.period == 'yearly'
      ? _shiftYearClamped(start, 1)
      : _shiftMonthClamped(start, 1);

  void _shift(int delta) {
    Haptics.select();
    setState(() => offset += delta);
  }

  @override
  Widget build(BuildContext context) {
    final revision = identityHashCode(ref.watch(financeRevisionProvider));
    final tx = identityHashCode(ref.watch(transactionsProvider).valueOrNull);
    final watchedCurrency = ref.watch(defaultCurrencyProvider);
    final key = (revision, tx, watchedCurrency, offset, budget);
    if (_futureKey != key) {
      _futureKey = key;
      _future = _totals(ref);
    }
    final cat = ref.watch(categoryByIdProvider(budget.categoryId)).valueOrNull;
    final palette = FlourishPalette.of(context);
    final start = rangeStart();
    final end = _rangeEnd(start).subtract(const Duration(days: 1));
    final fmt = DateFormat(budget.period == 'yearly' ? 'MMM y' : 'MMM d');

    return AppCard(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.sm, Sp.md),
      child: FutureBuilder<(Amount, Amount, String, int)>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final ratio = data == null || data.$2 <= Amount.zero || data.$4 < 0
              ? 0.0
              : (data.$1 / data.$2).toDouble();
          final tint = limitTone(context, ratio, palette.accent);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProgressRing(
                value: ratio,
                color: tint,
                size: 64,
                semanticsLabel: data == null
                    ? null
                    : '${(ratio * 100).toStringAsFixed(0)}% of budget used',
                child: cat == null
                    ? null
                    : Icon(
                        IconUtils.categoryIcon(cat.icon),
                        color: Color(cat.color),
                        size: 24,
                      ),
              ),
              const SizedBox(width: Sp.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cat?.name ?? '…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.subtitle.copyWith(
                              color: palette.textHigh,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Budget options',
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            color: palette.textLow,
                          ),
                          onSelected: (v) =>
                              v == 'edit' ? _edit(context) : widget.onDelete(),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
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
                    if (data == null)
                      Padding(
                        padding: const EdgeInsets.only(top: Sp.xs),
                        child: ShimmerLoading.block(width: 140, height: 14),
                      )
                    else if (data.$4 < 0)
                      Text(
                        'Budget ${data.$2.fixed()} · confirm its original currency using Edit.',
                        style: AppTextStyles.caption.copyWith(
                          color: palette.warning,
                        ),
                      )
                    else ...[
                      Text(
                        '${data.$3} ${data.$1.fixed()} / ${data.$2.fixed()}',
                        style: AppTextStyles.numberSmall.copyWith(
                          color: palette.textHigh,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: Motion.of(context, Motion.base),
                        style: AppTextStyles.caption.copyWith(color: tint),
                        child: Text(
                          data.$1 > data.$2
                              ? 'Over by ${(data.$1 - data.$2).fixed()}'
                              : '${(data.$2 - data.$1).fixed()} remaining · ${(ratio * 100).toStringAsFixed(0)}% used',
                        ),
                      ),
                      if (data.$4 > 0)
                        Text(
                          '${data.$4} records need exchange rates; spending is incomplete.',
                          style: AppTextStyles.caption.copyWith(
                            color: palette.warning,
                          ),
                        ),
                    ],
                    const SizedBox(height: Sp.sm),
                    Row(
                      children: [
                        _StepButton(
                          icon: Icons.chevron_left_rounded,
                          tooltip: 'Previous budget period',
                          onTap: () => _shift(-1),
                        ),
                        Expanded(
                          child: Text(
                            budget.period == 'yearly'
                                ? fmt.format(start)
                                : '${fmt.format(start)} – ${fmt.format(end)}',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              color: palette.textLow,
                            ),
                          ),
                        ),
                        _StepButton(
                          icon: Icons.chevron_right_rounded,
                          tooltip: 'Next budget period',
                          onTap: () => _shift(1),
                        ),
                        const SizedBox(width: Sp.sm),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final metadata = await ref
        .read(financeStoreProvider)
        .get('budgetCurrencies', '${budget.id}');
    if (!context.mounted) return;
    await financeForm(
      context,
      title: 'Edit budget',
      fields: [
        FinanceField(
          'currency',
          'Original budget currency',
          initial:
              metadata?['currency'] as String? ??
              ref.read<String>(defaultCurrencyProvider),
          options: {for (final c in AppConstants.currencies) c: c},
        ),
        FinanceField(
          'amount',
          'Budget amount',
          initial: '${budget.amount}',
          numeric: true,
        ),
        FinanceField(
          'date',
          'Start date',
          initial: budget.startDate.toIso8601String().substring(0, 10),
          date: true,
        ),
        FinanceField(
          'period',
          'Period',
          initial: budget.period,
          options: const {
            'weekly': 'Weekly',
            'monthly': 'Monthly',
            'yearly': 'Yearly',
          },
        ),
      ],
      save: (j) async {
        final amount = double.parse(j['amount']!);
        if (!amount.isFinite || amount <= 0) {
          throw ArgumentError('Enter a positive amount');
        }
        final store = ref.read(financeStoreProvider);
        final unit = j['currency']!;
        if (await store.get('budgetVersions', '${budget.id}:opening') == null) {
          await store.put('budgetVersions', '${budget.id}:opening', {
            'budgetId': budget.id,
            'amount': '${budget.amount}',
            'currency': unit,
            'date': budget.startDate.toIso8601String(),
          });
        }
        await store.put(
          'budgetVersions',
          '${budget.id}:${DateTime.now().microsecondsSinceEpoch}',
          {
            'budgetId': budget.id,
            'amount': '$amount',
            'currency': unit,
            'date': DateTime.now().toIso8601String(),
          },
        );
        await ref
            .read(budgetDaoProvider)
            .updateBudget(
              budget.copyWith(
                amount: amount,
                startDate: DateTime.parse(j['date']!),
                period: j['period']!,
              ),
            );
        await ref.read(financeStoreProvider).put(
          'budgetCurrencies',
          '${budget.id}',
          {'currency': j['currency']},
        );
      },
    );
  }

  Future<(Amount, Amount, String, int)> _totals(WidgetRef ref) async {
    final store = ref.read(financeStoreProvider),
        valuation = ref.read(valuationProvider);
    final metadata = await store.get('budgetCurrencies', '${budget.id}');
    if (metadata == null) {
      return (Amount.zero, Amount.fromNum(budget.amount), 'Unconfirmed', -1);
    }
    final start = rangeStart();
    final end = budget.period == 'weekly'
        ? start.add(const Duration(days: 7))
        : budget.period == 'yearly'
        ? _shiftYearClamped(start, 1)
        : _shiftMonthClamped(start, 1);
    final versions =
        (await store.list('budgetVersions'))
            .where(
              (v) =>
                  v['budgetId'] == budget.id &&
                  DateTime.parse(v['date']).isBefore(end),
            )
            .toList()
          ..sort(
            (a, b) =>
                DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])),
          );
    final originalLimit = versions.isEmpty
        ? Amount.fromNum(budget.amount)
        : Amount(versions.first['amount'].toString());
    final unit = versions.isEmpty
        ? metadata['currency'] as String
        : versions.first['currency'] as String;
    var spent = Amount.zero, missing = 0;
    for (final t in await ref.read(databaseProvider).getAllTransactions()) {
      if (t.categoryId != budget.categoryId ||
          t.type != 'expense' ||
          t.linkedTransactionId != null ||
          t.transactionDate.isBefore(start) ||
          !t.transactionDate.isBefore(end)) {
        continue;
      }
      final details = await store.transactionDetails(t.id);
      if (['asset', 'principal', 'transfer'].contains(details?['kind'])) {
        continue;
      }
      final amount = await valuation.transactionValue(t.id, unit);
      if (amount == null) {
        missing++;
      } else {
        spent += amount;
      }
    }
    if (unit == currency) return (spent, originalLimit, unit, missing);
    final converted = await valuation.convert(spent, unit, currency),
        convertedLimit = await valuation.convert(originalLimit, unit, currency);
    return converted == null || convertedLimit == null
        ? (spent, originalLimit, unit, missing)
        : (converted, convertedLimit, currency, missing);
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        haptic: false,
        scale: 0.88,
        semanticLabel: tooltip,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.mutedSurface(context),
          ),
          child: Icon(icon, size: 18, color: palette.textLow),
        ),
      ),
    );
  }
}

class AddBudgetSheet extends ConsumerStatefulWidget {
  const AddBudgetSheet({super.key});

  @override
  ConsumerState<AddBudgetSheet> createState() => AddBudgetSheetState();
}

class AddBudgetSheetState extends ConsumerState<AddBudgetSheet> {
  final _amountController = TextEditingController();
  int? _categoryId;
  String _period = 'monthly';
  bool _isSubmitting = false;
  String? _categoryError;
  String? _amountError;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final currency = ref.watch(defaultCurrencyProvider);

    return BottomSheetScaffold(
      title: 'Create Budget',
      children: [
        categoriesAsync.when(
          data: (cats) {
            final expenseCats = cats.where((c) => c.type == 'expense').toList();
            return DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: InputDecoration(
                labelText: 'Category',
                errorText: _categoryError,
              ),
              items: expenseCats
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
                  setState(() {
                    _categoryId = v;
                    _categoryError = null;
                  });
                }
              },
            );
          },
          loading: () => const SizedBox(height: 60),
          error: (error, stackTrace) => const SizedBox(height: 60),
        ),
        const SizedBox(height: Sp.md),
        TextField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: 'Budget Amount',
            prefixText: '${CurrencyFormatter.symbolFor(currency)} ',
            errorText: _amountError,
          ),
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() => _amountError = null),
        ),
        const SizedBox(height: Sp.md),
        DropdownButtonFormField<String>(
          initialValue: _period,
          decoration: const InputDecoration(labelText: 'Period'),
          items: const [
            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => _period = v);
            }
          },
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
              : const Text('Create Budget', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  void _submit() async {
    setState(() {
      _categoryError = null;
      _amountError = null;
    });

    bool hasError = false;
    if (_categoryId == null) {
      setState(() => _categoryError = 'Please select a category');
      hasError = true;
    }
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Please enter a valid amount');
      hasError = true;
    }
    if (hasError) return;

    setState(() => _isSubmitting = true);
    try {
      final dao = ref.read(budgetDaoProvider);
      final budgetId = await dao.insertBudget(
        BudgetsCompanion.insert(
          categoryId: _categoryId!,
          amount: amount!,
          period: _period,
          startDate: DateTime.now(),
        ),
      );
      await ref.read(financeStoreProvider).put(
        'budgetCurrencies',
        '$budgetId',
        {'currency': ref.read(defaultCurrencyProvider)},
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create budget: $e')));
      }
    }
  }
}

DateTime _shiftMonthClamped(DateTime value, int monthDelta) {
  final shifted = DateTime(value.year, value.month + monthDelta, 1);
  final shiftedYear = shifted.year;
  final normalizedMonth = shifted.month;
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
