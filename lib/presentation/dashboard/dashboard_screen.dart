import 'package:flourish/core/finance/transaction_classifier.dart';
import '../../core/services/preferences_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../shared/widgets/animated_list_item.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/spring_bottom_sheet.dart';
import '../../shared/widgets/stat_pill.dart';
import '../../shared/widgets/transaction_swipe_tile.dart';
import '../accounts/accounts_screen.dart' show AddAccountSheet;
import '../providers/finance_providers.dart';
import '../providers/account_providers.dart';
import '../providers/category_providers.dart';
import '../providers/transaction_providers.dart';
import '../providers/theme_providers.dart';
import '../transactions/widgets/add_transaction_sheet.dart';
import 'widgets/net_worth_hero.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // The monthly totals walk every transaction through valuation, so the
  // future is cached and only rebuilt when its inputs change.
  Future<(Amount, Amount, int)>? _monthlyFuture;
  Object? _monthlyKey;

  Future<void> _refresh() async {
    final currency = ref.read(defaultCurrencyProvider);
    final market = ref.read(marketDataProvider);
    await market.refresh(reportingCurrency: currency, force: true);
    ref.invalidate(wealthProvider);
    ref.invalidate(netWorthHistoryProvider);
    if (!mounted) return;
    if (market.warnings.isEmpty) {
      Haptics.success();
    } else {
      Haptics.warning();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(market.warnings.join('\n'))));
    }
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final loadedTx = ref.watch(transactionsProvider).valueOrNull;
    final tx = loadedTx ?? const <Transaction>[];
    final categories = {
      for (final c in ref.watch(categoriesProvider).valueOrNull ?? <Category>[])
        c.id: c,
    };
    final accounts = {
      for (final a in ref.watch(accountsProvider).valueOrNull ?? <Account>[])
        a.id: a,
    };
    final currency = ref.watch(defaultCurrencyProvider);
    // Each finance change emits a new AsyncValue; its identity marks a revision.
    final revision = identityHashCode(ref.watch(financeRevisionProvider));

    final key = (identityHashCode(loadedTx), currency, revision);
    if (_monthlyKey != key) {
      _monthlyKey = key;
      _monthlyFuture = _monthly(tx, currency);
    }

    final sections = <Widget>[
      const NetWorthHero(),
      const SizedBox(height: Sp.xl),
      _MonthSummary(future: _monthlyFuture!, currency: currency),
      const SizedBox(height: Sp.xxl),
      const _QuickActions(),
      const SizedBox(height: Sp.xxl + Sp.xs),
      _SectionHeader(
        title: 'Recent activity',
        action: tx.isEmpty ? null : 'See all',
        onAction: () => context.go('/transactions'),
      ),
      const SizedBox(height: Sp.md),
      if (tx.isEmpty)
        _GetStarted(hasAccounts: accounts.isNotEmpty)
      else
        _RecentActivity(
          transactions: tx.take(8).toList(),
          categories: categories,
          accounts: accounts,
          currency: currency,
        ),
    ];

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar.large(
            title: Text(_greeting()),
            actions: [
              IconButton(
                tooltip: 'Settings',
                onPressed: () {
                  Haptics.tap();
                  context.push('/settings');
                },
                icon: const Icon(Icons.tune_rounded),
              ),
              const SizedBox(width: Sp.sm),
            ],
          ),
          CupertinoSliverRefreshControl(onRefresh: _refresh),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Sp.screenH,
              Sp.xs,
              Sp.screenH,
              Sp.bottomNavClear + Sp.lg,
            ),
            sliver: SliverList.list(
              children: [
                // Sections enter in sequence: hero → pills → actions → list.
                for (var i = 0; i < sections.length; i++)
                  sections[i] is SizedBox
                      ? sections[i]
                      : AnimatedListItem(index: i ~/ 2, child: sections[i]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<(Amount, Amount, int)> _monthly(
    List<Transaction> transactions,
    String currency,
  ) async {
    final now = DateTime.now();
    final day = PreferencesService.getInt(
      'month_start_day',
      defaultValue: 1,
    ).clamp(1, 28);
    var start = DateTime(now.year, now.month, day);
    if (start.isAfter(now)) start = DateTime(now.year, now.month - 1, day);
    final end = DateTime(start.year, start.month + 1, day);
    var income = Amount.zero, expense = Amount.zero, missing = 0;
    final store = ref.read(financeStoreProvider),
        valuation = ref.read(valuationProvider);
    final inRange = transactions
        .where(
          (t) =>
              !t.transactionDate.isBefore(start) &&
              t.transactionDate.isBefore(end),
        )
        .toList();
    final details = await store.transactionDetailsFor(inRange.map((t) => t.id));
    final categories = {
      for (final c in await ref.read(databaseProvider).getAllCategories())
        c.id: c,
    };
    for (final t in inRange) {
      final flow = TransactionClassifier.classify(
        t,
        details[t.id],
        categories[t.categoryId],
      );
      if (!flow.isCashFlow) continue;
      final value = await valuation.transactionValue(t.id, currency);
      if (value == null) {
        missing++;
      } else if (flow == FlowClass.income) {
        income += value;
      } else if (flow == FlowClass.refund) {
        expense -= value;
      } else {
        expense += value;
      }
    }
    return (income, expense, missing);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.title.copyWith(color: palette.textHigh),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: () {
              Haptics.select();
              onAction?.call();
            },
            child: Text(action!),
          ),
      ],
    );
  }
}

