import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bastasaving/core/theme/app_colors.dart';
import 'package:bastasaving/core/theme/app_text_styles.dart';
import 'package:bastasaving/core/utils/date_formatter.dart' as date_utils;
import 'package:bastasaving/core/utils/currency_formatter.dart';
import 'package:bastasaving/data/database/database.dart';
import 'package:bastasaving/presentation/providers/transaction_providers.dart';
import 'package:bastasaving/presentation/providers/category_providers.dart';
import 'package:bastasaving/presentation/providers/account_providers.dart';
import 'package:bastasaving/presentation/providers/theme_providers.dart';
import 'package:bastasaving/shared/widgets/category_icon_widget.dart';
import 'package:drift/drift.dart' hide Column;

class AddTransactionSheet extends ConsumerStatefulWidget {
  final String? initialType;
  final int? initialAccountId;

  const AddTransactionSheet({
    super.key,
    this.initialType,
    this.initialAccountId,
  });

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();
  String _type = 'expense';
  int? _accountId;
  int? _categoryId;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? 'expense';
    _accountId = widget.initialAccountId;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final currency = ref.watch(defaultCurrencyProvider);

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
          Row(
            children: [
              _TypeToggle(
                label: 'Expense',
                icon: Icons.arrow_downward,
                selected: _type == 'expense',
                color: AppColors.expense,
                onTap: () => setState(() => _type = 'expense'),
              ),
              const SizedBox(width: 12),
              _TypeToggle(
                label: 'Income',
                icon: Icons.arrow_upward,
                selected: _type == 'income',
                color: AppColors.income,
                onTap: () => setState(() => _type = 'income'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '${CurrencyFormatter.symbolFor(currency)} ',
              hintText: '0.00',
            ),
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          accountsAsync.when(
            data: (accounts) => DropdownButtonFormField<int>(
              value: _accountId ?? (accounts.isNotEmpty ? accounts.first.id : null),
              decoration: const InputDecoration(labelText: 'Account'),
              items: accounts.map((a) => DropdownMenuItem(
                value: a.id,
                child: Text(a.name),
              )).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _accountId = v);
              },
            ),
            loading: () => const SizedBox(height: 60),
            error: (_, __) => const SizedBox(height: 60),
          ),
          const SizedBox(height: 12),
          categoriesAsync.when(
            data: (cats) {
              final filtered = cats.where((c) => c.type == _type).toList();
              if (filtered.isEmpty) return const SizedBox(height: 60);
              return DropdownButtonFormField<int>(
                value: _categoryId ?? (filtered.isNotEmpty ? filtered.first.id : null),
                decoration: const InputDecoration(labelText: 'Category'),
                items: filtered.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Row(
                    children: [
                      CategoryIconWidget(
                        iconName: c.icon,
                        color: Color(c.color),
                        size: 28,
                        iconSize: 14,
                      ),
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
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'Add a note...'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _date = picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date'),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 8),
                  Text(date_utils.DateFormatter.formatFull(_date)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _type == 'expense' ? AppColors.expense : AppColors.income,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Add ${_type == 'expense' ? 'Expense' : 'Income'}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_accountId == null || _categoryId == null) return;
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    final db = ref.read(transactionDaoProvider);

    await db.insertTransaction(TransactionsCompanion.insert(
      accountId: _accountId!,
      categoryId: _categoryId!,
      amount: amount,
      type: _type,
      note: Value(_noteController.text.trim().isEmpty ? null : _noteController.text.trim()),
      transactionDate: _date,
    ));

    final account = await db.getAccountById(_accountId!);
    if (account != null) {
      final newBalance = _type == 'income'
          ? account.balance + amount
          : account.balance - amount;
      await db.updateAccount(account.copyWith(balance: newBalance));
    }

    if (mounted) Navigator.pop(context);
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeToggle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08)),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? color : null, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: selected ? color : null,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
