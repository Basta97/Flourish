import 'package:flourish/l10n/l10n.dart';
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
import 'package:flourish/presentation/categories/category_form_sheet.dart';
import 'package:flourish/shared/widgets/spring_bottom_sheet.dart';
import 'package:flourish/presentation/providers/account_providers.dart';
import 'package:flourish/presentation/providers/theme_providers.dart';
import 'package:flourish/presentation/providers/transaction_providers.dart';
import 'package:flourish/shared/widgets/bottom_sheet_scaffold.dart';
import 'package:flourish/shared/widgets/segmented_pill.dart';
import 'package:flourish/core/motion/motion.dart';
import 'transaction_form_parts.dart';
import 'package:flourish/core/utils/amount_parser.dart';
import 'package:flourish/core/finance/payment_methods.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/core/utils/error_text.dart';

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
  String? _currencyNote;
  int? _instrumentId;
  String? _method;
  final _merchantController = TextEditingController();
  bool _refund = false;
  String? _originalNote;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _type = t.type;
    _accountId = t.accountId;
    _categoryId = t.categoryId;
    _date = t.transactionDate;
    _amountController.text = '${Amount.fromNum(t.amount)}';
    if (t.note != null) _noteController.text = t.note!;
    _instrumentId = t.paymentInstrumentId;
    _method = t.paymentMethod;
    _merchantController.text = t.merchant ?? '';
    // The REAL column is a rounded projection; edit the exact stored value.
    ref.read(financeStoreProvider).transactionDetails(t.id).then((details) {
      if (!mounted) return;
      final exact = details?['amount'];
      final original = details?['original'] as Map?;
      setState(() {
        if (exact != null && _accountId == t.accountId) {
          _amountController.text = '$exact';
        }
        _refund = details?['kind'] == 'refund';
        if (original != null) {
          _originalNote = details?['fxFeePercent'] != null
              ? context.l10n.paidOriginalWithFee(
                  '${original['currency']}',
                  '${original['amount']}',
                  '${details!['fxFeePercent']}',
                )
              : context.l10n.paidOriginal(
                  '${original['currency']}',
                  '${original['amount']}',
                );
        }
      });
    });
  }

  /// Moving an entry to an account in another currency converts the amount
  /// at the transaction date's rate instead of silently relabelling it.
  Future<void> _changeAccount(int id, List<Account> accounts) async {
    final from = accounts.where((a) => a.id == _accountId).firstOrNull;
    final to = accounts.where((a) => a.id == id).firstOrNull;
    setState(() {
      _accountId = id;
      // A card belongs to one account; keep only a method that still fits.
      _instrumentId = null;
      if (to != null &&
          _method != null &&
          !PaymentMethods.fitsAccount(_method!, to.type)) {
        _method = null;
      }
    });
    if (from == null || to == null || from.currency == to.currency) {
      setState(() => _currencyNote = null);
      return;
    }
    final current = AmountParser.parse(
      _amountController.text,
      currency: from.currency,
    ).value;
    final converted = current == null
        ? null
        : await ref
              .read(valuationProvider)
              .convert(current, from.currency, to.currency, at: _date);
    if (!mounted) return;
    setState(() {
      if (converted == null) {
        _amountController.clear();
        _currencyNote = context.l10n.noRateForDate(from.currency, to.currency);
      } else {
        final rounded = converted.rounded(
          CurrencyFormatter.decimalsFor(to.currency),
        );
        _amountController.text = '$rounded';
        _currencyNote = context.l10n.convertedAtRate(
          from.currency,
          '${current!}',
          to.currency,
        );
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  /// Creates a category of [type] from the form and selects it.
  Future<void> _createCategory(String type) async {
    final id = await showSpringBottomSheet<int>(
      context: context,
      builder: (_) => CategoryFormSheet(initialType: type),
    );
    if (id == null || !mounted) return;
    setState(() => _categoryId = id);
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(pickableCategoriesProvider);
    final currency =
        accountsAsync.valueOrNull
            ?.where((a) => a.id == _accountId)
            .firstOrNull
            ?.currency ??
        ref.watch<String>(defaultCurrencyProvider);
    final palette = FlourishPalette.of(context);
    if (widget.transaction.linkedTransactionId != null) {
      return BottomSheetScaffold(
        title: context.l10n.transfer,
        children: [
          Text(
            context.l10n.transferEditNote,
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
            child: Text(context.l10n.editTransfer),
          ),
          const SizedBox(height: Sp.sm),
          TextButton(
            onPressed: _confirmDelete,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(context.l10n.deleteTransfer),
          ),
        ],
      );
    }

    final tint = modeColor(context, _type);
    final accounts = accountsAsync.valueOrNull ?? const <Account>[];
    return BottomSheetScaffold(
      title: context.l10n.editTransaction,
      headerTrailing: TextButton.icon(
        onPressed: _confirmDelete,
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        label: Text(context.l10n.delete),
        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
      ),
      children: [
        if (_refund)
          Text(
            context.l10n.refundReduces,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: palette.income),
          )
        else
          SegmentedPill(
            labels: [context.l10n.expense, context.l10n.income],
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
          FormLabel(context.l10n.account),
          AccountChips(
            accounts: accounts,
            selectedId: accounts.any((a) => a.id == _accountId)
                ? _accountId
                : accounts.first.id,
            color: tint,
            onSelected: (v) => _changeAccount(v, accounts),
          ),
          if (_type == 'expense' || _refund)
            if (accounts.where((a) => a.id == _accountId).firstOrNull
                case final account?) ...[
              const SizedBox(height: Sp.lg),
              FormLabel(context.l10n.paidWith),
              PaidWithChips(
                account: account,
                instruments:
                    ref.watch(paymentInstrumentsProvider).valueOrNull ?? [],
                instrumentId: _instrumentId,
                method: _method,
                color: tint,
                onChanged: (id, method) => setState(() {
                  _instrumentId = id;
                  _method = method;
                }),
              ),
            ],
          if (_originalNote != null) ...[
            const SizedBox(height: Sp.sm),
            Text(
              _originalNote!,
              style: AppTextStyles.caption.copyWith(color: palette.textLow),
            ),
          ],
          if (_currencyNote != null) ...[
            const SizedBox(height: Sp.sm),
            Text(
              _currencyNote!,
              style: AppTextStyles.caption.copyWith(color: palette.warning),
            ),
          ],
          const SizedBox(height: Sp.lg),
        ],
        FormLabel(context.l10n.category),
        categoriesAsync.when(
          data: (cats) {
            final filtered = cats
                .where((c) => c.type == (_refund ? 'expense' : _type))
                .toList();
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
              onAdd: () => _createCategory(_refund ? 'expense' : _type),
            );
          },
          loading: () => const SizedBox(height: 84),
          error: (error, stackTrace) => const SizedBox(height: 84),
        ),
        if (_type == 'expense' || _refund) ...[
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
          label: context.l10n.saveChanges,
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
    final store = ref.read(financeStoreProvider);
    final details = await store.transactionDetails(out.id);
    final feeDetails = details?['feeId'] == null
        ? null
        : await store.transactionDetails(details!['feeId'] as int);
    final accounts = await db.getAllAccounts();
    if (!mounted) return;
    final saved = await financeForm(
      context,
      title: context.l10n.editLinkedTransfer,
      fields: [
        FinanceField(
          'from',
          context.l10n.fromAccount,
          initial: '${out.accountId}',
          options: {
            for (final a in accounts) '${a.id}': '${a.name} (${a.currency})',
          },
        ),
        FinanceField(
          'to',
          context.l10n.toAccount,
          initial: '${incoming.accountId}',
          options: {
            for (final a in accounts) '${a.id}': '${a.name} (${a.currency})',
          },
        ),
        FinanceField(
          'amount',
          context.l10n.sourceAmount,
          initial: '${details?['sourceAmount'] ?? Amount.fromNum(out.amount)}',
          numeric: true,
        ),
        FinanceField(
          'received',
          context.l10n.destinationAmount,
          initial:
              '${details?['destinationAmount'] ?? Amount.fromNum(incoming.amount)}',
          numeric: true,
        ),
        FinanceField(
          'fee',
          context.l10n.sourceCurrencyFee,
          initial: '${feeDetails?['amount'] ?? 0}',
          required: false,
          numeric: true,
        ),
        FinanceField(
          'date',
          context.l10n.date,
          initial: out.transactionDate.toIso8601String().substring(0, 10),
          date: true,
        ),
        FinanceField(
          'note',
          context.l10n.note,
          initial: out.note ?? '',
          required: false,
        ),
      ],
      save: (j) => ref
          .read(financialLedgerProvider)
          .transfer(
            fromAccountId: int.parse(j['from']!),
            toAccountId: int.parse(j['to']!),
            amount: number(j, 'amount'),
            received: number(j, 'received'),
            fee: j['fee']!.isEmpty ? null : number(j, 'fee'),
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
        title: Text(context.l10n.deleteTransactionTitle2),
        content: Text(context.l10n.deleteTransactionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
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
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(describeError(e))));
                }
              }
            },
            child: Text(
              context.l10n.delete,
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final accounts = ref.read(accountsProvider).valueOrNull ?? const [];
    final currency =
        accounts.where((a) => a.id == _accountId).firstOrNull?.currency ?? '';
    final parsed = AmountParser.parse(
      _amountController.text,
      currency: currency,
    );
    if (!parsed.isValid) {
      setState(() => _amountError = parsed.error);
      return;
    }
    if (!await confirmFutureDate(context, _date)) return;

    setState(() => _submitState = SubmitState.busy);
    try {
      await ref
          .read(financialLedgerProvider)
          .updateCash(
            widget.transaction.id,
            accountId: _accountId,
            amount: parsed.value!,
            type: _type,
            categoryId: _categoryId,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            date: _date,
            expectCurrency: currency,
            instrumentId: Value(
              _type == 'expense' || _refund ? _instrumentId : null,
            ),
            paymentMethod: Value(
              _type == 'expense' || _refund ? _method : null,
            ),
            merchant: Value(_merchantController.text),
          );
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
