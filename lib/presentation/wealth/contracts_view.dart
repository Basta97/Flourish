import 'package:flourish/l10n/l10n.dart';
import '../accounts/widgets/credit_card_panel.dart' show payCard;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/finance_providers.dart';
import '../providers/account_providers.dart';
import '../providers/theme_providers.dart';
import '../../data/finance/finance_store.dart';
import 'finance_form.dart';
import 'holdings_view.dart';
import 'widgets/asset_tile.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../shared/widgets/shimmer_loading.dart';

class ContractsView extends ConsumerWidget {
  const ContractsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
    children: [
      FilledButton.icon(
        onPressed: () => addContract(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.addContractOrDebt),
      ),
      Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: WealthHint(context.l10n.expectedPaymentsNote),
      ),
      ...ref
          .watch(contractsProvider)
          .when(
            data: (items) => items.isEmpty
                ? <Widget>[]
                : [
                    AssetGroup(
                      children: [
                        for (final c in items)
                          () {
                            final (icon, tint) = contractStyle(c.kind);
                            return AssetTile(
                              key: ValueKey(c.id),
                              icon: icon,
                              tint: tint,
                              title: c.name,
                              subtitle:
                                  '${contractKindLabel(context.l10n, c.kind)}${c.counterparty.isEmpty ? '' : ' · ${c.counterparty}'}\n${context.l10n.ratesMatures('${c.annualRate}', c.maturity.toIso8601String().substring(0, 10))}',
                              // A card's debt lives on its account, not
                              // in the contract's principal.
                              value: CurrencyFormatter.format(
                                c.kind == ContractKind.creditCard
                                    ? (ref
                                                  .watch(accountsProvider)
                                                  .valueOrNull
                                                  ?.where(
                                                    (a) =>
                                                        a.id == c.cardAccountId,
                                                  )
                                                  .firstOrNull
                                                  ?.balance ??
                                              0)
                                          .toDouble()
                                    : c.principal.toDouble(),
                                currency: c.currency,
                              ),
                              valueTone: c.isDebt ? AppColors.expense : null,
                              secondary: c.isDebt
                                  ? context.l10n.owed
                                  : context.l10n.principal,
                              // Root navigator so the detail page covers the
                              // floating nav bar.
                              onTap: () =>
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ContractDetailScreen(contract: c),
                                    ),
                                  ),
                            );
                          }(),
                      ],
                    ),
                  ],
            loading: () => [
              for (var i = 0; i < 3; i++) ShimmerLoading.listItem(),
            ],
            error: (e, _) => [Text('$e')],
          ),
    ],
  );
}

