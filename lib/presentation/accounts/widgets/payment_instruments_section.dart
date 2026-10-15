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
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.sm, Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Cards & wallets', style: AppTextStyles.title),
              ),
              TextButton.icon(
                onPressed: () => editPaymentInstrument(context, ref, account),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: Sp.md, bottom: Sp.xs),
              child: Text(
                'Add the cards and wallets that pay from this account so '
                'spending shows what paid and detected payments find the '
                'right account.',
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
                  if (i.isDefault) 'default',
                  if (i.termsJson?['fxFeePercent'] != null)
                    'FX fee ${i.termsJson!['fxFeePercent']}%',
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cash accounts have no cards or wallets')),
    );
    return;
  }
  await financeForm(
    context,
    title: existing == null ? 'Add card or wallet' : 'Edit ${existing.name}',
    fields: [
      FinanceField(
        'name',
        'Name (e.g. CIB Visa)',
        initial: existing?.name ?? account.name,
      ),
      FinanceField(
        'kind',
        'Type',
        initial: existing?.kind ?? kinds.keys.first,
        options: kinds,
      ),
      FinanceField(
        'network',
        'Card network',
        initial: existing?.network ?? '',
        required: false,
        options: {
          '': 'None / not a card',
          for (final n in PaymentMethods.networks)
            n: PaymentMethods.networkLabel(n),
        },
      ),
      FinanceField(
        'last4',
        'Last 4 digits (matches bank messages)',
        initial: existing?.last4 ?? '',
        required: false,
        numeric: true,
      ),
      FinanceField(
        'issuer',
        'Bank or wallet',
        initial: existing?.issuer ?? '',
        required: false,
        options: {'': 'Other', for (final i in Issuers.all) i.id: i.name},
      ),
      FinanceField(
        'handle',
        'Wallet number or InstaPay address',
        initial: existing?.handle ?? '',
        required: false,
      ),
      FinanceField(
        'fx',
        'Foreign transaction fee, % (optional)',
        initial: '${existing?.termsJson?['fxFeePercent'] ?? ''}',
        required: false,
        numeric: true,
      ),
      FinanceField(
        'default',
        'Default for this account',
        initial: existing?.isDefault == true ? 'yes' : 'no',
        options: const {'no': 'No', 'yes': 'Yes'},
      ),
      if (existing != null)
        FinanceField(
          'archived',
          'Status',
          initial: existing.archived ? 'yes' : 'no',
          options: const {'no': 'In use', 'yes': 'Archived'},
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
