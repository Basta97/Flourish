import 'package:flourish/shared/category_label.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/detection/detection_service.dart';
import '../../core/detection/issuers.dart';
import '../../core/detection/parsed_payment.dart';
import '../../core/finance/system_categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/error_text.dart';
import '../../data/database/database.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/liquid_page.dart';
import '../providers/account_providers.dart';
import '../providers/ai_providers.dart';
import '../providers/category_providers.dart';
import '../providers/finance_providers.dart';
import '../wealth/finance_form.dart';
import '../wealth/holdings_view.dart' show number;

String kindLabel(String? kind) => switch (kind) {
  'purchase' => currentL10n.kindPurchase,
  'withdrawal' => currentL10n.kindWithdrawal,
  'transfer_out' => currentL10n.kindMoneySent,
  'transfer_in' => currentL10n.kindMoneyReceived,
  'deposit' => currentL10n.kindDeposit,
  'refund' => currentL10n.kindRefund,
  'bill_payment' => currentL10n.kindBillPayment,
  'card_payment' => currentL10n.kindCardPayment,
  'fee' => currentL10n.kindFee,
  _ => currentL10n.kindPayment,
};

/// Payments found in bank and wallet messages, waiting for a tap.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(detectedPaymentsProvider).valueOrNull ?? const [];
    final pending = rows.where((r) => r.status == 'pending').toList();
    final week = DateTime.now().subtract(const Duration(days: 7));
    final auto = rows
        .where(
          (r) =>
              r.status == 'confirmed' &&
              r.autoConfirmed &&
              (r.resolvedAt?.isAfter(week) ?? false),
        )
        .toList();
    final set = rows
        .where((r) => r.status == 'duplicate' || r.status == 'dismissed')
        .take(30)
        .toList();
    final service = ref.read(detectionServiceProvider);
    final ready = pending.where((r) => _ready(service, r)).toList();
    final aiReady = ref.watch(aiAssistProvider).valueOrNull != null;
    final unclear = pending
        .where((r) => r.confidence < 0.7 && !service.parsedOf(r).aiAssisted)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.paymentsToReviewTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.catchUpTitle,
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push('/catch-up'),
          ),
          IconButton(
            tooltip: context.l10n.detectionSettings,
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push('/settings/detection'),
          ),
        ],
      ),
      body: LiquidPageBackground(
        child: rows.isEmpty
            ? EmptyState(
                icon: Icons.mark_email_unread_outlined,
                title: context.l10n.nothingDetected,
                subtitle: context.l10n.nothingDetectedSubtitle,
                action: FilledButton(
                  onPressed: () => context.push('/settings/detection'),
                  child: Text(context.l10n.setUpDetection),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  Sp.screenH,
                  Sp.lg,
                  Sp.screenH,
                  120,
                ),
                children: [
                  if (aiReady && unclear.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.md),
                      child: OutlinedButton.icon(
                        onPressed: () => askAi(context, ref, [
                          for (final r in unclear) r.id,
                        ]),
                        icon: const Icon(Icons.psychology_alt_outlined),
                        label: Text(context.l10n.checkUnclear(unclear.length)),
                      ),
                    ),
                  if (ready.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.md),
                      child: FilledButton.icon(
                        onPressed: () => _confirmAll(context, ref, ready),
                        icon: const Icon(Icons.done_all_rounded),
                        label: Text(context.l10n.addReady(ready.length)),
                      ),
                    ),
                  if (pending.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.lg),
                      child: Text(
                        context.l10n.allCaughtUp,
                        style: AppTextStyles.body,
                      ),
                    ),
                  for (final r in pending) _DetectedCard(row: r),
                  if (auto.isNotEmpty) ...[
                    _Header(context.l10n.addedAutoThisWeek),
                    for (final r in auto) _DetectedCard(row: r),
                  ],
                  if (set.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        context.l10n.duplicatesDismissed(set.length),
                        style: AppTextStyles.bodyMedium,
                      ),
                      children: [for (final r in set) _DetectedCard(row: r)],
                    ),
                ],
              ),
      ),
    );
  }

  /// Ready for one tap: an account and, when needed, a category (an
  /// existing one or one to create).
  static bool _ready(DetectionService service, DetectedPayment r) =>
      r.accountId != null &&
      r.matchTransactionId == null &&
      (r.categoryId != null ||
          service.proposalOf(r) != null ||
          [
            'transfer_out',
            'transfer_in',
            'withdrawal',
            'card_payment',
          ].contains(r.kind));

  Future<void> _confirmAll(
    BuildContext context,
    WidgetRef ref,
    List<DetectedPayment> rows,
  ) async {
    final service = ref.read(detectionServiceProvider);
    final l = context.l10n;
    var added = 0;
    final problems = <String>[];
    for (final r in rows) {
      try {
        await service.confirm(r.id);
        added++;
      } catch (e) {
        problems.add(describeError(e));
      }
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          problems.isEmpty
              ? l.addedPayments(added)
              : l.addedWithProblems(added, problems.length, problems.first),
        ),
      ),
    );
  }
}

