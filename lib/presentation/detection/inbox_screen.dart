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
import '../providers/category_providers.dart';
import '../providers/finance_providers.dart';
import '../wealth/finance_form.dart';
import '../wealth/holdings_view.dart' show number;

String kindLabel(String? kind) => switch (kind) {
  'purchase' => 'Purchase',
  'withdrawal' => 'Cash withdrawal',
  'transfer_out' => 'Money sent',
  'transfer_in' => 'Money received',
  'deposit' => 'Deposit',
  'refund' => 'Refund',
  'bill_payment' => 'Bill payment',
  'card_payment' => 'Card payment',
  'fee' => 'Fee',
  _ => 'Payment',
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
    final ready = pending.where(_ready).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments to review'),
        actions: [
          IconButton(
            tooltip: 'Detection settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push('/settings/detection'),
          ),
        ],
      ),
      body: LiquidPageBackground(
        child: rows.isEmpty
            ? EmptyState(
                icon: Icons.mark_email_unread_outlined,
                title: 'Nothing detected yet',
                subtitle:
                    'Turn on payment detection to collect bank and wallet '
                    'alerts here, or paste an alert.',
                action: FilledButton(
                  onPressed: () => context.push('/settings/detection'),
                  child: const Text('Set up detection'),
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
                  if (ready.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.md),
                      child: FilledButton.icon(
                        onPressed: () => _confirmAll(context, ref, ready),
                        icon: const Icon(Icons.done_all_rounded),
                        label: Text('Add ${ready.length} ready payments'),
                      ),
                    ),
                  if (pending.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.lg),
                      child: Text('All caught up.', style: AppTextStyles.body),
                    ),
                  for (final r in pending) _DetectedCard(row: r),
                  if (auto.isNotEmpty) ...[
                    _Header('Added automatically this week'),
                    for (final r in auto) _DetectedCard(row: r),
                  ],
                  if (set.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Duplicates and dismissed (${set.length})',
                        style: AppTextStyles.bodyMedium,
                      ),
                      children: [for (final r in set) _DetectedCard(row: r)],
                    ),
                ],
              ),
      ),
    );
  }

  /// Ready for one tap: an account and, when needed, a category.
  static bool _ready(DetectedPayment r) =>
      r.accountId != null &&
      r.matchTransactionId == null &&
      (r.categoryId != null ||
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
              ? 'Added $added payments'
              : 'Added $added; ${problems.length} need a look: ${problems.first}',
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.lg, 0, Sp.sm),
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
          ? 'Converting to $currency…'
          : 'No exchange rate yet · tap Edit to enter the $currency amount';
    }
    final fee = e.fee > Amount.zero ? ' + ${e.feePercent}% card fee' : '';
    return '≈ ${CurrencyFormatter.format(e.amount.toDouble(), currency: currency)}'
        '$fee · exchange rate estimate';
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
      account?.name ?? 'Choose an account',
      ?instrument?.label,
      if (category != null) category.name,
      DateFormat('d MMM, HH:mm').format(when),
      from,
    ].join(' · ');
    final pending = row.status == 'pending';
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.md, Sp.sm),
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
                        '${p.bookedAmount != null ? ' · charged ${p.bookedCurrency} ${p.bookedAmount}' : ''}',
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
                'You may have entered this already',
                action: 'Same entry',
                onAction: () => service.link(row.id, row.matchTransactionId!),
              ),
            if (row.status == 'duplicate')
              const _Flag('Same payment as another alert'),
            if (p.confidence < 0.7 && pending)
              const _Flag('Unclear message: check the details'),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (row.rawText != null)
                  IconButton(
                    tooltip: 'Show message',
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
                    child: const Text('Dismiss'),
                  ),
                  TextButton(
                    onPressed: () => _edit(context, ref, p),
                    child: const Text('Edit'),
                  ),
                  FilledButton(
                    onPressed: () => _confirm(context, ref),
                    child: const Text('Add'),
                  ),
                ] else if (row.status == 'confirmed')
                  TextButton(
                    onPressed: () => service.undoConfirm(row.id),
                    child: const Text('Undo'),
                  )
                else
                  TextButton(
                    onPressed: () => service.restore(row.id),
                    child: const Text('Review again'),
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
    try {
      final result = await ref
          .read(detectionServiceProvider)
          .confirm(row.id, draft: draft);
      final difference = result.balanceDifference;
      if (difference == null) return;
      final accountId = draft.accountId ?? row.accountId!;
      final ledger = ref.read(financialLedgerProvider);
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            'The bank says your balance is ${row.balanceAfter}; Flourish '
            'differs by $difference.',
          ),
          action: SnackBarAction(
            label: 'Match bank',
            onPressed: () async {
              await ledger.reconcile(
                accountId,
                amountOf(row.balanceAfter),
                'Matched balance in bank message',
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
      title: error ?? 'Review payment',
      fields: [
        FinanceField(
          'account',
          'Account',
          initial: '${row.accountId ?? ''}',
          options: {
            for (final a in accounts) '${a.id}': '${a.name} (${a.currency})',
          },
        ),
        FinanceField(
          'amount',
          !foreign
              ? 'Amount'
              : bankFigure
              ? 'Charged to the account (${account.currency}); paid ${p.currency} ${p.amount}'
              : 'Charged in ${account.currency} (empty: exchange rate + card fee); '
                    'paid ${p.currency} ${p.amount}',
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
            'Category',
            initial: '${row.categoryId ?? ''}',
            required: false,
            options: {
              '': 'Automatic',
              for (final c in categories.where((c) => c.type == categoryType))
                '${c.id}': c.name,
            },
          ),
        if (moves)
          FinanceField(
            'to',
            'Went to one of your accounts?',
            initial: '',
            required: false,
            options: {
              '': p.kind == 'transfer_out' ? 'No, someone else' : 'Choose',
              for (final a in accounts) '${a.id}': a.name,
            },
          ),
        if (receives)
          FinanceField(
            'from',
            'Came from one of your accounts?',
            initial: '',
            required: false,
            options: {'': 'No', for (final a in accounts) '${a.id}': a.name},
          ),
        FinanceField(
          'merchant',
          'Merchant or person',
          initial: row.merchant ?? '',
          required: false,
        ),
      ],
      submit: 'Add',
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
      ).showSnackBar(const SnackBar(content: Text('Payment added')));
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
