import 'package:flourish/shared/category_label.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../shared/widgets/animated_list_item.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/segmented_pill.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/transaction_swipe_tile.dart';
import '../providers/account_providers.dart';
import '../providers/category_providers.dart';
import '../providers/transaction_providers.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  static const _types = ['all', 'income', 'expense', 'transfer'];

  String type = 'all', view = 'list';
  int? account, category;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? selectedDay;
  DateTimeRange? range;

  /// +1 when moving forward in time, -1 backward; drives the slide direction.
  int _direction = 0;

  void _shiftMonth(int delta) {
    Haptics.select();
    setState(() {
      _direction = delta;
      month = DateTime(month.year, month.month + delta);
      range = null;
      selectedDay = null;
    });
  }

  Future<void> _pickRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2126),
      initialDateRange: range,
    );
    if (selected != null) {
      setState(() {
        range = selected;
        selectedDay = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider),
        accounts = ref.watch(accountsProvider).valueOrNull ?? <Account>[],
        categories = ref.watch(categoriesProvider).valueOrNull ?? <Category>[];
    final accountMap = {for (final a in accounts) a.id: a},
        categoryMap = {for (final c in categories) c.id: c};
    final palette = FlourishPalette.of(context);

    final periodLabel = range != null
        ? '${DateFormat('MMM d').format(range!.start)} – ${DateFormat('MMM d, y').format(range!.end)}'
        : DateFormat('MMMM y').format(month);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            pinned: true,

            title: Text(context.l10n.navLedger),
            actions: [
              IconButton(
                tooltip: context.l10n.search,
                onPressed: () {
                  Haptics.tap();
                  context.push('/search');
                },
                icon: const Icon(Icons.search_rounded),
              ),
              IconButton(
                tooltip: view == 'calendar'
                    ? context.l10n.listView
                    : context.l10n.calendarView,
                isSelected: view == 'calendar',
                onPressed: () {
                  Haptics.select();
                  setState(() => view = view == 'list' ? 'calendar' : 'list');
                },
                icon: const Icon(Icons.calendar_month),
                selectedIcon: Icon(Icons.calendar_month, color: palette.accent),
              ),
              const SizedBox(width: Sp.xs),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.screenH),
            sliver: SliverList.list(
              children: [
                _PeriodSwitcher(
                  label: periodLabel,
                  direction: _direction,
                  onPrevious: () => _shiftMonth(-1),
                  onNext: () => _shiftMonth(1),
                  onPickRange: _pickRange,
                  onClearRange: range == null
                      ? null
                      : () => setState(() => range = null),
                ),
                const SizedBox(height: Sp.md),
                SegmentedPill(
                  labels: [
                    context.l10n.all,
                    context.l10n.income,
                    context.l10n.expense,
                    context.l10n.transfers,
                  ],
                  selectedIndex: _types.indexOf(type),
                  activeColor: switch (type) {
                    'income' => palette.income,
                    'expense' => palette.expense,
                    _ => null,
                  },
                  onChanged: (i) => setState(() => type = _types[i]),
                ),
                const SizedBox(height: Sp.md),
                Row(
                  children: [
                    Expanded(
                      child: _FilterMenu<int>(
                        icon: Icons.account_balance_wallet_outlined,
                        label:
                            accountMap[account]?.name ??
                            context.l10n.allAccounts,
                        active: accountMap.containsKey(account),
                        options: {
                          null: context.l10n.allAccounts,
                          for (final a in accounts) a.id: a.name,
                        },
                        onSelected: (v) => setState(() => account = v),
                      ),
                    ),
                    const SizedBox(width: Sp.sm),
                    Expanded(
                      child: _FilterMenu<int>(
                        icon: Icons.category_outlined,
                        label:
                            categoryMap[category]?.name ??
                            context.l10n.allCategories,
                        active: categoryMap.containsKey(category),
                        options: {
                          null: context.l10n.allCategories,
                          for (final c in categories) c.id: c.displayName,
                        },
                        onSelected: (v) => setState(() => category = v),
                      ),
                    ),
                  ],
                ),
                // AnimatedSize asserts with a zero duration, so under
                // reduce-motion it gets the shortest non-zero one instead.
                AnimatedSize(
                  duration: Motion.reduced(context)
                      ? const Duration(milliseconds: 1)
                      : Motion.base,
                  curve: Motion.morph,
                  alignment: Alignment.topCenter,
                  child: view == 'calendar' && range == null
                      ? Padding(
                          padding: const EdgeInsets.only(top: Sp.md),
                          child: Container(
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(Rad.lg),
                              border: Border.all(color: palette.stroke),
                            ),
                            child: SizedBox(
                              height: 320,
                              child: CalendarDatePicker(
                                key: ValueKey(month),
                                initialDate: selectedDay ?? month,
                                firstDate: DateTime(1900),
                                lastDate: DateTime(2126),
                                onDateChanged: (date) {
                                  Haptics.select();
                                  setState(() => selectedDay = date);
                                },
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                if (selectedDay != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => setState(() => selectedDay = null),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text(
                        context.l10n.showingDay(
                          DateFormat('MMM d').format(selectedDay!),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: Sp.sm),
              ],
            ),
          ),
          ...transactions.when(
            data: (rows) => _daySlivers(context, rows, accountMap, categoryMap),
            loading: () => [
              SliverPadding(
                padding: const EdgeInsets.all(Sp.screenH),
                sliver: SliverList.list(
                  children: [
                    for (var i = 0; i < 5; i++) ShimmerLoading.listItem(),
                  ],
                ),
              ),
            ],
            error: (e, _) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: context.l10n.couldNotLoadTransactions,
                  subtitle: '$e',
                ),
              ),
            ],
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: Sp.bottomNavClear + Sp.lg),
          ),
        ],
      ),
    );
  }

  List<Widget> _daySlivers(
    BuildContext context,
    List<Transaction> rows,
    Map<int, Account> accountMap,
    Map<int, Category> categoryMap,
  ) {
    final start = range?.start ?? selectedDay ?? month;
    final end = range != null
        ? range!.end.add(const Duration(days: 1))
        : selectedDay != null
        ? selectedDay!.add(const Duration(days: 1))
        : DateTime(month.year, month.month + 1);
    final filtered = rows
        .where(
          (t) =>
              !t.transactionDate.isBefore(start) &&
              t.transactionDate.isBefore(end) &&
              (type == 'all' ||
                  (type == 'transfer'
                      ? t.linkedTransactionId != null
                      : t.type == type && t.linkedTransactionId == null)) &&
              (account == null || t.accountId == account) &&
              (category == null || t.categoryId == category),
        )
        .toList();

    if (filtered.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            key: ValueKey('empty-$month-$type-$account-$category'),
            icon: Icons.receipt_long_rounded,
            title: context.l10n.nothingHereYet,
            subtitle: context.l10n.noTransactionsPeriod,
          ),
        ),
      ];
    }

    // Per-day net totals, per currency, excluding transfer legs.
    final daily = <String, Map<String, double>>{};
    for (final t in filtered.where((t) => t.linkedTransactionId == null)) {
      final day = t.transactionDate.toIso8601String().substring(0, 10);
      final currency = accountMap[t.accountId]?.currency ?? '???';
      final totals = daily.putIfAbsent(day, () => {});
      totals[currency] =
          (totals[currency] ?? 0) + (t.type == 'income' ? t.amount : -t.amount);
    }
    final grouped = <String, List<Transaction>>{};
    for (final t in filtered) {
      grouped
          .putIfAbsent(
            t.transactionDate.toIso8601String().substring(0, 10),
            () => [],
          )
          .add(t);
    }

    var groupIndex = 0;
    return [
      for (final entry in grouped.entries)
        SliverMainAxisGroup(
          key: ValueKey('day-${entry.key}'),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _DayHeaderDelegate(
                day: DateTime.parse(entry.key),
                totals: daily[entry.key] ?? const {},
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Sp.screenH,
                0,
                Sp.screenH,
                Sp.md,
              ),
              sliver: SliverToBoxAdapter(
                child: AnimatedListItem(
                  index: groupIndex++,
                  child: _DayCard(
                    transactions: entry.value,
                    accountMap: accountMap,
                    categoryMap: categoryMap,
                  ),
                ),
              ),
            ),
          ],
        ),
    ];
  }
}

