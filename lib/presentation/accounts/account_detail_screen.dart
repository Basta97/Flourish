import '../wealth/finance_tools_view.dart';
import 'package:flutter/material.dart';
import 'package:flourish/core/utils/error_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/providers/account_providers.dart';
import 'package:flourish/presentation/providers/transaction_providers.dart';
import 'package:flourish/presentation/providers/category_providers.dart';
import 'package:flourish/shared/widgets/empty_state.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/shared/widgets/animated_list_item.dart';
import 'package:flourish/shared/widgets/shimmer_loading.dart';
import 'package:flourish/shared/widgets/stat_pill.dart';
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/presentation/accounts/widgets/account_card.dart';
import 'package:flourish/shared/widgets/transaction_swipe_tile.dart';
import 'package:flourish/shared/widgets/spring_bottom_sheet.dart';
import 'package:flourish/presentation/transactions/widgets/add_transaction_sheet.dart';

class AccountDetailScreen extends ConsumerWidget {
  final int accountId;
  const AccountDetailScreen({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountByIdProvider(accountId));
    final transactionsAsync = ref.watch(
      transactionsByAccountProvider(accountId),
    );

    final palette = FlourishPalette.of(context);
    final account = accountAsync.valueOrNull;

    return Scaffold(
      body: accountAsync.when(
        data: (account) {
          if (account == null) {
            return const EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Account not found',
            );
          }
          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                pinned: true,
                title: Text(account.name),
                actions: [
                  IconButton(
                    tooltip: 'Manage account',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => editAccount(context, ref, account),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: 'Delete account',
                    onPressed: () => _confirmDelete(context, ref, account),
                  ),
                  const SizedBox(width: Sp.xs),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Sp.screenH,
                  Sp.sm,
                  Sp.screenH,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Hero(
                    tag: accountHeroTag(account.id),
                    child: AccountCard(account: account, large: true),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Sp.screenH,
                  Sp.xl,
                  Sp.screenH,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: AnimatedBody(
                    delay: const Duration(milliseconds: 180),
                    child: _MonthFlow(
                      account: account,
                      transactions: transactionsAsync.valueOrNull,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Sp.screenH,
                  Sp.xxl,
                  Sp.screenH - Sp.sm,
                  Sp.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Transactions',
                          style: AppTextStyles.title.copyWith(
                            color: palette.textHigh,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _addTransaction(context, ref, account),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                ),
              ),
              transactionsAsync.when(
                data: (transactions) => _TransactionList(
                  transactions: transactions,
                  account: account,
                ),
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.screenH),
                  sliver: SliverList.list(
                    children: [
                      for (var i = 0; i < 4; i++) ShimmerLoading.listItem(),
                    ],
                  ),
                ),
                error: (error, stackTrace) => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Error loading transactions',
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Error loading account',
        ),
      ),
      floatingActionButton: account != null
          ? FloatingActionButton.extended(
              onPressed: () => _addTransaction(context, ref, account),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Transaction'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Rad.full),
              ),
            )
          : null,
    );
  }

  void _addTransaction(BuildContext context, WidgetRef ref, Account account) {
    showSpringBottomSheet(
      context: context,
      builder: (ctx) => AddTransactionSheet(initialAccountId: account.id),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Account account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text(
          'Delete "${account.name}"? Accounts with transactions must be '
          'archived instead, so their history stays in your reports.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final db = ref.read(accountDaoProvider);
              try {
                await db.deleteAccount(account.id);
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(describeError(e))));
                }
                return;
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) context.pop();
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

/// This month's money in and out of the account, in its own currency.
class _MonthFlow extends StatelessWidget {
  const _MonthFlow({required this.account, required this.transactions});

  final Account account;
  final List<Transaction>? transactions;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    double? income, expense;
    if (transactions != null) {
      income = 0;
      expense = 0;
      for (final t in transactions!) {
        if (t.transactionDate.isBefore(start)) continue;
        if (t.type == 'income') {
          income = income! + t.amount;
        } else if (t.type == 'expense') {
          expense = expense! + t.amount;
        }
      }
    }
    String fmt(double v) =>
        CurrencyFormatter.formatCompact(v, currency: account.currency);
    return Row(
      children: [
        Expanded(
          child: StatPill(
            label: 'In this month',
            icon: Icons.south_west_rounded,
            tone: palette.income,
            value: income,
            format: fmt,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatPill(
            label: 'Out this month',
            icon: Icons.north_east_rounded,
            tone: palette.expense,
            value: expense,
            format: fmt,
          ),
        ),
      ],
    );
  }
}

/// The account's transactions as one grouped card: each row is its own sliver
/// item (so long histories stay lazy) with the ends rounded off.
class _TransactionList extends ConsumerWidget {
  final List<Transaction> transactions;
  final Account account;

  const _TransactionList({required this.transactions, required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactions.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'No transactions',
          subtitle: 'Add a transaction to get started.',
        ),
      );
    }

    final palette = FlourishPalette.of(context);
    final catMap = {
      for (final c in ref.watch(categoriesProvider).valueOrNull ?? <Category>[])
        c.id: c,
    };
    final last = transactions.length - 1;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.screenH),
      sliver: SliverList.builder(
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final t = transactions[index];
          final radius = BorderRadius.vertical(
            top: index == 0 ? const Radius.circular(Rad.lg) : Radius.zero,
            bottom: index == last ? const Radius.circular(Rad.lg) : Radius.zero,
          );
          final row = Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: radius,
              border: Border(
                left: BorderSide(color: palette.stroke),
                right: BorderSide(color: palette.stroke),
                top: index == 0
                    ? BorderSide(color: palette.stroke)
                    : BorderSide.none,
                bottom: index == last
                    ? BorderSide(color: palette.stroke)
                    : BorderSide.none,
              ),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Column(
                children: [
                  if (index > 0)
                    Divider(height: 1, indent: 66, color: palette.stroke),
                  TransactionSwipeTile(
                    transaction: t,
                    category: catMap[t.categoryId],
                    currency: account.currency,
                    compact: true,
                    margin: const EdgeInsets.symmetric(horizontal: Sp.xs),
                  ),
                ],
              ),
            ),
          );
          // Only the first screenful staggers in; rows reached by scrolling
          // appear immediately.
          return index < Motion.maxStaggered
              ? AnimatedListItem(
                  key: ValueKey(t.id),
                  index: index,
                  delay: const Duration(milliseconds: 220),
                  child: row,
                )
              : KeyedSubtree(key: ValueKey(t.id), child: row);
        },
      ),
    );
  }
}
