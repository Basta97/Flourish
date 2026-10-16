import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/finance/credit_card_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/database/database.dart';
import '../../../shared/widgets/app_card.dart';
import '../../providers/account_providers.dart';
import '../../providers/finance_providers.dart';
import '../../wealth/finance_form.dart';
import '../../wealth/holdings_view.dart' show number, today;

/// Limit, available credit, statement, minimum due and interest for a credit
/// card account, with the actions that keep it accurate.
class CreditCardPanel extends ConsumerWidget {
  const CreditCardPanel({super.key, required this.account});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = FlourishPalette.of(context);
    final status = ref.watch(creditStatusProvider(account.id)).valueOrNull;
    String fmt(Amount v) =>
        CurrencyFormatter.format(v.toDouble(), currency: account.currency);
    if (status == null) return const SizedBox(height: 120);
    if (!status.hasTerms) {
      return AppCard(
        padding: const EdgeInsets.all(Sp.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Card details', style: AppTextStyles.title),
            const SizedBox(height: Sp.xs),
            Text(
              'Add the limit, statement and due days and fees to see '
              'available credit, the minimum payment and interest.',
              style: AppTextStyles.body.copyWith(color: palette.textLow),
            ),
            const SizedBox(height: Sp.md),
            FilledButton.icon(
              onPressed: () => editCardTerms(context, ref, account),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Set up card terms'),
            ),
          ],
        ),
      );
    }
    final utilization = status.utilization ?? 0;
    final tone = utilization >= 0.9
        ? AppColors.danger
        : utilization >= 0.3
        ? palette.warning
        : palette.income;
    final dueText = status.due == null
        ? ''
        : DateFormat.MMMd().format(status.due!);
    return AppCard(
      padding: const EdgeInsets.all(Sp.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Credit', style: AppTextStyles.title)),
              IconButton(
                tooltip: 'Edit card terms',
                icon: const Icon(Icons.tune_rounded, size: 20),
                onPressed: () => editCardTerms(context, ref, account),
              ),
            ],
          ),
          _Row('Available', fmt(status.available), strong: true),
          _Row('Limit', status.limit == null ? '—' : fmt(status.limit!)),
          const SizedBox(height: Sp.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Rad.full),
            child: LinearProgressIndicator(
              value: utilization.clamp(0, 1).toDouble(),
              minHeight: 8,
              color: tone,
              backgroundColor: palette.stroke,
            ),
          ),
          const SizedBox(height: Sp.xs),
          Text(
            '${(utilization * 100).toStringAsFixed(0)}% of the limit used'
            '${utilization > 0.3 ? ' · keeping it under 30% helps your credit' : ''}',
            style: AppTextStyles.caption.copyWith(color: palette.textLow),
          ),
          if (status.overLimitBy > Amount.zero)
            Padding(
              padding: const EdgeInsets.only(top: Sp.xs),
              child: Text(
                'Over the limit by ${fmt(status.overLimitBy)}',
                style: AppTextStyles.caption.copyWith(color: AppColors.danger),
              ),
            ),
          const Divider(height: Sp.xl),
          _Row('Last statement', fmt(status.statementBalance)),
          _Row('Still to pay', fmt(status.statementRemaining)),
          _Row(
            'Minimum due${dueText.isEmpty ? '' : ' by $dueText'}',
            fmt(status.minimumDue),
            strong: status.minimumDue > Amount.zero,
          ),
          if (status.interestEstimate > Amount.zero)
            _Row(
              'Interest if unpaid (est.)',
              fmt(status.interestEstimate),
              tone: palette.warning,
            ),
          if (status.cashAdvanceBalance > Amount.zero)
            _Row('Cash advances', fmt(status.cashAdvanceBalance)),
          const SizedBox(height: Sp.md),
          Wrap(
            spacing: Sp.sm,
            runSpacing: Sp.sm,
            children: [
              FilledButton.icon(
                onPressed: () => payCard(context, ref, account, status),
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Pay card'),
              ),
              OutlinedButton.icon(
                onPressed: () => recordCardCharge(context, ref, account),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Interest or fee'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.strong = false, this.tone});
  final String label, value;
  final bool strong;
  final Color? tone;
  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(color: palette.textLow),
            ),
          ),
          Text(
            value,
            style: (strong ? AppTextStyles.number : AppTextStyles.numberSmall)
                .copyWith(color: tone ?? palette.textHigh),
          ),
        ],
      ),
    );
  }
}