/// ‹ October 2026 › — the label slides in the direction of travel.
class _PeriodSwitcher extends StatelessWidget {
  const _PeriodSwitcher({
    required this.label,
    required this.direction,
    required this.onPrevious,
    required this.onNext,
    required this.onPickRange,
    this.onClearRange,
  });

  final String label;
  final int direction;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Tapping the label opens a custom date-range picker.
  final VoidCallback onPickRange;
  final VoidCallback? onClearRange;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Row(
      children: [
        _RoundButton(
          icon: Icons.chevron_left_rounded,
          tooltip: context.l10n.previousMonth,
          onTap: onPrevious,
        ),
        Expanded(
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.base),
              switchInCurve: Motion.enter,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final incoming = child.key == ValueKey(label);
                final dx = (incoming ? 0.35 : -0.35) * direction;
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(dx, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Row(
                key: ValueKey(label),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Pressable(
                      onTap: onPickRange,
                      scale: 0.96,
                      semanticLabel: context.l10n.chooseDateRange,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              style: AppTextStyles.title.copyWith(
                                color: palette.textHigh,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 20,
                            color: palette.textLow,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onClearRange != null)
                    IconButton(
                      tooltip: context.l10n.clearRange,
                      visualDensity: VisualDensity.compact,
                      onPressed: onClearRange,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                ],
              ),
            ),
          ),
        ),
        _RoundButton(
          icon: Icons.chevron_right_rounded,
          tooltip: context.l10n.nextMonth,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
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
        scale: 0.9,
        semanticLabel: tooltip,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.surface,
            border: Border.all(color: palette.stroke),
          ),
          child: Icon(icon, color: palette.textHigh),
        ),
      ),
    );
  }
}