Future<void> addContract(BuildContext context, WidgetRef ref) async {
  final accounts = ref.read(accountsProvider).valueOrNull ?? [];
  await financeForm(
    context,
    title: context.l10n.addContractObligation,
    fields: [
      FinanceField('name', context.l10n.name),
      FinanceField(
        'kind',
        context.l10n.type,
        initial: 'certificate',
        options: {
          for (final k in ContractKind.values)
            k.name: contractKindLabel(context.l10n, k),
        },
      ),
      FinanceField(
        'currency',
        context.l10n.currency,
        initial: ref.read(defaultCurrencyProvider),
        options: currencies,
        currency: true,
      ),
      FinanceField('principal', context.l10n.existingPrincipal, numeric: true),
      FinanceField(
        'rate',
        context.l10n.annualInterestCoupon,
        initial: '0',
        numeric: true,
      ),
      FinanceField('counterparty', context.l10n.counterparty, required: false),
      FinanceField(
        'method',
        context.l10n.interestConvention,
        initial: 'flat',
        options: {
          'flat': context.l10n.flatRate,
          'reducing': context.l10n.reducingBalance,
          'manual': context.l10n.manualSchedule,
        },
      ),
      FinanceField(
        'frequency',
        context.l10n.paymentsPerYear,
        initial: '12',
        options: {
          '12': context.l10n.monthly,
          '4': context.l10n.quarterly,
          '2': context.l10n.halfYearly,
          '1': context.l10n.yearly,
        },
      ),
      FinanceField(
        'start',
        context.l10n.startDate,
        initial: today(),
        date: true,
      ),
      FinanceField(
        'maturity',
        context.l10n.maturityDate,
        initial: DateTime(
          DateTime.now().year + 1,
          DateTime.now().month,
          DateTime.now().day,
        ).toIso8601String().substring(0, 10),
        date: true,
      ),
      FinanceField(
        'account',
        context.l10n.payoutAccount,
        initial: accounts.isEmpty ? '' : '${accounts.first.id}',
        options: {
          for (final a in accounts.where((a) => a.type != 'credit'))
            '${a.id}': '${a.name} (${a.currency})',
        },
        required: false,
      ),
      FinanceField(
        'card',
        context.l10n.linkedCard,
        options: {
          for (final a in accounts.where((a) => a.type == 'credit'))
            '${a.id}': a.name,
        },
        required: false,
      ),
      FinanceField(
        'statement',
        context.l10n.cardStatementDay,
        initial: '1',
        numeric: true,
      ),
      FinanceField(
        'due',
        context.l10n.cardPaymentDay,
        initial: '15',
        numeric: true,
      ),
      FinanceField(
        'fund',
        context.l10n.movePrincipalNow,
        initial: 'no',
        options: {
          'no': context.l10n.existingPosition,
          'yes': context.l10n.recordNewFunding,
        },
      ),
    ],
    save: (j) async {
      final statement = int.parse(j['statement']!), due = int.parse(j['due']!);
      if (statement < 1 || statement > 31 || due < 1 || due > 31) {
        throw ArgumentError(context.l10n.cardDaysRange);
      }
      final c = FinanceContract(
        id: ref.read(financialLedgerProvider).newId(),
        name: j['name']!,
        kind: ContractKind.values.byName(j['kind']!),
        currency: j['currency']!,
        principal: number(j, 'principal'),
        annualRate: number(j, 'rate'),
        start: DateTime.parse(j['start']!),
        maturity: DateTime.parse(j['maturity']!),
        counterparty: j['counterparty']!,
        interestMethod: j['method']!,
        paymentsPerYear: int.parse(j['frequency']!),
        accountId: int.tryParse(j['account']!),
        cardAccountId: int.tryParse(j['card']!),
        statementDay: statement,
        paymentDay: due,
      );
      await ref
          .read(contractServiceProvider)
          .create(c, fundNow: j['fund'] == 'yes');
    },
  );
}

