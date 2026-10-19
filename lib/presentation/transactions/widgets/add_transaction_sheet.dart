import '../../currencies/currency_picker.dart';
import '../../templates/template_picker.dart';
import '../../../core/finance/transaction_templates.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/presentation/providers/finance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/services/category_suggester.dart';
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
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/core/utils/error_text.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  final TemplateSelection? templateSelection;
  final String? initialType;
  final int? initialAccountId;

  const AddTransactionSheet({
    super.key,
    this.templateSelection,
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
  String? _templateId;
  bool _confirming = false;
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
  // What paid, where, and in which currency.
  int? _instrumentId;
  String? _method;
  int? _paymentForAccount;
  final _merchantController = TextEditingController();
  bool _foreign = false;
  String? _originalCurrency;
  final _originalController = TextEditingController();
  bool _feeIncluded = false;
  bool _bookedEdited = false;
  bool _refund = false;
  String? _originalError;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialType ?? 'expense';
    _accountId = widget.initialAccountId;
    _noteController.addListener(_onNoteChanged);
    if (widget.templateSelection case final selection?) {
      _applyTemplate(selection);
    }
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    _amountController.dispose();
    _destinationAmountController.dispose();
    _feeController.dispose();
    _merchantController.dispose();
    _originalController.dispose();
    super.dispose();
  }

  void _applyTemplate(TemplateSelection selection) {
    final t = selection.template;
    _templateId = t.id;
    _mode = t.type;
    _accountId = t.accountId;
    _categoryId = t.categoryId;
    _amountController.text = '${selection.amount}';
    _noteController.text = t.note ?? '';
    _date = DateTime.now();
    _instrumentId = null;
    _method = null;
    _foreign = false;
    _refund = false;
    _toAccountId = null;
    _amountError = _accountError = _categoryError = null;
  }

  Future<void> _pickTemplate() async {
    final selection = await pickTemplate(context, ref);
    if (selection != null && mounted) setState(() => _applyTemplate(selection));
  }

  void _onNoteChanged() {
    if (_categoryId != null || _mode == 'transfer') return;
    final note = _noteController.text.trim();
    if (note.length < 3) return;
    final transactions = ref.read(transactionsProvider).valueOrNull ?? [];
    final cats = ref.read(pickableCategoriesProvider).valueOrNull ?? [];
    final suggested = CategorySuggester.suggest(
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
    final categoriesAsync = ref.watch(pickableCategoriesProvider);
    final details = ref.watch(accountDetailsProvider).valueOrNull ?? {};
    final allAccounts = (accountsAsync.valueOrNull ?? <Account>[])
        .where((a) => details[a.id]?.archived != true)
        .toList();
    final effectiveFrom = _effectiveAccountId(allAccounts);
    final chosen = allAccounts.where((a) => a.id == effectiveFrom).firstOrNull;
    final currency =
        chosen?.currency ?? ref.watch<String>(defaultCurrencyProvider);
    final tint = modeColor(context, _mode);
    return BottomSheetScaffold(
      title: context.l10n.newTransaction,
      children: [
        SegmentedPill(
          labels: [
            context.l10n.expense,
            context.l10n.income,
            context.l10n.transfer,
          ],
          selectedIndex: _modes.indexOf(_mode),
          activeColor: tint,
          height: 44,
          onChanged: (i) => _selectMode(_modes[i]),
        ),
        if (_mode != 'transfer')
          TextButton.icon(
            onPressed: _submitState == SubmitState.busy ? null : _pickTemplate,
            icon: const Icon(Icons.bookmark_outline),
            label: Text(context.l10n.useTemplate),
          ),
        const SizedBox(height: Sp.xl),
        AmountInput(
          controller: _amountController,
          currency: currency,
          color: tint,
          errorText: _amountError,
          autofocus: true,
          onChanged: (_) => setState(() {
            _amountError = null;
            if (_foreign) _bookedEdited = true;
          }),
        ),
        const SizedBox(height: Sp.lg),
        if (allAccounts.isEmpty)
          Text(
            accountsAsync.isLoading ? '' : context.l10n.noAccountsAddFirst,
            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
          )
        else if (_mode == 'transfer') ...[
          if (allAccounts.length < 2)
            Text(
              context.l10n.needTwoAccounts,
              style: AppTextStyles.caption.copyWith(color: AppColors.danger),
            )
          else ...[
            FormLabel(context.l10n.from),
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
            FormLabel(context.l10n.to),
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
                  labelText: context.l10n.amountReceivedIn(toCurrency),
                  helperText: context.l10n.whatArrived,
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
                labelText: context.l10n.transferFeeIn(currency),
                errorText: _feeError,
              ),
              onChanged: (_) => setState(() => _feeError = null),
            ),
          ],
        ] else ...[
          FormLabel(context.l10n.account),
          AccountChips(
            accounts: allAccounts,
            selectedId: effectiveFrom,
            color: tint,
            onSelected: (v) => setState(() {
              _accountId = v;
              _accountError = null;
            }),
          ),
          if (_mode == 'expense' && chosen != null) ...[
            const SizedBox(height: Sp.lg),
            ..._paymentFields(chosen, tint),
          ],
          const SizedBox(height: Sp.lg),
          FormLabel(
            _refund ? context.l10n.refundFor : context.l10n.category,
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
        if (_mode == 'expense') ...[
          const SizedBox(height: Sp.lg),
          TextField(
            controller: _merchantController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: context.l10n.merchantOptional,
              prefixIcon: Icon(Icons.storefront_outlined, size: 20),
            ),
          ),
        ],
        const SizedBox(height: Sp.lg),
        TextField(
          controller: _noteController,
          decoration: InputDecoration(
            hintText: context.l10n.addNote,
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
              ? context.l10n.transfer
              : _mode == 'expense' && _refund
              ? context.l10n.addRefund
              : _mode == 'expense'
              ? context.l10n.addExpense
              : context.l10n.addIncome,
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
    return _templateId != null ? null : accounts.first.id;
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
    return _templateId != null ? null : categories.first.id;
  }

  /// Preselects the account's default card when the account changes.
  void _syncPayment(Account account, List<PaymentInstrument>? instruments) {
    // Wait for the cards to load, or the default would never be picked.
    if (_paymentForAccount == account.id || instruments == null) return;
    _paymentForAccount = account.id;
    final preferred = instruments
        .where((i) => i.accountId == account.id && !i.archived)
        .where((i) => i.isDefault)
        .firstOrNull;
    _instrumentId = preferred?.id;
    _method = preferred?.kind;
    if (_originalCurrency == account.currency) _originalCurrency = null;
  }

  List<Widget> _paymentFields(Account account, Color tint) {
    final loaded = ref.watch(paymentInstrumentsProvider).valueOrNull;
    _syncPayment(account, loaded);
    final instruments = loaded ?? const <PaymentInstrument>[];
    final palette = FlourishPalette.of(context);
    final credit = account.type == 'credit'
        ? ref.watch(creditStatusProvider(account.id)).valueOrNull
        : null;
    final typed = AmountParser.parse(
      _amountController.text,
      currency: account.currency,
    ).value;
    final over = typed == null
        ? null
        : credit?.overAfter(typed, foreign: _foreign && !_refund);
    return [
      FormLabel(context.l10n.paidWith),
      PaidWithChips(
        account: account,
        instruments: instruments,
        instrumentId: _instrumentId,
        method: _method,
        color: tint,
        onChanged: (id, method) => setState(() {
          _instrumentId = id;
          _method = method;
        }),
      ),
      if (over != null)
        Padding(
          padding: const EdgeInsets.only(top: Sp.sm),
          child: Text(
            (over.international
                ? context.l10n.overCardIntlLimit
                : context.l10n.overCardLimit)(
              CurrencyFormatter.format(
                over.by.toDouble(),
                currency: account.currency,
              ),
            ),
            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
          ),
        ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: _refund,
        title: Text(context.l10n.isRefund),
        subtitle: Text(context.l10n.isRefundSubtitle),
        onChanged: (v) => setState(() {
          _refund = v;
          if (v) _foreign = false;
        }),
      ),
      if (!_refund && account.type != 'cash')
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _foreign,
          title: Text(context.l10n.paidOtherCurrency),
          subtitle: Text(
            context.l10n.paidOtherCurrencySubtitle(account.currency),
          ),
          onChanged: (v) => setState(() {
            _foreign = v;
            _originalCurrency ??= account.currency == 'USD' ? 'EUR' : 'USD';
          }),
        ),
      if (_foreign && !_refund) ...[
        Row(
          children: [
            SizedBox(
              width: 110,
              child: CurrencyField(
                value: _originalCurrency ?? 'USD',
                label: context.l10n.currency,
                excluded: {account.currency},
                onChanged: (v) {
                  setState(() => _originalCurrency = v);
                  _estimateBooked(account);
                },
              ),
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: TextField(
                controller: _originalController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [AmountInputFormatter()],
                decoration: InputDecoration(
                  labelText: context.l10n.priceIn(_originalCurrency ?? ''),
                  errorText: _originalError,
                ),
                onChanged: (_) {
                  setState(() => _originalError = null);
                  _estimateBooked(account);
                },
              ),
            ),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _feeIncluded,
          title: Text(context.l10n.feeIncluded),
          onChanged: (v) => setState(() => _feeIncluded = v),
        ),
        FutureBuilder<Amount>(
          future: _feePercent(account),
          builder: (context, snap) {
            final pct = snap.data ?? Amount.zero;
            final charged = typed ?? Amount.zero;
            final digits = CurrencyFormatter.decimalsFor(account.currency);
            final fee = _feeIncluded
                ? charged -
                      (charged / (Amount.one + pct / Amount('100'))).rounded(
                        digits,
                      )
                : (charged * pct / Amount('100')).rounded(digits);
            String fmt(Amount a) => CurrencyFormatter.format(
              a.toDouble(),
              currency: account.currency,
            );
            return Text(
              pct == Amount.zero
                  ? context.l10n.chargedAmountNote(account.name)
                  : _feeIncluded
                  ? context.l10n.fxFeeInside('$pct', fmt(fee), fmt(charged))
                  : context.l10n.fxFeeOnTop('$pct', fmt(fee), fmt(charged)),
              style: AppTextStyles.caption.copyWith(color: palette.textLow),
            );
          },
        ),
      ],
    ];
  }

  Future<Amount>? _feeFuture;
  Object? _feeKey;

  /// The FX fee for the chosen account and card, fetched once per choice.
  Future<Amount> _feePercent(Account account) {
    final key = (account.id, _instrumentId);
    if (_feeKey != key || _feeFuture == null) {
      _feeKey = key;
      _feeFuture = ref
          .read(financialLedgerProvider)
          .fxFeePercentFor(account, _instrumentId);
    }
    return _feeFuture!;
  }

  /// Prefills what the account was charged from the reference rate until
  /// the person types their own figure.
  Future<void> _estimateBooked(Account account) async {
    final currency = _originalCurrency;
    if (_bookedEdited || currency == null) return;
    final original = AmountParser.parse(
      _originalController.text,
      currency: currency,
    ).value;
    if (original == null) return;
    final converted = await ref
        .read(valuationProvider)
        .convert(original, currency, account.currency, at: _date);
    if (!mounted || converted == null || _bookedEdited) return;
    setState(() {
      _amountController.text =
          '${converted.rounded(CurrencyFormatter.decimalsFor(account.currency))}';
    });
  }

  String? _destinationCurrency(List<Account> accounts, int? fromId) {
    if (fromId == null) return null;
    final toId = _effectiveDestinationId(accounts, fromId);
    return accounts.where((a) => a.id == toId).firstOrNull?.currency;
  }

  Future<void> _submit() async {
    if (_submitState != SubmitState.idle || _confirming) return;
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
    final categories = ref.read(pickableCategoriesProvider).valueOrNull ?? [];
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
      setState(() => _accountError = context.l10n.selectAccountError);
      hasError = true;
    }

    Amount? received, fee;
    if (_mode == 'transfer') {
      if (accounts.length < 2 || toAccountId == null) {
        setState(() => _accountError = context.l10n.selectDestinationError);
        hasError = true;
      }
      if (toAccountId != null && toAccountId == accountId) {
        setState(() => _accountError = context.l10n.sameAccountsError);
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
        setState(() => _categoryError = context.l10n.selectCategoryError);
        hasError = true;
      }
    }
    Money? original;
    if (_mode == 'expense' && _foreign && !_refund) {
      final result = AmountParser.parse(
        _originalController.text,
        currency: _originalCurrency ?? '',
      );
      if (!result.isValid || _originalCurrency == null) {
        setState(
          () => _originalError = result.error ?? context.l10n.chooseCurrency,
        );
        hasError = true;
      } else {
        original = Money('${result.value}', _originalCurrency!);
      }
    }
    if (hasError) return;
    _confirming = true;
    final confirmed = await confirmFutureDate(context, _date);
    _confirming = false;
    if (!mounted || !confirmed) return;
    final merchant = _mode == 'expense' ? _merchantController.text : null;

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
      } else if (_mode == 'expense' && _refund) {
        await ledger.recordRefund(
          accountId: accountId!,
          amount: parsed.value!,
          expenseCategoryId: categoryId!,
          instrumentId: _instrumentId,
          merchant: merchant,
          note: note,
          date: _date,
          source: _templateId == null ? 'manual' : 'template',
          sourceRef: _templateId,
          expectCurrency: currency,
        );
      } else if (_mode == 'expense' && original != null) {
        await ledger.recordPurchase(
          accountId: accountId!,
          amount: parsed.value!,
          categoryId: categoryId!,
          original: original,
          feeIncluded: _feeIncluded,
          instrumentId: _instrumentId,
          paymentMethod: _method,
          merchant: merchant,
          note: note,
          date: _date,
          source: _templateId == null ? 'manual' : 'template',
          sourceRef: _templateId,
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
          instrumentId: _mode == 'expense' ? _instrumentId : null,
          paymentMethod: _mode == 'expense' ? _method : null,
          merchant: merchant,
          source: _templateId == null ? 'manual' : 'template',
          sourceRef: _templateId,
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

/// Shared entry point for the Add menu and phone-widget action.
class TemplateTransactionSheet extends ConsumerStatefulWidget {
  const TemplateTransactionSheet({super.key});
  @override
  ConsumerState<TemplateTransactionSheet> createState() =>
      _TemplateTransactionSheetState();
}

class _TemplateTransactionSheetState
    extends ConsumerState<TemplateTransactionSheet> {
  TemplateSelection? selection;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final picked = await pickTemplate(context, ref);
      if (!mounted) return;
      if (picked == null) {
        Navigator.pop(context);
        return;
      }
      setState(() => selection = picked);
    });
  }

  @override
  Widget build(BuildContext context) => selection == null
      ? const SizedBox(
          height: 160,
          child: Center(child: Icon(Icons.bookmark_outline)),
        )
      : AddTransactionSheet(templateSelection: selection);
}
