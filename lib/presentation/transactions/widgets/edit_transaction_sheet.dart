import '../../wealth/finance_form.dart';
import '../../wealth/holdings_view.dart';
import 'package:flourish/presentation/providers/finance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/providers/category_providers.dart';
import 'package:flourish/presentation/providers/account_providers.dart';
import 'package:flourish/presentation/providers/theme_providers.dart';
import 'package:flourish/presentation/providers/transaction_providers.dart';
import 'package:flourish/presentation/providers/detection_providers.dart';
import 'package:flourish/shared/widgets/bottom_sheet_scaffold.dart';
import 'package:flourish/shared/widgets/segmented_pill.dart';
import 'package:flourish/core/motion/motion.dart';
import 'transaction_form_parts.dart';
import 'package:drift/drift.dart' hide Column;

class EditTransactionSheet extends ConsumerStatefulWidget {
  final Transaction transaction;

  const EditTransactionSheet({super.key, required this.transaction});

  @override
  ConsumerState<EditTransactionSheet> createState() =>
      _EditTransactionSheetState();
}

class _EditTransactionSheetState extends ConsumerState<EditTransactionSheet> {
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();
  late String _type;
  late int _accountId;
  late int _categoryId;
  late DateTime _date;
  SubmitState _submitState = SubmitState.idle;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _type = t.type;
    _accountId = t.accountId;
    _categoryId = t.categoryId;
    _date = t.transactionDate;
    _amountController.text = t.amount.toStringAsFixed(2);
    if (t.note != null) _noteController.text = t.note!;
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
    final currency =
        accountsAsync.valueOrNull
            ?.where((a) => a.id == _accountId)
            .firstOrNull
            ?.currency ??
        ref.watch<String>(defaultCurrencyProvider);
    final palette = FlourishPalette.of(context);
    if (widget.transaction.linkedTransactionId != null) {
      return BottomSheetScaffold(
        title: 'Transfer',
        children: [
          Text(
            'Changes apply to both linked accounts and the transfer fee.',
            style: AppTextStyles.body.copyWith(color: palette.textLow),
          ),
          const SizedBox(height: Sp.xl),
          FilledButton(
            onPressed: _editTransfer,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Rad.full),
              ),
            ),
            child: const Text('Edit transfer'),
          ),
          const SizedBox(height: Sp.sm),
          TextButton(
            onPressed: _confirmDelete,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete transfer'),
          ),
        ],
      );
    }

    final tint = modeColor(context, _type);
    final accounts = accountsAsync.valueOrNull ?? const <Account>[];
    return BottomSheetScaffold(
      title: 'Edit Transaction',
      headerTrailing: TextButton.icon(
        onPressed: _confirmDelete,
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        label: const Text('Delete'),
        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
      ),
      children: [
        SegmentedPill(
          labels: const ['Expense', 'Income'],
          selectedIndex: _type == 'income' ? 1 : 0,
          activeColor: tint,
          height: 44,
          onChanged: (i) => setState(() {
            _type = i == 1 ? 'income' : 'expense';
            _categoryId = -1;
          }),
        ),
        const SizedBox(height: Sp.xl),
        AmountInput(
          controller: _amountController,
          currency: currency,
          color: tint,
          errorText: _amountError,
          onChanged: (_) => setState(() => _amountError = null),
        ),
        const SizedBox(height: Sp.lg),
        if (accounts.isNotEmpty) ...[
          const FormLabel('Account'),
          AccountChips(
            accounts: accounts,
            selectedId: accounts.any((a) => a.id == _accountId)
                ? _accountId
                : accounts.first.id,
            color: tint,
            onSelected: (v) => setState(() => _accountId = v),
          ),
          const SizedBox(height: Sp.lg),
        ],
        const FormLabel('Category'),
        categoriesAsync.when(
          data: (cats) {
            final filtered = cats.where((c) => c.type == _type).toList();
            final valid =
                _categoryId > 0 && filtered.any((c) => c.id == _categoryId);
            if (filtered.isNotEmpty && !valid) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _categoryId = filtered.first.id);
                }
              });
            }
            return CategoryGrid(
              categories: filtered,
              selectedId: valid
                  ? _categoryId
                  : (filtered.isNotEmpty ? filtered.first.id : null),
              onSelected: (v) => setState(() => _categoryId = v),
            );
          },
          loading: () => const SizedBox(height: 84),
          error: (error, stackTrace) => const SizedBox(height: 84),
        ),
        const SizedBox(height: Sp.lg),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            hintText: 'Add a note',
            prefixIcon: Icon(Icons.notes_rounded, size: 20),
          ),
          minLines: 1,
          maxLines: 2,
        ),
        const SizedBox(height: Sp.md),
        DatePills(value: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: Sp.xl),
        SubmitButton(
          label: 'Save Changes',
          color: tint,
          state: _submitState,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _editTransfer() async {
    final db = ref.read(databaseProvider);
    final other = await db.getTransactionById(
      widget.transaction.linkedTransactionId!,
    );
    if (other == null || !mounted) return;
    final out = widget.transaction.type == 'expense'
        ? widget.transaction
        : other;
    final incoming = widget.transaction.type == 'income'
        ? widget.transaction
        : other;
    final details = await ref
        .read(financeStoreProvider)
        .transactionDetails(out.id);
    final feeTx = details?['feeId'] == null
        ? null
        : await db.getTransactionById(details!['feeId'] as int);
    final accounts = await db.getAllAccounts();
    if (!mounted) return;
    final saved = await financeForm(
      context,
      title: 'Edit linked transfer',
      fields: [
        FinanceField(
          'from',
          'From account',
          initial: '${out.accountId}',
          options: {
            for (final a in accounts) '${a.id}': '${a.name} (${a.currency})',
          },
        ),
        FinanceField(
          'to',
          'To account',
          initial: '${incoming.accountId}',
          options: {
            for (final a in accounts) '${a.id}': '${a.name} (${a.currency})',
          },
        ),
        FinanceField(
          'amount',
          'Source amount',
          initial: '${out.amount}',
          numeric: true,
        ),
        FinanceField(
          'received',
          'Destination amount',
          initial: '${incoming.amount}',
          numeric: true,
        ),
        FinanceField(
          'fee',
          'Source-currency fee',
          initial: '${feeTx?.amount ?? 0}',
          numeric: true,
        ),
        FinanceField(
          'date',
          'Date',
          initial: out.transactionDate.toIso8601String().substring(0, 10),
          date: true,
        ),
        FinanceField('note', 'Note', initial: out.note ?? '', required: false),
      ],
      save: (j) => ref
          .read(financialLedgerProvider)
          .transfer(
            fromAccountId: int.parse(j['from']!),
            toAccountId: int.parse(j['to']!),
            amount: number(j, 'amount'),
            received: number(j, 'received'),
            fee: number(j, 'fee'),
            date: DateTime.parse(j['date']!),
            note: j['note'],
            editId: out.id,
          ),
    );
    if (saved == true && mounted) Navigator.pop(context);
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure? The account balance will be adjusted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(financialLedgerProvider)
                    .deleteTransactionAndUpdateBalance(widget.transaction.id);
                ref.invalidate(transactionsProvider);
                ref.invalidate(accountsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  Navigator.pop(context);
                }
              } on TransactionLogicException catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
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

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Please enter a valid amount');
      return;
    }

    setState(() => _submitState = SubmitState.busy);
    try {
      await ref
          .read(financialLedgerProvider)
          .updateTransactionAndUpdateBalance(
            widget.transaction.copyWith(
              accountId: _accountId,
              categoryId: _categoryId,
              amount: amount,
              type: _type,
              note: Value(
                _noteController.text.trim().isEmpty
                    ? null
                    : _noteController.text.trim(),
              ),
              transactionDate: _date,
            ),
          );
      if (_categoryId != widget.transaction.categoryId) {
        // Teach Smart Import the corrected category for this merchant.
        final details = await ref
            .read(financeStoreProvider)
            .transactionDetails(widget.transaction.id);
        final key = details?['merchantKey'];
        if (key is String && key.isNotEmpty) {
          await ref
              .read(categoryLearningProvider)
              .learn(merchantKey: key, type: _type, categoryId: _categoryId);
        }
      }
      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);

      Haptics.success();
      if (!mounted) return;
      setState(() => _submitState = SubmitState.done);
      await Future<void>.delayed(
        Motion.reduced(context)
            ? Duration.zero
            : const Duration(milliseconds: 420),
      );
      if (mounted) Navigator.pop(context);
    } on TransactionLogicException catch (e) {
      if (mounted) {
        setState(() => _submitState = SubmitState.idle);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitState = SubmitState.idle);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }
}