/// Runs the AI stage on [ids] and reports the outcome.
Future<void> askAi(BuildContext context, WidgetRef ref, List<int> ids) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  messenger.showSnackBar(SnackBar(content: Text(l.askingAi)));
  try {
    final changed = await ref
        .read(detectionServiceProvider)
        .assistPending(ids: ids);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            changed == 0 ? l.aiNothingToAdd : l.updatedPayments(changed),
          ),
        ),
      );
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l.aiUnavailable(describeError(e)))),
      );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(Sp.xs, Sp.lg, 0, Sp.sm),
    child: Text(text.toUpperCase(), style: AppTextStyles.eyebrow),
  );
}

class _DetectedCard extends ConsumerWidget {
  const _DetectedCard({required this.row});
  final DetectedPayment row;

  static String _chargeText(
    AsyncValue<ChargeEstimate?> estimate,
    String currency,
  ) {
    final e = estimate.valueOrNull;
    if (e == null) {
      return estimate.isLoading
          ? currentL10n.convertingTo(currency)
          : currentL10n.noRateYetEdit(currency);
    }
    final fee = e.fee > Amount.zero
        ? currentL10n.cardFeePercent('${e.feePercent}')
        : '';
    return '≈ ${CurrencyFormatter.format(e.amount.toDouble(), currency: currency)}'
        '$fee · ${currentL10n.rateEstimate}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = FlourishPalette.of(context);
    final service = ref.read(detectionServiceProvider);
    final p = service.parsedOf(row);
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final account = accounts.where((a) => a.id == row.accountId).firstOrNull;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final category = categories
        .where((c) => c.id == row.categoryId)
        .firstOrNull;
    final proposal = service.proposalOf(row);
    final instrument = (ref.watch(paymentInstrumentsProvider).valueOrNull ?? [])
        .where((i) => i.id == row.instrumentId)
        .firstOrNull;
    final income = row.direction == 'income';
    final currency = row.currency ?? account?.currency ?? '';
    final amount = row.amount == null
        ? '—'
        : '${income ? '+' : '−'}${CurrencyFormatter.format(double.parse(row.amount!), currency: currency)}';
    final foreign =
        account != null &&
        row.currency != null &&
        row.currency != account.currency &&
        p.bookedCurrency != account.currency;
    final when = row.occurredAt ?? row.receivedAt;
    final from = Issuers.byId(p.issuerId)?.name ?? row.sender ?? row.source;
    final details = [
      account?.name ?? context.l10n.chooseAnAccount,
      ?instrument?.label,
      if (category != null) category.displayName,
      if (category == null && proposal != null)
        context.l10n.newProposal(proposal.label),
      DateFormat('d MMM, HH:mm').format(when),
      from,
    ].join(' · ');
    final pending = row.status == 'pending';
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: AppCard(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Sp.lg,
          Sp.md,
          Sp.md,
          Sp.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.merchant ?? kindLabel(row.kind),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: palette.textHigh,
                        ),
                      ),
                      Text(
                        '${kindLabel(row.kind)}'
                        '${p.bookedAmount != null ? context.l10n.chargedAmountLine('${p.bookedCurrency}', '${p.bookedAmount}') : ''}',
                        style: AppTextStyles.caption.copyWith(
                          color: palette.textLow,
                        ),
                      ),
                      if (foreign && pending)
                        Text(
                          _chargeText(
                            ref.watch(detectionChargeProvider(row)),
                            account.currency,
                          ),
                          style: AppTextStyles.caption.copyWith(
                            color: palette.textLow,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  amount,
                  style: AppTextStyles.number.copyWith(
                    color: income ? palette.income : palette.textHigh,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.xs),
            Text(
              details,
              style: AppTextStyles.caption.copyWith(color: palette.textLow),
            ),
            if (row.matchTransactionId != null && pending)
              _Flag(
                context.l10n.maybeEnteredAlready,
                action: context.l10n.sameEntry,
                onAction: () => service.link(row.id, row.matchTransactionId!),
              ),
            if (row.status == 'duplicate') _Flag(context.l10n.sameAsOtherAlert),
            if (p.confidence < 0.7 && pending)
              _Flag(
                context.l10n.unclearMessage,
                action:
                    !p.aiAssisted &&
                        row.rawText != null &&
                        ref.watch(aiAssistProvider).valueOrNull != null
                    ? context.l10n.askAi
                    : null,
                onAction: () => askAi(context, ref, [row.id]),
              ),
            if (p.aiAssisted && pending) _Flag(context.l10n.checkedWithAi),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (row.rawText != null)
                  IconButton(
                    tooltip: context.l10n.showMessage,
                    icon: const Icon(Icons.notes_rounded, size: 20),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(from),
                        content: SelectableText(row.rawText!),
                      ),
                    ),
                  ),
                if (pending) ...[
                  TextButton(
                    onPressed: () => service.dismiss(row.id),
                    child: Text(context.l10n.dismiss),
                  ),
                  TextButton(
                    onPressed: () => _edit(context, ref, p),
                    child: Text(context.l10n.edit),
                  ),
                  FilledButton(
                    onPressed: () => _confirm(context, ref),
                    child: Text(context.l10n.add),
                  ),
                ] else if (row.status == 'confirmed')
                  TextButton(
                    onPressed: () => service.undoConfirm(row.id),
                    child: Text(context.l10n.undo),
                  )
                else
                  TextButton(
                    onPressed: () => service.restore(row.id),
                    child: Text(context.l10n.reviewAgain),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref, [
    DetectionDraft draft = const DetectionDraft(),
  ]) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      final result = await ref
          .read(detectionServiceProvider)
          .confirm(row.id, draft: draft);
      final accountId = draft.accountId ?? row.accountId!;
      final ledger = ref.read(financialLedgerProvider);
      final gap = result.limitDifference;
      if (gap != null) {
        final available = ref.read(detectionServiceProvider).parsedOf(row);
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text(
              l.bankLimitDiffers('${available.availableCredit}', '$gap'),
            ),
            action: SnackBarAction(
              label: l.matchBank,
              onPressed: () async {
                // More available means less owed.
                final owed = await ledger.store.balance(accountId);
                await ledger.reconcile(
                  accountId,
                  owed - gap,
                  l.matchedBankLimit,
                );
              },
            ),
          ),
        );
        return;
      }
      final difference = result.balanceDifference;
      if (difference == null) return;
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            l.bankBalanceDiffers('${row.balanceAfter}', '$difference'),
          ),
          action: SnackBarAction(
            label: l.matchBank,
            onPressed: () async {
              await ledger.reconcile(
                accountId,
                amountOf(row.balanceAfter),
                context.l10n.matchedBankBalance,
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        await _edit(context, ref, null, error: describeError(e));
      }
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ParsedPayment? parsed, {
    String? error,
  }) async {
    final p = parsed ?? ref.read(detectionServiceProvider).parsedOf(row);
    final accounts = ref.read(accountsProvider).valueOrNull ?? const [];
    final categories = SystemCategories.pickable(
      ref.read(categoriesProvider).valueOrNull ?? const [],
    );
    final categoryType = p.kind == 'refund' ? 'expense' : p.direction;
    final moves = [
      'transfer_out',
      'withdrawal',
      'card_payment',
    ].contains(p.kind);
    final receives = [
      'transfer_in',
      'deposit',
      'card_payment',
    ].contains(p.kind);
    final account = accounts.where((a) => a.id == row.accountId).firstOrNull;
    final foreign =
        p.currency != null && account != null && p.currency != account.currency;
    final bankFigure = foreign && p.bookedCurrency == account.currency;
    final saved = await financeForm(
      context,
      title: error ?? context.l10n.reviewPayment,
      fields: [
        FinanceField(
          'account',
          context.l10n.account,
          initial: '${row.accountId ?? ''}',
          options: {
            for (final a in accounts) '${a.id}': '${a.name} (${a.currency})',
          },
        ),
        FinanceField(
          'amount',
          !foreign
              ? context.l10n.amount
              : bankFigure
              ? context.l10n.chargedToAccountPaid(
                  account.currency,
                  '${p.currency}',
                  '${p.amount}',
                )
              : context.l10n.chargedInEmpty(
                  account.currency,
                  '${p.currency}',
                  '${p.amount}',
                ),
          initial: !foreign
              ? (row.amount ?? '')
              : bankFigure
              ? '${p.bookedAmount}'
              : '',
          numeric: true,
          required: !foreign || bankFigure,
        ),
        if (!moves || p.kind == 'card_payment')
          FinanceField(
            'category',
            context.l10n.category,
            initial: '${row.categoryId ?? ''}',
            required: false,
            options: {
              '': ref.read(detectionServiceProvider).proposalOf(row) == null
                  ? context.l10n.automatic
                  : context.l10n.newProposal(
                      ref.read(detectionServiceProvider).proposalOf(row)!.label,
                    ),
              for (final c in categories.where((c) => c.type == categoryType))
                '${c.id}': c.displayName,
            },
          ),
        if (moves)
          FinanceField(
            'to',
            context.l10n.wentToYourAccount,
            initial: '',
            required: false,
            options: {
              '': p.kind == 'transfer_out'
                  ? context.l10n.noSomeoneElse
                  : context.l10n.choose,
              for (final a in accounts) '${a.id}': a.name,
            },
          ),
        if (receives)
          FinanceField(
            'from',
            context.l10n.cameFromYourAccount,
            initial: '',
            required: false,
            options: {
              '': context.l10n.no,
              for (final a in accounts) '${a.id}': a.name,
            },
          ),
        FinanceField(
          'merchant',
          context.l10n.merchantOrPerson,
          initial: row.merchant ?? '',
          required: false,
        ),
      ],
      submit: context.l10n.add,
      save: (j) async {
        int? id(String key) =>
            j[key] == null || j[key]!.isEmpty ? null : int.parse(j[key]!);
        await ref
            .read(detectionServiceProvider)
            .confirm(
              row.id,
              draft: DetectionDraft(
                accountId: id('account'),
                amount: j['amount']!.isEmpty ? null : number(j, 'amount'),
                categoryId: id('category'),
                toAccountId: id('to'),
                fromAccountId: id('from'),
                merchant: j['merchant']!.isEmpty ? null : j['merchant'],
              ),
            );
      },
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.paymentAdded)));
    }
  }
}

class _Flag extends StatelessWidget {
  const _Flag(this.text, {this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Sp.xs),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: palette.warning),
          const SizedBox(width: Sp.xs),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(color: palette.warning),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}