/// "This month" — Income, Spending and Saved, counting up once loaded.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.future, required this.currency});

  final Future<(Amount, Amount, int)> future;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    String fmt(double v) =>
        CurrencyFormatter.formatCompact(v, currency: currency);

    return FutureBuilder<(Amount, Amount, int)>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final income = data?.$1;
        final expense = data?.$2;
        final saved = data == null ? null : data.$1 - data.$2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'THIS MONTH',
              style: AppTextStyles.eyebrow.copyWith(color: palette.textLow),
            ),
            const SizedBox(height: Sp.md),
            Row(
              children: [
                Expanded(
                  child: StatPill(
                    label: 'Income',
                    icon: Icons.south_west_rounded,
                    tone: palette.income,
                    value: income?.toDouble(),
                    format: fmt,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatPill(
                    label: 'Spending',
                    icon: Icons.north_east_rounded,
                    tone: palette.expense,
                    value: expense?.toDouble(),
                    format: fmt,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatPill(
                    label: 'Saved',
                    icon: Icons.savings_outlined,
                    tone: saved != null && saved < Amount.zero
                        ? palette.expense
                        : palette.accent,
                    value: saved?.toDouble(),
                    format: fmt,
                  ),
                ),
              ],
            ),
            if (data != null && data.$3 > 0) ...[
              const SizedBox(height: Sp.sm),
              Text(
                '${data.$3} transactions need historical exchange rates.',
                style: AppTextStyles.caption.copyWith(color: palette.warning),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _actions = [
    ('Holdings', '/wealth', Icons.diamond_outlined),
    ('Budgets', '/budgets', Icons.track_changes_rounded),
    ('Goals', '/goals', Icons.flag_outlined),
    ('Recurring', '/recurring', Icons.repeat_rounded),
    ('Import', '/smart-import', Icons.document_scanner_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Row(
      children: [
        for (final (label, route, icon) in _actions)
          Expanded(
            child: Pressable(
              semanticLabel: label,
              scale: 0.92,
              onTap: () => context.push(route),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.surface,
                      border: Border.all(color: palette.stroke),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [palette.raised, palette.surface],
                      ),
                    ),
                    child: Icon(icon, size: 22, color: palette.accent),
                  ),
                  const SizedBox(height: Sp.sm),
                  ExcludeSemantics(
                    child: Text(
                      label,
                      style: AppTextStyles.caption.copyWith(
                        color: palette.textLow,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Latest transactions grouped in one card with hairline dividers. Rows are
/// keyed by id, so a newly added transaction slides in on its own while the
/// existing rows stay put.
class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.transactions,
    required this.categories,
    required this.accounts,
    required this.currency,
  });

  final List<Transaction> transactions;
  final Map<int, Category> categories;
  final Map<int, Account> accounts;
  final String currency;

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
              KeyedSubtree(
                key: ValueKey(transactions[i].id),
                child: AnimatedListItem(
                  index: i,
                  delay: const Duration(milliseconds: 160),
                  child: Column(
                    children: [
                      if (i > 0)
                        Divider(height: 1, indent: 66, color: palette.stroke),
                      TransactionSwipeTile(
                        transaction: transactions[i],
                        category: categories[transactions[i].categoryId],
                        accountName: accounts[transactions[i].accountId]?.name,
                        currency:
                            accounts[transactions[i].accountId]?.currency ??
                            currency,
                        compact: true,
                        margin: const EdgeInsets.symmetric(horizontal: Sp.xs),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GetStarted extends StatelessWidget {
  const _GetStarted({required this.hasAccounts});

  final bool hasAccounts;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Rad.lg),
        border: Border.all(color: palette.stroke),
      ),
      child: EmptyState(
        icon: hasAccounts
            ? Icons.receipt_long_rounded
            : Icons.account_balance_wallet_outlined,
        title: hasAccounts ? 'No activity yet' : 'Let’s get you set up',
        subtitle: hasAccounts
            ? 'Add your first transaction and it will show up here.'
            : 'Add an account and your first transaction to get started.',
        action: FilledButton.icon(
          onPressed: () => showSpringBottomSheet(
            context: context,
            builder: (_) => hasAccounts
                ? const AddTransactionSheet()
                : const AddAccountSheet(),
          ),
          icon: const Icon(Icons.add_rounded),
          label: Text(hasAccounts ? 'Add transaction' : 'Add an account'),
        ),
      ),
    );
  }
}