/// Edits a card's limit, billing days, APR and fees.
Future<void> editCardTerms(
  BuildContext context,
  WidgetRef ref,
  Account account,
) async {
  final service = ref.read(creditCardServiceProvider);
  final contract = await service.contractFor(account.id);
  final t = contract?.card;
  if (!context.mounted) return;
  String v(Amount? a, String fallback) => a == null ? fallback : '$a';
  await financeForm(
    context,
    title: '${account.name} terms',
    fields: [
      FinanceField(
        'limit',
        'Credit limit (${account.currency})',
        initial: v(t?.creditLimit, ''),
        numeric: true,
      ),
      FinanceField(
        'apr',
        'Purchase interest, % a year',
        initial: v(contract?.annualRate, ''),
        numeric: true,
      ),
      FinanceField(
        'statement',
        'Statement closing day (1–31)',
        initial: '${contract?.statementDay ?? 25}',
        numeric: true,
      ),
      FinanceField(
        'due',
        'Payment due day (1–31)',
        initial: '${contract?.paymentDay ?? 10}',
        numeric: true,
      ),
      FinanceField(
        'minPct',
        'Minimum payment, % of statement',
        initial: v(t?.minPaymentPercent, '5'),
        numeric: true,
      ),
      FinanceField(
        'minFloor',
        'Minimum payment at least (${account.currency})',
        initial: v(t?.minPaymentFloor, '0'),
        numeric: true,
      ),
      FinanceField(
        'fx',
        'Foreign transaction fee, %',
        initial: v(t?.fxFeePercent, '0'),
        numeric: true,
      ),
      FinanceField(
        'cashPct',
        'Cash advance fee, %',
        initial: v(t?.cashAdvanceFeePercent, '0'),
        numeric: true,
      ),
      FinanceField(
        'cashMin',
        'Cash advance fee at least (${account.currency})',
        initial: v(t?.cashAdvanceFeeMin, '0'),
        numeric: true,
      ),
      FinanceField(
        'cashApr',
        'Cash advance interest, % a year',
        initial: v(t?.cashAdvanceApr, '0'),
        numeric: true,
      ),
      FinanceField(
        'late',
        'Late payment fee (${account.currency})',
        initial: v(t?.lateFee, '0'),
        numeric: true,
      ),
    ],
    save: (j) => service.saveTerms(
      account.id,
      terms: CardTerms(
        creditLimit: number(j, 'limit'),
        minPaymentPercent: number(j, 'minPct'),
        minPaymentFloor: number(j, 'minFloor'),
        fxFeePercent: number(j, 'fx'),
        cashAdvanceFeePercent: number(j, 'cashPct'),
        cashAdvanceFeeMin: number(j, 'cashMin'),
        cashAdvanceApr: number(j, 'cashApr'),
        lateFee: number(j, 'late'),
      ),
      purchaseApr: number(j, 'apr'),
      statementDay: number(j, 'statement').toDouble().toInt(),
      paymentDay: number(j, 'due').toDouble().toInt(),
    ),
  );
}

/// Pays the card from another account, prefilled with what is still owed
/// on the last statement.
Future<void> payCard(
  BuildContext context,
  WidgetRef ref,
  Account card,
  CreditStatus status,
) async {
  final accounts = (ref.read(accountsProvider).valueOrNull ?? const [])
      .where((a) => a.type != 'credit' && a.currency == card.currency)
      .toList();
  if (accounts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Add a ${card.currency} bank or cash account to pay from',
        ),
      ),
    );
    return;
  }
  final suggested = status.statementRemaining > Amount.zero
      ? status.statementRemaining
      : status.owed > Amount.zero
      ? status.owed
      : Amount.zero;
  await financeForm(
    context,
    title: 'Pay ${card.name}',
    fields: [
      FinanceField(
        'from',
        'Pay from',
        initial: '${accounts.first.id}',
        options: {for (final a in accounts) '${a.id}': a.name},
      ),
      FinanceField(
        'amount',
        'Amount (minimum ${status.minimumDue})',
        initial: suggested > Amount.zero ? '$suggested' : '',
        numeric: true,
      ),
      FinanceField('date', 'Date', initial: today(), date: true),
    ],
    submit: 'Pay',
    save: (j) => ref
        .read(financialLedgerProvider)
        .transfer(
          fromAccountId: int.parse(j['from']!),
          toAccountId: card.id,
          amount: number(j, 'amount'),
          date: DateTime.parse(j['date']!),
          note: 'Card payment: ${card.name}',
        ),
  );
}

/// Records interest, a late fee or another charge the bank put on the card.
Future<void> recordCardCharge(
  BuildContext context,
  WidgetRef ref,
  Account card,
) => financeForm(
  context,
  title: 'Charge on ${card.name}',
  fields: [
    const FinanceField(
      'kind',
      'Charge',
      initial: 'interest',
      options: {
        'interest': 'Interest',
        'late': 'Late payment fee',
        'annual': 'Annual fee',
        'other': 'Other bank fee',
      },
    ),
    FinanceField('amount', 'Amount (${card.currency})', numeric: true),
    FinanceField('date', 'Statement date', initial: today(), date: true),
  ],
  save: (j) => ref
      .read(financialLedgerProvider)
      .recordCash(
        accountId: card.id,
        amount: number(j, 'amount'),
        type: 'expense',
        kind: j['kind'] == 'interest' ? 'contractInterest' : 'fee',
        note: switch (j['kind']) {
          'interest' => 'Card interest',
          'late' => 'Late payment fee',
          'annual' => 'Annual card fee',
          _ => 'Card fee',
        },
        date: DateTime.parse(j['date']!),
        extra: {'feeType': j['kind']},
      ),
);
