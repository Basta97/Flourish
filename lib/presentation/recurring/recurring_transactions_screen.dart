import 'package:flourish/shared/category_label.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/core/utils/amount_parser.dart';
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
import 'package:flourish/presentation/providers/finance_providers.dart';
import 'package:flourish/core/finance/recurring_service.dart';
import 'package:flourish/core/finance/system_categories.dart';
import 'package:flourish/core/utils/error_text.dart';
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
        label: Text(context.l10n.recurringPayment),
      ),
      appBar: AppBar(title: Text(context.l10n.recurringTransactions)),
      body: LiquidPageBackground(
        child: recurringAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.repeat,
                title: context.l10n.noRecurring,
                subtitle: context.l10n.setUpAutomatic,
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
              EmptyState(icon: Icons.error, title: context.l10n.errorLoading),
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
    final currency =
        ref
            .watch(accountByIdProvider(recurring.accountId))
            .valueOrNull
            ?.currency ??
        '';
    final warning = ref
        .watch(recurringWarningsProvider)
        .valueOrNull?[recurring.id];
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
          padding: const EdgeInsetsDirectional.fromSTEB(
            Sp.lg,
            Sp.md,
            Sp.xs,
            Sp.md,
          ),
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
                            cat?.displayName ?? _frequencyLabel(recurring.frequency),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: palette.textHigh,
                            ),
                          ),
                        ),
                        if (!recurring.isActive) ...[
                          const SizedBox(width: 6),
                          _Tag(context.l10n.pausedCaps, palette.warning),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.l10n.frequencyNext(
                        _frequencyLabel(recurring.frequency),
                        DateFormatter.format(recurring.nextDate),
                      ),
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
                    if (warning != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          context.l10n.notPosted(warning),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : '−'}${CurrencyFormatter.format(recurring.amount, currency: currency)}',
                textDirection: TextDirection.ltr,
                style: AppTextStyles.numberSmall.copyWith(color: tone),
              ),
              PopupMenuButton<String>(
                tooltip: context.l10n.recurringOptions,
                icon: Icon(Icons.more_vert_rounded, color: palette.textLow),
                onSelected: (action) async {
                  Haptics.select();
                  final service = ref.read(recurringServiceProvider);
                  if (action == 'edit') {
                    await showSpringBottomSheet(
                      context: context,
                      builder: (_) => _AddRecurringSheet(existing: recurring),
                    );
                  } else if (action == 'toggle') {
                    await service.setActive(recurring, !recurring.isActive);
                  } else if (action == 'delete') {
                    await service.delete(recurring.id);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      recurring.isActive
                          ? context.l10n.pause
                          : context.l10n.resume,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      context.l10n.delete,
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
        return currentL10n.daily;
      case 'weekly':
        return currentL10n.weekly;
      case 'monthly':
        return currentL10n.monthly;
      case 'yearly':
        return currentL10n.yearly;
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
  const _AddRecurringSheet({this.existing});

  final RecurringTransaction? existing;

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
  int? _toAccountId;
  int? _instrumentId;
  DateTime? _endDate;
  DateTime _nextDate = DateTime.now().add(const Duration(days: 1));
  bool _isSubmitting = false;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    if (r != null) {
      _amountController.text = '${r.amount}';
      _noteController.text = r.note ?? '';
      _type = r.type;
      _frequency = r.frequency;
      _accountId = r.accountId;
      _categoryId = r.categoryId;
      _nextDate = r.nextDate;
      _toAccountId = r.toAccountId;
      _instrumentId = r.paymentInstrumentId;
      _endDate = r.endDate;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(pickableCategoriesProvider);
    final currency =
        accountsAsync.valueOrNull
            ?.where((a) => a.id == _accountId)
            .firstOrNull
            ?.currency ??
        '';

    return BottomSheetScaffold(
      title: widget.existing == null
          ? context.l10n.newRecurring
          : context.l10n.editRecurring,
      children: [
        Row(
          children: [
            Expanded(
              child: _TypeBtn(
                label: context.l10n.expense,
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
                label: context.l10n.income,
                selected: _type == 'income',
                color: AppColors.income,
                onTap: () => setState(() {
                  _type = 'income';
                  _categoryId = null;
                }),
              ),
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: _TypeBtn(
                label: context.l10n.transfer,
                selected: _type == 'transfer',
                color: AppColors.primary,
                onTap: () => setState(() {
                  _type = 'transfer';
                  _categoryId = null;
                  _instrumentId = null;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: Sp.lg),
        TextField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: context.l10n.amount,
            prefixText: '${CurrencyFormatter.symbolFor(currency)} ',
            hintText: '0.00',
            errorText: _amountError,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [AmountInputFormatter()],
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
              decoration: InputDecoration(labelText: context.l10n.account),
              items: accounts
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name} (${a.currency})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _accountId = v;
                    _instrumentId = null;
                    if (_toAccountId == v) _toAccountId = null;
                  });
                }
              },
            );
          },
          loading: () => const SizedBox(height: 60),
          error: (error, stackTrace) => const SizedBox(height: 60),
        ),
        if (_type == 'transfer') ...[
          const SizedBox(height: Sp.md),
          DropdownButtonFormField<int>(
            key: ValueKey('recurring-to-$_accountId-$_toAccountId'),
            initialValue: _toAccountId,
            decoration: InputDecoration(labelText: context.l10n.toAccountHint),
            items: [
              for (final a in accountsAsync.valueOrNull ?? const <Account>[])
                if (a.id != _accountId)
                  DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.name} (${a.currency})'),
                  ),
            ],
            onChanged: (v) => setState(() => _toAccountId = v),
          ),
        ],
        if (_type == 'expense')
          if ((ref.watch(paymentInstrumentsProvider).valueOrNull ?? [])
                  .where((i) => i.accountId == _accountId && !i.archived)
                  .toList()
              case final cards when cards.isNotEmpty) ...[
            const SizedBox(height: Sp.md),
            DropdownButtonFormField<int?>(
              key: ValueKey('recurring-card-$_accountId-$_instrumentId'),
              initialValue: _instrumentId,
              decoration: InputDecoration(labelText: context.l10n.chargedTo),
              items: [
                DropdownMenuItem(value: null, child: Text(context.l10n.notSet)),
                for (final c in cards)
                  DropdownMenuItem(value: c.id, child: Text(c.label)),
              ],
              onChanged: (v) => setState(() => _instrumentId = v),
            ),
          ],
        const SizedBox(height: Sp.md),
        if (_type != 'transfer')
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
                  _categoryId != null &&
                      filtered.any((c) => c.id == _categoryId)
                  ? _categoryId
                  : (filtered.isNotEmpty ? filtered.first.id : null);
              return DropdownButtonFormField<int>(
                key: ValueKey('recurring-category-$_type-$effectiveCat'),
                initialValue: effectiveCat,
                decoration: InputDecoration(labelText: context.l10n.category),
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
                            Text(c.displayName),
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
          decoration: InputDecoration(labelText: context.l10n.frequency),
          items: [
            DropdownMenuItem(value: 'daily', child: Text(context.l10n.daily)),
            DropdownMenuItem(value: 'weekly', child: Text(context.l10n.weekly)),
            DropdownMenuItem(
              value: 'monthly',
              child: Text(context.l10n.monthly),
            ),
            DropdownMenuItem(value: 'yearly', child: Text(context.l10n.yearly)),
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
              firstDate: DateTime(DateTime.now().year - 5),
              lastDate: DateTime(2035),
            );
            if (picked != null) setState(() => _nextDate = picked);
          },
          borderRadius: BorderRadius.circular(Rad.md),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.existing == null
                  ? context.l10n.firstOccurrence
                  : context.l10n.nextOccurrence,
            ),
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
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _endDate ?? _nextDate,
              firstDate: _nextDate,
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => _endDate = picked);
          },
          borderRadius: BorderRadius.circular(Rad.md),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: context.l10n.endsOptional,
              suffixIcon: _endDate == null
                  ? null
                  : IconButton(
                      tooltip: context.l10n.noEndDate,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _endDate = null),
                    ),
            ),
            child: Text(
              _endDate == null
                  ? context.l10n.never
                  : DateFormatter.formatFull(_endDate!),
            ),
          ),
        ),
        const SizedBox(height: Sp.md),
        TextField(
          controller: _noteController,
          decoration: InputDecoration(labelText: context.l10n.noteOptional),
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
              : Text(
                  widget.existing == null
                      ? context.l10n.createRecurring
                      : context.l10n.save,
                  style: const TextStyle(fontSize: 16),
                ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final currency =
        ref
            .read(accountsProvider)
            .valueOrNull
            ?.where((a) => a.id == _accountId)
            .firstOrNull
            ?.currency ??
        '';
    final parsed = AmountParser.parse(
      _amountController.text,
      currency: currency,
    );
    if (!parsed.isValid) {
      setState(() => _amountError = parsed.error);
      return;
    }
    final amount = parsed.value!.toDouble();
    if (_type == 'transfer') {
      if (_toAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chooseTransferTarget)),
        );
        return;
      }
      _categoryId = await SystemCategories.idFor(
        ref.read(databaseProvider),
        'transfer_out',
      );
      if (!mounted) return;
    }
    if (_accountId == null || _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.selectAccountCategory)),
      );
      return;
    }
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final service = ref.read(recurringServiceProvider);
    final existing = widget.existing;
    var catchUp = false;
    if (existing == null) {
      final today = DateTime.now();
      final missed = RecurringService.occurrences(
        _nextDate,
        _frequency,
        today,
        limit: 25,
      ).length;
      if (missed > 0) {
        final choice = await _askCatchUp(missed);
        if (choice == null) return;
        catchUp = choice;
      }
    }
    setState(() => _isSubmitting = true);
    try {
      if (existing == null) {
        await service.create(
          RecurringTransactionsCompanion.insert(
            accountId: _accountId!,
            categoryId: _categoryId!,
            amount: amount,
            type: _type,
            frequency: _frequency,
            nextDate: _nextDate,
            note: Value(note),
            toAccountId: Value(_type == 'transfer' ? _toAccountId : null),
            paymentInstrumentId: Value(
              _type == 'expense' ? _instrumentId : null,
            ),
            endDate: Value(_endDate),
          ),
          catchUp: catchUp,
        );
      } else {
        await service.update(
          existing.copyWith(
            accountId: _accountId,
            categoryId: _categoryId,
            amount: amount,
            type: _type,
            frequency: _frequency,
            nextDate: _nextDate,
            note: Value(note),
            toAccountId: Value(_type == 'transfer' ? _toAccountId : null),
            paymentInstrumentId: Value(
              _type == 'expense' ? _instrumentId : null,
            ),
            endDate: Value(_endDate),
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }

  /// Asks whether occurrences before today should be posted now. Returns
  /// null when the user cancels.
  Future<bool?> _askCatchUp(int missed) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.l10n.startInPast),
      content: Text(
        missed > 24 ? ctx.l10n.tooManyMissed : ctx.l10n.missedPayments(missed),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(context.l10n.startFromNext),
        ),
        if (missed <= 24)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.postCount(missed)),
          ),
      ],
    ),
  );
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
