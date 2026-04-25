import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bastasaving/core/theme/app_colors.dart';
import 'package:bastasaving/core/theme/app_text_styles.dart';
import 'package:bastasaving/core/constants/app_constants.dart';
import 'package:bastasaving/core/utils/currency_formatter.dart';
import 'package:bastasaving/data/database/database.dart';
import 'package:bastasaving/presentation/providers/account_providers.dart';
import 'package:bastasaving/presentation/providers/theme_providers.dart';
import 'package:bastasaving/shared/widgets/glass_card.dart';
import 'package:bastasaving/shared/widgets/empty_state.dart';
import 'package:drift/drift.dart' hide Column;

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(accountsProvider.future),
        child: accountsAsync.when(
          data: (accounts) {
            if (accounts.isEmpty) {
              return const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No accounts yet',
                subtitle: 'Add your first account to start tracking',
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                return _AccountGridCard(
                  account: account,
                  onTap: () => context.push('/accounts/${account.id}'),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const EmptyState(icon: Icons.error, title: 'Error loading accounts'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccountSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Account'),
      ),
    );
  }

  void _showAddAccountSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddAccountSheet(ref: ref),
    );
  }
}

class _AccountGridCard extends StatelessWidget {
  final Account account;
  final VoidCallback onTap;

  const _AccountGridCard({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors.accountGradients[
        AppColors.accountGradientIndex(account.icon)];
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        gradient: gradient,
        padding: const EdgeInsets.all(16),
        borderRadius: 17,
        elevation: 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconData(account.icon),
                color: Colors.white.withValues(alpha: 0.95),
                size: 24,
              ),
            ),
            const Spacer(),
            Text(
              account.name,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(account.balance, currency: account.currency),
              style: AppTextStyles.numberBold.copyWith(
                fontSize: 19,
                color: Colors.white,
              ),
            ),
            Text(
              account.type.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 10,
              ),
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

class _AddAccountSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _AddAccountSheet({required this.ref});

  @override
  ConsumerState<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<_AddAccountSheet> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  String _type = 'bank';
  String _currency = 'USD';
  int _color = 0xFF4F46E5;
  String _icon = 'account_balance';

  @override
  void initState() {
    super.initState();
    _currency = widget.ref.read(defaultCurrencyProvider);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
          Text('Add Account', style: AppTextStyles.heading.copyWith(fontSize: 20)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Account Name', hintText: 'e.g. Main Bank'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _balanceController,
            decoration: InputDecoration(
              labelText: 'Initial Balance',
              hintText: '0.00',
              prefixText: '${CurrencyFormatter.symbolFor(_currency)} ',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Account Type'),
            items: AppConstants.accountTypeOptions.map((opt) => DropdownMenuItem(
              value: opt['value'] as String,
              child: Row(
                children: [
                  Icon(_typeIcon(opt['icon'] as String), size: 18),
                  const SizedBox(width: 8),
                  Text(opt['label'] as String),
                ],
              ),
            )).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _type = v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _currency,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: AppConstants.currencies.map((c) => DropdownMenuItem(
              value: c,
              child: Text(c),
            )).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _currency = v);
            },
          ),
          const SizedBox(height: 12),
          Text('Icon', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.accountIcons.map((icon) {
              final selected = _icon == icon;
              return GestureDetector(
                onTap: () => setState(() => _icon = icon),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(_iconData(icon), color: selected ? AppColors.primary : null, size: 24),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text('Color', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppColors.accountGradients.map((g) {
              final color = g[0];
              final selected = _color == color.value;
              return GestureDetector(
                onTap: () => setState(() => _color = color.value),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: selected ? Border.all(color: Colors.white, width: 3) : null,
                    boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)] : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add Account', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _submit() async {
    if (_nameController.text.trim().isEmpty) return;
    final dao = widget.ref.read(accountDaoProvider);
    await dao.insertAccount(AccountsCompanion.insert(
      name: _nameController.text.trim(),
      type: _type,
      balance: Value(double.tryParse(_balanceController.text) ?? 0),
      currency: Value(_currency),
      color: _color,
      icon: _icon,
    ));
    if (mounted) Navigator.pop(context);
  }

  IconData _typeIcon(String iconName) {
    switch (iconName) {
      case 'account_balance': return Icons.account_balance;
      case 'account_balance_wallet': return Icons.account_balance_wallet;
      case 'credit_card': return Icons.credit_card;
      case 'wallet': return Icons.wallet;
      default: return Icons.account_balance_wallet;
    }
  }

  IconData _iconData(String name) {
    switch (name) {
      case 'account_balance': return Icons.account_balance;
      case 'account_balance_wallet': return Icons.account_balance_wallet;
      case 'credit_card': return Icons.credit_card;
      case 'savings': return Icons.savings;
      case 'wallet': return Icons.wallet;
      case 'payments': return Icons.payments;
      case 'currency_exchange': return Icons.currency_exchange;
      case 'monetization_on': return Icons.monetization_on;
      default: return Icons.account_balance_wallet;
    }
  }
}
