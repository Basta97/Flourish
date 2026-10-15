import 'package:flourish/presentation/providers/finance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/services/insights_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/providers/category_providers.dart';
import 'package:flourish/presentation/providers/account_providers.dart';
import 'package:flourish/presentation/providers/transaction_providers.dart';
import 'package:flourish/presentation/providers/theme_providers.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/presentation/transactions/widgets/transaction_form_parts.dart';
import 'package:flourish/shared/widgets/segmented_pill.dart';
import 'package:flourish/shared/widgets/bottom_sheet_scaffold.dart';
import 'package:flourish/core/utils/amount_parser.dart';
import 'package:flourish/core/utils/error_text.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  final String? initialType;
  final int? initialAccountId;

  const AddTransactionSheet({
    super.key,
    this.initialType,
    this.initialAccountId,
  });

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();
  final _destinationAmountController = TextEditingController();
  final _feeController = TextEditingController();
  String _mode = 'expense';
  int? _accountId;
  int? _toAccountId;
  int? _categoryId;
  DateTime _date = DateTime.now();
  SubmitState _submitState = SubmitState.idle;
  String? _amountError;
  String? _accountError;
  String? _categoryError;
  String? _destinationError;
  String? _feeError;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialType ?? 'expense';
    _accountId = widget.initialAccountId;
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    _amountController.dispose();
    _destinationAmountController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    if (_categoryId != null || _mode == 'transfer') return;
    final note = _noteController.text.trim();
    if (note.length < 3) return;
    final transactions = ref.read(transactionsProvider).valueOrNull ?? [];
    final cats = ref.read(categoriesProvider).valueOrNull ?? [];
    final suggested = InsightsService.suggestCategoryFromNote(
      note,
      transactions,
      categories: cats,
      type: _mode,
    );
    if (suggested != null) {
      final hasCategory = cats.any((c) => c.id == suggested && c.type == _mode);
      if (hasCategory && suggested != _categoryId) {
        setState(() => _categoryId = suggested);
      }
    }
  }

  void _selectMode(String mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _categoryId = null;
      _toAccountId = null;
      _accountError = null;
      _categoryError = null;
    });
  }

  static const _modes = ['expense', 'income', 'transfer'];

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final allAccounts = accountsAsync.valueOrNull ?? [];
    final effectiveFrom = _effectiveAccountId(allAccounts);
    final chosen = allAccounts.where((a) => a.id == effectiveFrom).firstOrNull;
    final currency =
        chosen?.currency ?? ref.watch<String>(defaultCurrencyProvider);
    final tint = modeColor(context, _mode);
    return BottomSheetScaffold(
      title: 'New Transaction',
      children: [
        SegmentedPill(
          labels: const ['Expense', 'Income', 'Transfer'],
          selectedIndex: _modes.indexOf(_mode),
          activeColor: tint,
          height: 44,
          onChanged: (i) => _selectMode(_modes[i]),
        ),
        const SizedBox(height: Sp.xl),
        AmountInput(
          controller: _amountController,
          currency: currency,
          color: tint,
          errorText: _amountError,
          autofocus: true,
          onChanged: (_) => setState(() => _amountError = null),
        ),
        const SizedBox(height: Sp.lg),
        if (allAccounts.isEmpty)
          Text(
            accountsAsync.isLoading
                ? ''
                : 'No accounts available. Please add an account first.',
            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
          )
        else if (_mode == 'transfer') ...[
          if (allAccounts.length < 2)
            Text(
              'Add at least 2 accounts to transfer.',
              style: AppTextStyles.caption.copyWith(color: AppColors.danger),
            )
          else ...[
            const FormLabel('From'),
            AccountChips(
              accounts: allAccounts,
              selectedId: effectiveFrom,
              color: tint,
              onSelected: (v) => setState(() {
                _accountId = v;
                if (_toAccountId == v) _toAccountId = null;
                _accountError = null;
              }),
            ),
            const SizedBox(height: Sp.lg),
            const FormLabel('To'),
            AccountChips(
              accounts: allAccounts
                  .where((a) => a.id != effectiveFrom)
                  .toList(),
              selectedId: _effectiveDestinationId(allAccounts, effectiveFrom!),
              color: tint,
              onSelected: (v) => setState(() => _toAccountId = v),
            ),
            if (_destinationCurrency(allAccounts, effectiveFrom)
                case final toCurrency? when toCurrency != currency) ...[
              const SizedBox(height: Sp.lg),
              TextField(
                controller: _destinationAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [AmountInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Amount received in $toCurrency',
                  helperText: 'What actually arrived after conversion',
                  errorText: _destinationError,
                ),
                onChanged: (_) => setState(() => _destinationError = null),
              ),
            ],
            const SizedBox(height: Sp.md),
            TextField(
              controller: _feeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [AmountInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Transfer fee in $currency (optional)',
                errorText: _feeError,
              ),
              onChanged: (_) => setState(() => _feeError = null),
            ),
          ],
        ] else ...[
          const FormLabel('Account'),
          AccountChips(
            accounts: allAccounts,
            selectedId: effectiveFrom,
            color: tint,
            onSelected: (v) => setState(() {
              _accountId = v;
              _accountError = null;
            }),
          ),
          const SizedBox(height: Sp.lg),
          FormLabel(
            'Category',
            trailing: _categoryError == null
                ? null
                : Text(
                    _categoryError!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
          ),
          categoriesAsync.when(
            data: (cats) {
              final filtered = cats.where((c) => c.type == _mode).toList();
              return CategoryGrid(
                categories: filtered,
                selectedId: _effectiveCategoryId(filtered),
                onSelected: (v) => setState(() {
                  _categoryId = v;
                  _categoryError = null;
                }),
              );
            },
            loading: () => const SizedBox(height: 84),
            error: (error, stackTrace) => const SizedBox(height: 84),
          ),
        ],
        if (_accountError != null) ...[
          const SizedBox(height: Sp.sm),
          Text(
            _accountError!,
            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
          ),
        ],
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
          label: _mode == 'transfer'
              ? 'Transfer'
              : 'Add ${_mode == 'expense' ? 'Expense' : 'Income'}',
          color: tint,
          state: _submitState,
          onPressed: _submit,
        ),
      ],
    );
  }

  int? _effectiveAccountId(List<Account> accounts) {
    if (accounts.isEmpty) return null;
    final selected = _accountId;
    if (selected != null && accounts.any((account) => account.id == selected)) {
      return selected;
    }
    return accounts.first.id;
  }

  int? _effectiveDestinationId(List<Account> accounts, int fromAccountId) {
    final destinations = accounts
        .where((account) => account.id != fromAccountId)
        .toList();
    if (destinations.isEmpty) return null;
    final selected = _toAccountId;
    if (selected != null &&
        destinations.any((account) => account.id == selected)) {
      return selected;
    }
    return destinations.first.id;
  }

  int? _effectiveCategoryId(List<Category> categories) {
    if (categories.isEmpty) return null;
    final selected = _categoryId;
    if (selected != null &&
        categories.any((category) => category.id == selected)) {
      return selected;
    }
    return categories.first.id;
  }

  String? _destinationCurrency(List<Account> accounts, int? fromId) {
    if (fromId == null) return null;
    final toId = _effectiveDestinationId(accounts, fromId);
    return accounts.where((a) => a.id == toId).firstOrNull?.currency;
  }

  Future<void> _submit() async {
    setState(() {
      _amountError = null;
      _accountError = null;
      _categoryError = null;
      _destinationError = null;
      _feeError = null;
    });

    final accounts = ref.read(accountsProvider).valueOrNull ?? [];
    final accountId = _effectiveAccountId(accounts);
    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    final currency = account?.currency ?? '';
    final parsed = AmountParser.parse(
      _amountController.text,
      currency: currency,
    );
    final categories = ref.read(categoriesProvider).valueOrNull ?? [];
    final filteredCategories = categories
        .where((category) => category.type == _mode)
        .toList();
    final categoryId = _mode == 'transfer'
        ? null
        : _effectiveCategoryId(filteredCategories);
    final toAccountId = accountId == null
        ? null
        : _effectiveDestinationId(accounts, accountId);
    final toCurrency = accounts
        .where((a) => a.id == toAccountId)
        .firstOrNull
        ?.currency;
    bool hasError = false;

    if (!parsed.isValid) {
      setState(() => _amountError = parsed.error);
      hasError = true;
    }
    if (accountId == null) {
      setState(() => _accountError = 'Please select an account');
      hasError = true;
    }

    Amount? received, fee;
    if (_mode == 'transfer') {
      if (accounts.length < 2 || toAccountId == null) {
        setState(() => _accountError = 'Please select destination account');
        hasError = true;
      }
      if (toAccountId != null && toAccountId == accountId) {
        setState(
          () => _accountError =
              'Transfer source and destination must be different',
        );
        hasError = true;
      }
      if (toCurrency != null && toCurrency != currency) {
        final result = AmountParser.parse(
          _destinationAmountController.text,
          currency: toCurrency,
        );
        if (result.isValid) {
          received = result.value;
        } else {
          setState(() => _destinationError = result.error);
          hasError = true;
        }
      }
      if (_feeController.text.trim().isNotEmpty) {
        final result = AmountParser.parse(
          _feeController.text,
          currency: currency,
          allowZero: true,
        );
        if (result.isValid) {
          fee = result.value;
        } else {
          setState(() => _feeError = result.error);
          hasError = true;
        }
      }
    } else {
      if (categoryId == null) {
        setState(() => _categoryError = 'Please select a category');
        hasError = true;
      }
    }
    if (hasError) return;
    if (!await confirmFutureDate(context, _date)) return;

    setState(() => _submitState = SubmitState.busy);
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    try {
      final ledger = ref.read(financialLedgerProvider);
      if (_mode == 'transfer') {
        await ledger.transfer(
          fromAccountId: accountId!,
          toAccountId: toAccountId!,
          amount: parsed.value!,
          received: received,
          fee: fee,
          note: note,
          date: _date,
          expectCurrency: currency,
        );
      } else {
        await ledger.recordCash(
          accountId: accountId!,
          amount: parsed.value!,
          type: _mode,
          categoryId: categoryId!,
          note: note,
          date: _date,
          expectCurrency: currency,
        );
      }

      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(categoriesProvider);

      // Let the button morph into a check before the sheet drops away.
      Haptics.success();
      if (!mounted) return;
      setState(() => _submitState = SubmitState.done);
      await Future<void>.delayed(
        Motion.reduced(context)
            ? Duration.zero
            : const Duration(milliseconds: 420),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _submitState = SubmitState.idle);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }
}
