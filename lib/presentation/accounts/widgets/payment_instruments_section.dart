import 'package:flourish/l10n/l10n.dart';
import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/detection/issuers.dart';
import '../../../core/finance/payment_methods.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/database/database.dart';
import '../../../shared/widgets/app_card.dart';
import '../../providers/finance_providers.dart';
import '../../providers/database_provider.dart';
import '../../wealth/finance_form.dart';
import '../../wealth/holdings_view.dart' show number;

/// Cards and wallets that pay from [account], with add/edit.
class PaymentInstrumentsSection extends ConsumerWidget {
  const PaymentInstrumentsSection({super.key, required this.account});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = FlourishPalette.of(context);
    final items = (ref.watch(paymentInstrumentsProvider).valueOrNull ?? [])
        .where((i) => i.accountId == account.id)
        .toList();
    return AppCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Sp.lg, Sp.md, Sp.sm, Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.cardsWallets,
                  style: AppTextStyles.title,
                ),
              ),
              TextButton.icon(
                onPressed: () => editPaymentInstrument(context, ref, account),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.l10n.add),
              ),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: Sp.md,
                bottom: Sp.xs,
              ),
              child: Text(
                context.l10n.cardsWalletsHelp,
                style: AppTextStyles.caption.copyWith(color: palette.textLow),
              ),
            ),
          for (final i in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(_icon(i.kind), color: palette.textHigh),
              title: Text(
                i.label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: i.archived ? palette.textLow : palette.textHigh,
                  decoration: i.archived ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                [
                  PaymentMethods.label(i.kind),
                  if (i.isDefault) context.l10n.defaultLower,
                  if (i.termsJson?['fxFeePercent'] != null)
                    context.l10n.fxFee('${i.termsJson!['fxFeePercent']}'),
                ].join(' · '),
                style: AppTextStyles.caption.copyWith(color: palette.textLow),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => editPaymentInstrument(context, ref, account, i),
            ),
        ],
      ),
    );
  }
}

IconData _icon(String kind) => switch (kind) {
  'credit_card' || 'debit_card' || 'prepaid_card' => Icons.credit_card_rounded,
  'mobile_wallet' => Icons.phone_android_rounded,
  'instapay' => Icons.bolt_rounded,
  'bank_transfer' => Icons.account_balance_rounded,
  'bnpl' => Icons.calendar_month_rounded,
  _ => Icons.payments_outlined,
};

Future<void> editPaymentInstrument(
  BuildContext context,
  WidgetRef ref,
  Account account, [
  PaymentInstrument? existing,
]) async {
  final kinds = {
    for (final k in PaymentMethods.instrumentKinds)
      if (PaymentMethods.fitsAccount(k, account.type))
        k: PaymentMethods.label(k),
  };
  if (kinds.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.cashNoCards)));
    return;
  }
  await financeForm(
    context,
    title: existing == null
        ? context.l10n.addCardOrWallet
        : context.l10n.editNamed(existing.name),
    fields: [
      FinanceField(
        'name',
        context.l10n.instrumentName,
        initial: existing?.name ?? account.name,
      ),
      FinanceField(
        'kind',
        context.l10n.type,
        initial: existing?.kind ?? kinds.keys.first,
        options: kinds,
      ),
      FinanceField(
        'network',
        context.l10n.cardNetwork,
        initial: existing?.network ?? '',
        required: false,
        options: {
          '': context.l10n.noneNotCard,
          for (final n in PaymentMethods.networks)
            n: PaymentMethods.networkLabel(n),
        },
      ),
      FinanceField(
        'last4',
        context.l10n.last4Digits,
        initial: existing?.last4 ?? '',
        required: false,
        numeric: true,
      ),
      FinanceField(
        'issuer',
        context.l10n.bankOrWallet,
        initial: existing?.issuer ?? '',
        required: false,
        options: {
          '': context.l10n.other,
          for (final i in Issuers.all) i.id: i.name,
        },
      ),
      FinanceField(
        'handle',
        context.l10n.walletHandle,
        initial: existing?.handle ?? '',
        required: false,
      ),
      FinanceField(
        'fx',
        context.l10n.foreignFeeOptional,
        initial: '${existing?.termsJson?['fxFeePercent'] ?? ''}',
        required: false,
        numeric: true,
      ),
      FinanceField(
        'default',
        context.l10n.defaultForAccount,
        initial: existing?.isDefault == true ? 'yes' : 'no',
        options: {'no': context.l10n.no, 'yes': context.l10n.yes},
      ),
      if (existing != null)
        FinanceField(
          'archived',
          context.l10n.status,
          initial: existing.archived ? 'yes' : 'no',
          options: {'no': context.l10n.inUse, 'yes': context.l10n.archived},
        ),
    ],
    save: (j) async {
      String? opt(String key) => j[key]!.isEmpty ? null : j[key];
      final terms = {
        ...?existing?.termsJson,
        if (opt('fx') != null) 'fxFeePercent': '${number(j, 'fx')}',
      };
      if (opt('fx') == null) terms.remove('fxFeePercent');
      final last4 = opt('last4');
      await ref
          .read(databaseProvider)
          .savePaymentInstrument(
            PaymentInstrumentsCompanion(
              id: existing == null ? const Value.absent() : Value(existing.id),
              accountId: Value(account.id),
              name: Value(j['name']!),
              kind: Value(j['kind']!),
              network: Value(opt('network')),
              last4: Value(
                last4 == null ? null : TextNormalizer.digits(last4).trim(),
              ),
              issuer: Value(opt('issuer')),
              handle: Value(opt('handle')),
              terms: Value(terms.isEmpty ? null : jsonEncode(terms)),
              isDefault: Value(j['default'] == 'yes'),
              archived: Value(j['archived'] == 'yes'),
            ),
          );
    },
  );
}
