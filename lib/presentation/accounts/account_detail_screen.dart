import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bastasaving/core/theme/app_colors.dart';
import 'package:bastasaving/core/theme/app_text_styles.dart';
import 'package:bastasaving/core/utils/currency_formatter.dart';
import 'package:bastasaving/data/database/database.dart';
import 'package:bastasaving/presentation/providers/account_providers.dart';
import 'package:bastasaving/presentation/providers/transaction_providers.dart';
import 'package:bastasaving/presentation/providers/category_providers.dart';
import 'package:bastasaving/presentation/providers/theme_providers.dart';
import 'package:bastasaving/shared/widgets/glass_card.dart';
import 'package:bastasaving/shared/widgets/section_header.dart';
import 'package:bastasaving/shared/widgets/empty_state.dart';
import 'package:bastasaving/shared/widgets/animated_counter.dart';
import 'package:bastasaving/shared/widgets/category_icon_widget.dart';
import 'package:bastasaving/presentation/transactions/widgets/add_transaction_sheet.dart';

class AccountDetailScreen extends ConsumerWidget {
  final int accountId;
  const AccountDetailScreen({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountByIdProvider(accountId));
    final transactionsAsync = ref.watch(transactionsByAccountProvider(accountId));
    final currency = ref.watch(defaultCurrencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: accountAsync.when(
          data: (a) => Text(a?.name ?? 'Account'),
          loading: () => const Text('Account'),
          error: (_, __) => const Text('Account'),
        ),
        actions: [
          if (accountAsync.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, accountAsync.valueOrNull!),
            ),
        ],
      ),
      body: accountAsync.when(
        data: (account) {
          if (account == null) return const EmptyState(icon: Icons.error, title: 'Account not found');
          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              _AccountHero(account: account, currency: currency),
              const SizedBox(height: 16),
              SectionHeader(title: 'Transactions', trailing: TextButton.icon(
                onPressed: () => _addTransaction(context, ref, account),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              )),
              transactionsAsync.when(
                data: (transactions) => _TransactionList(
                  transactions: transactions,
                  account: account,
                  ref: ref,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const EmptyState(icon: Icons.error, title: 'Error loading transactions'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(icon: Icons.error, title: 'Error loading account'),
      ),
      floatingActionButton: accountAsync.valueOrNull != null
          ? FloatingActionButton.extended(
              onPressed: () => _addTransaction(context, ref, accountAsync.valueOrNull!),
              icon: const Icon(Icons.add),
              label: const Text('Transaction'),
            )
          : null,
    );
  }

  void _addTransaction(BuildContext context, WidgetRef ref, Account account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProviderScope(
        overrides: [],
        child: AddTransactionSheet(initialAccountId: account.id),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Account account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text('Delete "${account.name}" and all its transactions?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final dao = ref.read(accountDaoProvider);
              await dao.deleteAccount(account.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) context.pop();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _AccountHero extends StatelessWidget {
  final Account account;
  final String currency;

  const _AccountHero({required this.account, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GlassCard(
        gradient: AppColors.accountGradients[AppColors.accountGradientIndex(account.icon)],
        padding: const EdgeInsets.all(24),
        borderRadius: 20,
        elevation: 6,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _iconData(account.icon),
                color: Colors.white.withValues(alpha: 0.95),
                size: 40,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              account.name,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              account.type.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedCounter(
              value: account.balance,
              currency: account.currency,
              style: AppTextStyles.numberBold.copyWith(fontSize: 34, color: Colors.white),
              duration: const Duration(milliseconds: 600),
            ),
          ],
        ),
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
      default: return Icons.account_balance_wallet;
    }
  }
}

class _TransactionList extends ConsumerWidget {
  final List<Transaction> transactions;
  final Account account;
  final WidgetRef ref;

  const _TransactionList({
    required this.transactions,
    required this.account,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactions.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long,
        title: 'No transactions',
        subtitle: 'Add a transaction to get started',
      );
    }

    final categoriesAsync = ref.watch(categoriesProvider);

    return categoriesAsync.when(
      data: (categories) => Column(
        children: transactions.map((t) => _TransactionItem(
          transaction: t,
          category: categories.cast<Category?>().firstWhere(
            (c) => c?.id == t.categoryId,
            orElse: () => null,
          ),
          account: account,
        )).toList(),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TransactionItem extends ConsumerWidget {
  final Transaction transaction;
  final Category? category;
  final Account account;

  const _TransactionItem({
    required this.transaction,
    this.category,
    required this.account,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    Text(category?.name ?? 'Unknown',
                        style: AppTextStyles.bodyMedium.copyWith(fontSize: 14)),
                    if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(transaction.note!,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          )),
                    ],
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
                  '${isIncome ? '+' : '-'}${CurrencyFormatter.formatCompact(transaction.amount, currency: account.currency)}',
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
