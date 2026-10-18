import 'package:flourish/l10n/l10n.dart';
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
            Text(context.l10n.cardDetails, style: AppTextStyles.title),
            const SizedBox(height: Sp.xs),
            Text(
              context.l10n.cardDetailsHelp,
              style: AppTextStyles.body.copyWith(color: palette.textLow),
            ),
            const SizedBox(height: Sp.md),
            FilledButton.icon(
              onPressed: () => editCardTerms(context, ref, account),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Text(context.l10n.setUpCardTerms),
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
              Expanded(
                child: Text(context.l10n.credit, style: AppTextStyles.title),
              ),
              IconButton(
                tooltip: context.l10n.editCardTerms,
                icon: const Icon(Icons.tune_rounded, size: 20),
                onPressed: () => editCardTerms(context, ref, account),
              ),
            ],
          ),
          _Row(context.l10n.available, fmt(status.available), strong: true),
          _Row(
            context.l10n.limit,
            status.limit == null ? '—' : fmt(status.limit!),
          ),
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
            '${context.l10n.limitUsed((utilization * 100).toStringAsFixed(0))}'
            '${utilization > 0.3 ? ' · ${context.l10n.under30Tip}' : ''}',
            style: AppTextStyles.caption.copyWith(color: palette.textLow),
          ),
          if (status.overLimitBy > Amount.zero)
            Padding(
              padding: const EdgeInsets.only(top: Sp.xs),
              child: Text(
                context.l10n.overLimitBy(fmt(status.overLimitBy)),
                style: AppTextStyles.caption.copyWith(color: AppColors.danger),
              ),
            ),
          if (status.intlLimit != null) ...[
            const SizedBox(height: Sp.sm),
            _Row(context.l10n.availableAbroad, fmt(status.intlAvailable!)),
            _Row(context.l10n.intlLimit, fmt(status.intlLimit!)),
            if (status.intlOverLimitBy > Amount.zero)
              Text(
                context.l10n.overIntlLimitBy(fmt(status.intlOverLimitBy)),
                style: AppTextStyles.caption.copyWith(color: AppColors.danger),
              ),
          ],
          for (final (reported, said) in [
            (status.bankAvailable, context.l10n.bankSaidAvailable),
            (status.bankIntlAvailable, context.l10n.bankSaidIntlAvailable),
          ])
            if (reported != null)
              Padding(
                padding: const EdgeInsets.only(top: Sp.xs),
                child: Text(
                  said(
                    DateFormat.MMMd().format(reported.at),
                    fmt(reported.value),
                  ),
                  style: AppTextStyles.caption.copyWith(color: palette.textLow),
                ),
              ),
          const Divider(height: Sp.xl),
          _Row(context.l10n.lastStatement, fmt(status.statementBalance)),
          _Row(context.l10n.stillToPay, fmt(status.statementRemaining)),
          _Row(
            dueText.isEmpty
                ? context.l10n.minimumDue
                : context.l10n.minimumDueBy(dueText),
            fmt(status.minimumDue),
            strong: status.minimumDue > Amount.zero,
          ),
          if (status.interestEstimate > Amount.zero)
            _Row(
              context.l10n.interestIfUnpaid,
              fmt(status.interestEstimate),
              tone: palette.warning,
            ),
          if (status.cashAdvanceBalance > Amount.zero)
            _Row(context.l10n.cashAdvances, fmt(status.cashAdvanceBalance)),
          const SizedBox(height: Sp.md),
          Wrap(
            spacing: Sp.sm,
            runSpacing: Sp.sm,
            children: [
              FilledButton.icon(
                onPressed: () => payCard(context, ref, account, status),
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: Text(context.l10n.payCard),
              ),
              OutlinedButton.icon(
                onPressed: () => recordCardCharge(context, ref, account),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.l10n.interestOrFee),
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
    title: context.l10n.termsOf(account.name),
    fields: [
      FinanceField(
        'limit',
        context.l10n.creditLimitIn(account.currency),
        initial: v(t?.creditLimit, ''),
        numeric: true,
      ),
      FinanceField(
        'intl',
        context.l10n.intlLimitIn(account.currency),
        initial: v(t?.intlLimit, ''),
        numeric: true,
        required: false,
      ),
      FinanceField(
        'apr',
        context.l10n.purchaseInterest,
        initial: v(contract?.annualRate, ''),
        numeric: true,
      ),
      FinanceField(
        'statement',
        context.l10n.statementClosingDay,
        initial: '${contract?.statementDay ?? 25}',
        numeric: true,
      ),
      FinanceField(
        'due',
        context.l10n.paymentDueDay,
        initial: '${contract?.paymentDay ?? 10}',
        numeric: true,
      ),
      FinanceField(
        'minPct',
        context.l10n.minimumPaymentPercent,
        initial: v(t?.minPaymentPercent, '5'),
        numeric: true,
      ),
      FinanceField(
        'minFloor',
        context.l10n.minimumPaymentAtLeast(account.currency),
        initial: v(t?.minPaymentFloor, '0'),
        numeric: true,
      ),
      FinanceField(
        'fx',
        context.l10n.foreignFeePercent,
        initial: v(t?.fxFeePercent, '0'),
        numeric: true,
      ),
      FinanceField(
        'cashPct',
        context.l10n.cashAdvanceFee,
        initial: v(t?.cashAdvanceFeePercent, '0'),
        numeric: true,
      ),
      FinanceField(
        'cashMin',
        context.l10n.cashAdvanceFeeMin(account.currency),
        initial: v(t?.cashAdvanceFeeMin, '0'),
        numeric: true,
      ),
      FinanceField(
        'cashApr',
        context.l10n.cashAdvanceInterest,
        initial: v(t?.cashAdvanceApr, '0'),
        numeric: true,
      ),
      FinanceField(
        'late',
        context.l10n.latePaymentFeeIn(account.currency),
        initial: v(t?.lateFee, '0'),
        numeric: true,
      ),
    ],
    save: (j) => service.saveTerms(
      account.id,
      terms: CardTerms(
        creditLimit: number(j, 'limit'),
        intlLimit: j['intl']!.trim().isEmpty ? null : number(j, 'intl'),
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
      SnackBar(content: Text(context.l10n.addAccountToPayFrom(card.currency))),
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
    title: context.l10n.payNamed(card.name),
    fields: [
      FinanceField(
        'from',
        context.l10n.payFrom,
        initial: '${accounts.first.id}',
        options: {for (final a in accounts) '${a.id}': a.name},
      ),
      FinanceField(
        'amount',
        context.l10n.amountMinimum('${status.minimumDue}'),
        initial: suggested > Amount.zero ? '$suggested' : '',
        numeric: true,
      ),
      FinanceField('date', context.l10n.date, initial: today(), date: true),
    ],
    submit: context.l10n.pay,
    save: (j) => ref
        .read(financialLedgerProvider)
        .transfer(
          fromAccountId: int.parse(j['from']!),
          toAccountId: card.id,
          amount: number(j, 'amount'),
          date: DateTime.parse(j['date']!),
          note: currentL10n.cardPaymentNote(card.name),
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
  title: context.l10n.chargeOn(card.name),
  fields: [
    FinanceField(
      'kind',
      context.l10n.charge,
      initial: 'interest',
      options: {
        'interest': context.l10n.interest,
        'late': context.l10n.latePaymentFee,
        'annual': context.l10n.annualFee,
        'other': context.l10n.otherBankFee,
      },
    ),
    FinanceField('amount', context.l10n.amountIn(card.currency), numeric: true),
    FinanceField(
      'date',
      context.l10n.statementDate,
      initial: today(),
      date: true,
    ),
  ],
  save: (j) => ref
      .read(financialLedgerProvider)
      .recordCash(
        accountId: card.id,
        amount: number(j, 'amount'),
        type: 'expense',
        kind: j['kind'] == 'interest' ? 'contractInterest' : 'fee',
        note: switch (j['kind']) {
          'interest' => currentL10n.cardInterest,
          'late' => currentL10n.latePaymentFee,
          'annual' => currentL10n.annualCardFee,
          _ => currentL10n.cardFee,
        },
        date: DateTime.parse(j['date']!),
        extra: {'feeType': j['kind']},
      ),
);
