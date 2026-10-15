import 'package:flourish/presentation/providers/finance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/core/utils/date_formatter.dart';
import 'package:flourish/core/utils/error_text.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/providers/account_providers.dart';
import 'package:flourish/presentation/providers/transaction_providers.dart';
import 'package:flourish/presentation/transactions/widgets/edit_transaction_sheet.dart';
import 'package:flourish/shared/widgets/bottom_sheet_scaffold.dart';
import 'package:flourish/shared/widgets/category_icon_widget.dart';
import 'package:flourish/shared/widgets/pressable.dart';
import 'package:flourish/shared/widgets/spring_bottom_sheet.dart';

/// A ledger row: tinted category squircle, title + meta, and a tabular amount.
///
/// Swiping left reveals Edit/Delete with a stretch motion and a haptic tick
/// as the actions open. Deleting collapses the row away before the record is
/// removed, so the list closes the gap smoothly instead of jumping.
class TransactionSwipeTile extends ConsumerStatefulWidget {
  const TransactionSwipeTile({
    super.key,
    required this.transaction,
    required this.currency,
    this.category,
    this.accountName,
    this.compact = false,
    this.showTime = false,
    this.margin,
  });

  final Transaction transaction;
  final Category? category;
  final String currency;
  final String? accountName;
  final bool compact;

  /// Show the time of day instead of a relative date, for lists that are
  /// already grouped by day.
  final bool showTime;
  final EdgeInsetsGeometry? margin;

  @override
  ConsumerState<TransactionSwipeTile> createState() =>
      _TransactionSwipeTileState();
}

class _TransactionSwipeTileState extends ConsumerState<TransactionSwipeTile>
    with TickerProviderStateMixin {
  late final SlidableController _slidable = SlidableController(this);
  late final AnimationController _collapse = AnimationController(
    vsync: this,
    duration: Motion.base,
    value: 1,
  );
  bool _openedTick = false;

  @override
  void initState() {
    super.initState();
    _slidable.animation.addListener(_onSlide);
  }

  @override
  void dispose() {
    _slidable.animation.removeListener(_onSlide);
    _slidable.dispose();
    _collapse.dispose();
    super.dispose();
  }

  /// One haptic tick when the swipe crosses the open threshold.
  void _onSlide() {
    final value = _slidable.animation.value;
    if (!_openedTick && value > 0.2) {
      _openedTick = true;
      Haptics.select();
    } else if (_openedTick && value < 0.05) {
      _openedTick = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final palette = FlourishPalette.of(context);
    final isIncome = t.type == 'income';
    final isTransfer = t.linkedTransactionId != null;
    final tone = isIncome ? palette.income : palette.textHigh;
    final meta = [
      if ((widget.accountName ?? '').trim().isNotEmpty) widget.accountName!,
      if ((t.note ?? '').trim().isNotEmpty) t.note!.trim(),
    ].join(' · ');

    final row = Pressable(
      onTap: _openEdit,
      scale: 0.985,
      haptic: false,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: widget.compact ? 12 : 14,
          horizontal: widget.compact ? Sp.md : Sp.lg,
        ),
        child: Row(
          children: [
            CategoryIconWidget(
              iconName: widget.category?.icon ?? 'more_horiz',
              color: Color(widget.category?.color ?? AppColors.fallbackColor),
              size: widget.compact ? 42 : 46,
              iconSize: widget.compact ? 19 : 21,
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.category?.name ??
                        (isTransfer
                            ? 'Transfer'
                            : isIncome
                            ? 'Income'
                            : 'Expense'),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: palette.textHigh,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      style: AppTextStyles.caption.copyWith(
                        color: palette.textLow,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: widget.compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Sp.sm),
            // Capped so a huge amount (or large text) shrinks to fit rather
            // than overflowing; figures are scaled, never truncated.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${isIncome ? '+' : '−'}${_amount(t.amount)}',
                      style: AppTextStyles.numberSmall.copyWith(
                        fontSize: 14,
                        color: tone,
                      ),
                    ),
                  ),
                  const SizedBox(height: Sp.xs),
                  Text(
                    widget.showTime
                        ? DateFormat.Hm().format(t.transactionDate)
                        : DateFormatter.format(t.transactionDate),
                    style: AppTextStyles.caption.copyWith(
                      color: palette.textLow,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: _collapse, curve: Motion.morph),
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _collapse,
        child: Padding(
          padding:
              widget.margin ??
              const EdgeInsets.symmetric(
                horizontal: Sp.screenH,
                vertical: Sp.xs,
              ),
          child: Slidable(
            key: ValueKey('transaction-${t.id}'),
            controller: _slidable,
            endActionPane: ActionPane(
              motion: const StretchMotion(),
              extentRatio: widget.compact ? 0.42 : 0.38,
              openThreshold: 0.2,
              closeThreshold: 0.1,
              children: [
                CustomSlidableAction(
                  onPressed: (_) => _openEdit(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sp.xs,
                    vertical: Sp.sm,
                  ),
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.transparent,
                  child: _SwipeAction(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    tint: palette.accent,
                  ),
                ),
                CustomSlidableAction(
                  onPressed: (_) => _confirmDelete(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sp.xs,
                    vertical: Sp.sm,
                  ),
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.transparent,
                  child: const _SwipeAction(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    tint: AppColors.danger,
                  ),
                ),
              ],
            ),
            child: row,
          ),
        ),
      ),
    );
  }

  String _amount(double value) => value.abs() >= 100000
      ? CurrencyFormatter.formatCompact(value, currency: widget.currency)
      : CurrencyFormatter.format(value, currency: widget.currency);

  void _openEdit() {
    Haptics.tap();
    showSpringBottomSheet(
      context: context,
      builder: (_) => EditTransactionSheet(transaction: widget.transaction),
    );
  }

  void _confirmDelete() {
    Haptics.warning();
    final palette = FlourishPalette.of(context);
    showSpringBottomSheet(
      context: context,
      builder: (sheetContext) => BottomSheetScaffold(
        title: 'Delete transaction?',
        children: [
          Text(
            'This removes the transaction and rebalances the linked account automatically.',
            style: AppTextStyles.body.copyWith(color: palette.textLow),
          ),
          const SizedBox(height: Sp.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Keep'),
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _delete();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final ledger = ref.read(financialLedgerProvider);
    final id = widget.transaction.id;

    // Collapse first so the row folds away, then remove the record.
    if (!Motion.reduced(context)) await _collapse.reverse();
    try {
      final deleted = await ledger.deleteWithUndo(id);
      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Transaction deleted'),
          action: deleted == null
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    try {
                      await ledger.restore(deleted);
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(describeError(e))),
                      );
                    }
                    ref.invalidate(transactionsProvider);
                    ref.invalidate(accountsProvider);
                  },
                ),
        ),
      );
    } catch (e) {
      if (mounted) _collapse.forward();
      messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.label,
    required this.icon,
    required this.tint,
  });

  final String label;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: tint),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: tint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