/// A pill that opens a menu of options; tinted when a filter is active.
class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    required this.icon,
    required this.label,
    required this.active,
    required this.options,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Map<T?, String> options;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    final tint = active ? palette.accent : palette.textLow;
    return MenuAnchor(
      style: const MenuStyle(
        maximumSize: WidgetStatePropertyAll(Size(280, 360)),
      ),
      menuChildren: [
        for (final option in options.entries)
          MenuItemButton(
            onPressed: () {
              Haptics.select();
              onSelected(option.key);
            },
            child: Text(option.value),
          ),
      ],
      builder: (context, controller, _) => Pressable(
        haptic: false,
        scale: 0.97,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.base),
          curve: Motion.morph,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: Sp.md),
          decoration: BoxDecoration(
            color: active ? palette.accentSoft : palette.surface,
            borderRadius: BorderRadius.circular(Rad.full),
            border: Border.all(
              color: active
                  ? palette.accent.withValues(alpha: 0.4)
                  : palette.stroke,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: active ? palette.accent : palette.textHigh,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.expand_more_rounded, size: 16, color: tint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sticky "Today · +EGP 1,200.00" header for one day's group.
class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DayHeaderDelegate({required this.day, required this.totals});

  final DateTime day;
  final Map<String, double> totals;

  static const double _extent = 40;

  @override
  double get minExtent => _extent;
  @override
  double get maxExtent => _extent;

  static String _label(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(day.year, day.month, day.day));
    if (diff.inDays == 0) return currentL10n.today;
    if (diff.inDays == 1) return currentL10n.yesterday;
    return DateFormat(
      day.year == now.year ? 'EEE d MMM' : 'EEE d MMM y',
    ).format(day);
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final palette = FlourishPalette.of(context);
    final net = totals.entries
        .map(
          (e) =>
              '${e.value > 0
                  ? '+'
                  : e.value < 0
                  ? '−'
                  : ''}${CurrencyFormatter.format(e.value.abs(), currency: e.key)}',
        )
        .join(' · ');
    final positive = totals.values.every((v) => v >= 0);
    return Container(
      color: palette.background,
      padding: const EdgeInsets.symmetric(horizontal: Sp.screenH + Sp.xs),
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        children: [
          Text(
            _label(day).toUpperCase(),
            style: AppTextStyles.eyebrow.copyWith(color: palette.textLow),
          ),
          const SizedBox(width: Sp.md),
          if (net.isNotEmpty)
            Expanded(
              child: Text(
                net,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.numberSmall.copyWith(
                  fontSize: 12,
                  color: positive ? palette.income : palette.textLow,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_DayHeaderDelegate oldDelegate) =>
      oldDelegate.day != day || oldDelegate.totals != totals;
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.transactions,
    required this.accountMap,
    required this.categoryMap,
  });

  final List<Transaction> transactions;
  final Map<int, Account> accountMap;
  final Map<int, Category> categoryMap;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Rad.lg),
        border: Border.all(color: palette.stroke),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Rad.lg),
        child: Column(
          children: [
            for (var i = 0; i < transactions.length; i++)
              Column(
                key: ValueKey(transactions[i].id),
                children: [
                  if (i > 0)
                    Divider(height: 1, indent: 66, color: palette.stroke),
                  TransactionSwipeTile(
                    transaction: transactions[i],
                    category: categoryMap[transactions[i].categoryId],
                    accountName: accountMap[transactions[i].accountId]?.name,
                    currency:
                        accountMap[transactions[i].accountId]?.currency ??
                        'EGP',
                    compact: true,
                    showTime: true,
                    margin: const EdgeInsets.symmetric(horizontal: Sp.xs),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