class ContractDetailScreen extends ConsumerWidget {
  final FinanceContract contract;
  const ContractDetailScreen({super.key, required this.contract});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(financeRevisionProvider);
    final c = contract;
    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: FutureBuilder<List<ScheduledPayment>>(
        future: ContractRepository(
          ref.read(financeStoreProvider),
        ).payments(c.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                context.l10n.principalAnnual(
                  c.principal.fixed(),
                  c.currency,
                  '${c.annualRate}',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                c.interestMethod == 'reducing'
                    ? context.l10n.equalInstallmentsNote
                    : context.l10n.flatCouponsNote,
              ),
              const SizedBox(height: 16),
              if (c.kind == ContractKind.creditCard)
                FutureBuilder(
                  future: ref.read(contractServiceProvider).cardStatement(c),
                  builder: (context, s) {
                    return Card(
                      child: ListTile(
                        title: Text(
                          context.l10n.outstandingAmount(
                            '${s.data?['outstanding'] ?? '…'}',
                            c.currency,
                          ),
                        ),
                        subtitle: Text(
                          context.l10n.billedLine(
                            '${s.data?['billed'] ?? '…'}',
                            '${s.data?['unbilled'] ?? '…'}',
                            '${s.data?['olderOrOpening'] ?? '…'}',
                            s.data?['due']?.toString().substring(0, 10) ?? '…',
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final account = await ref
                                .read(databaseProvider)
                                .getAccountById(c.cardAccountId!);
                            if (account == null || !context.mounted) return;
                            final status = await ref
                                .read(creditCardServiceProvider)
                                .status(account.id);
                            if (!context.mounted) return;
                            await payCard(context, ref, account, status);
                          },
                          child: Text(context.l10n.payCard),
                        ),
                      ),
                    );
                  },
                ),
              if (c.interestMethod == 'manual')
                OutlinedButton(
                  onPressed: () => _manualPayment(context, ref, c),
                  child: Text(context.l10n.addAgreedPayment),
                ),
              if (c.kind != ContractKind.creditCard)
                OutlinedButton(
                  onPressed: () async {
                    final paid = rows
                        .where((p) => p.paid)
                        .fold(Amount.zero, (sum, p) => sum + p.principal);
                    await financeForm(
                      context,
                      title: context.l10n.earlySettlement,
                      fields: [
                        FinanceField(
                          'principal',
                          context.l10n.outstandingPrincipal,
                          initial: '${c.principal - paid}',
                          numeric: true,
                        ),
                        FinanceField(
                          'interest',
                          context.l10n.agreedFinalInterest,
                          initial: '0',
                          numeric: true,
                        ),
                      ],
                      save: (j) async {
                        if (c.accountId == null) {
                          throw StateError(context.l10n.noLinkedCashAccount);
                        }
                        await ref
                            .read(contractServiceProvider)
                            .earlySettle(
                              c.id,
                              c.accountId!,
                              number(j, 'principal'),
                              number(j, 'interest'),
                            );
                      },
                    );
                  },
                  child: Text(context.l10n.recordEarlySettlement),
                ),
              for (final p in rows)
                Card(
                  child: ListTile(
                    title: Text(
                      '${p.date.toIso8601String().substring(0, 10)} · ${p.total.fixed()} ${c.currency}',
                    ),
                    subtitle: Text(
                      '${context.l10n.principalInterestLine(p.principal.fixed(), p.interest.fixed())}${p.paid ? ' · ${context.l10n.confirmed}' : ''}',
                    ),
                    trailing: p.paid
                        ? IconButton(
                            tooltip: context.l10n.reverseConfirmedPayment,
                            icon: const Icon(Icons.undo),
                            onPressed: () async {
                              final reverse = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(context.l10n.reversePaymentTitle),
                                  content: Text(
                                    context.l10n.reversePaymentBody,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(context.l10n.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(context.l10n.reverse),
                                    ),
                                  ],
                                ),
                              );
                              if (reverse == true) {
                                try {
                                  await ref
                                      .read(contractServiceProvider)
                                      .reverseConfirmation(p.id);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$e')),
                                    );
                                  }
                                }
                              }
                            },
                          )
                        : TextButton(
                            onPressed: () async {
                              final accounts =
                                  (ref.read(accountsProvider).valueOrNull ?? [])
                                      .where(
                                        (a) =>
                                            a.currency == c.currency &&
                                            a.type != 'credit',
                                      )
                                      .toList();
                              await financeForm(
                                context,
                                title: context.l10n.confirmActual(
                                  p.total.fixed(),
                                  c.currency,
                                ),
                                fields: [
                                  FinanceField(
                                    'account',
                                    context.l10n.cashAccountRecordNow,
                                    initial:
                                        c.accountId?.toString() ??
                                        accounts.firstOrNull?.id.toString() ??
                                        '',
                                    options: {
                                      for (final a in accounts)
                                        '${a.id}': a.name,
                                    },
                                  ),
                                ],
                                submit: context.l10n.confirm,
                                save: (j) => ref
                                    .read(contractServiceProvider)
                                    .confirm(
                                      p.id,
                                      accountId: int.parse(j['account']!),
                                    ),
                              );
                            },
                            child: Text(context.l10n.confirm),
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

String contractKindLabel(AppLocalizations l, ContractKind kind) =>
    switch (kind) {
      ContractKind.deposit => l.contractDeposit,
      ContractKind.certificate => l.contractCertificate,
      ContractKind.loan => l.contractLoan,
      ContractKind.receivable => l.contractReceivable,
      ContractKind.creditCard => l.contractCreditCard,
    };

Future<void> _manualPayment(
  BuildContext context,
  WidgetRef ref,
  FinanceContract c, {
  bool card = false,
}) async {
  await financeForm(
    context,
    title: card ? context.l10n.payCreditCard : context.l10n.addAgreedPayment,
    fields: [
      FinanceField('date', context.l10n.dueDate, initial: today(), date: true),
      FinanceField('principal', context.l10n.principalAmount, numeric: true),
      FinanceField(
        'interest',
        context.l10n.interestAmount,
        initial: '0',
        numeric: true,
      ),
    ],
    save: (j) async {
      final p = ScheduledPayment(
        id: ref.read(financialLedgerProvider).newId(),
        contractId: c.id,
        date: DateTime.parse(j['date']!),
        principal: number(j, 'principal'),
        interest: number(j, 'interest'),
      );
      if (card) {
        if (p.total <= Amount.zero) {
          throw ArgumentError(context.l10n.enterPositivePayment);
        }
        await ref.read(databaseProvider).transaction(() async {
          await ref
              .read(financeStoreProvider)
              .put('payments', p.id, p.toJson());
          await ref.read(contractServiceProvider).confirm(p.id);
        });
      } else {
        await ref.read(contractServiceProvider).addPayment(p);
      }
    },
  );
}
