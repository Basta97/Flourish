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
        label: const Text('Add contract or debt'),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: WealthHint(
          'Expected payments never change cash until you confirm receipt or payment.',
        ),
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
                                  '${c.kind.name}${c.counterparty.isEmpty ? '' : ' · ${c.counterparty}'}\n${c.annualRate}% · matures ${c.maturity.toIso8601String().substring(0, 10)}',
                              value: CurrencyFormatter.format(
                                c.principal.toDouble(),
                                currency: c.currency,
                              ),
                              valueTone: c.isDebt ? AppColors.expense : null,
                              secondary: c.isDebt ? 'Owed' : 'Principal',
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
    title: 'Add contract or obligation',
    fields: [
      const FinanceField('name', 'Name'),
      FinanceField(
        'kind',
        'Type',
        initial: 'certificate',
        options: {for (final k in ContractKind.values) k.name: k.name},
      ),
      FinanceField(
        'currency',
        'Currency',
        initial: ref.read(defaultCurrencyProvider),
        options: currencies,
      ),
      const FinanceField(
        'principal',
        'Existing outstanding / invested principal',
        numeric: true,
      ),
      const FinanceField(
        'rate',
        'Annual interest / coupon (%)',
        initial: '0',
        numeric: true,
      ),
      const FinanceField(
        'counterparty',
        'Bank / person / lender',
        required: false,
      ),
      const FinanceField(
        'method',
        'Interest convention',
        initial: 'flat',
        options: {
          'flat': 'Flat fixed annual rate / periodic coupons',
          'reducing': 'Reducing balance, equal installments',
          'manual': 'Enter an agreed schedule manually',
        },
      ),
      const FinanceField(
        'frequency',
        'Payments per year',
        initial: '12',
        options: {
          '12': 'Monthly',
          '4': 'Quarterly',
          '2': 'Half-yearly',
          '1': 'Yearly',
        },
      ),
      FinanceField('start', 'Start date', initial: today(), date: true),
      FinanceField(
        'maturity',
        'Maturity / end date',
        initial: DateTime(
          DateTime.now().year + 1,
          DateTime.now().month,
          DateTime.now().day,
        ).toIso8601String().substring(0, 10),
        date: true,
      ),
      FinanceField(
        'account',
        'Cash / payout account',
        initial: accounts.isEmpty ? '' : '${accounts.first.id}',
        options: {
          for (final a in accounts.where((a) => a.type != 'credit'))
            '${a.id}': '${a.name} (${a.currency})',
        },
        required: false,
      ),
      FinanceField(
        'card',
        'Linked credit card (cards only)',
        options: {
          for (final a in accounts.where((a) => a.type == 'credit'))
            '${a.id}': a.name,
        },
        required: false,
      ),
      const FinanceField(
        'statement',
        'Card statement day',
        initial: '1',
        numeric: true,
      ),
      const FinanceField(
        'due',
        'Card payment day',
        initial: '15',
        numeric: true,
      ),
      const FinanceField(
        'fund',
        'Move principal from/to cash now?',
        initial: 'no',
        options: {
          'no': 'No — this is an existing position',
          'yes': 'Yes — record new funding',
        },
      ),
    ],
    save: (j) async {
      final statement = int.parse(j['statement']!), due = int.parse(j['due']!);
      if (statement < 1 || statement > 31 || due < 1 || due > 31) {
        throw ArgumentError('Card days must be 1–31');
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
                '${c.principal.fixed()} ${c.currency} · ${c.annualRate}% annual',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                c.interestMethod == 'reducing'
                    ? 'Equal installments; periodic rate = annual rate / payments per year.'
                    : 'Flat coupons; final partial period is prorated by actual days in the scheduled period.',
              ),
              const SizedBox(height: 16),
              if (c.kind == ContractKind.creditCard)
                FutureBuilder(
                  future: ref.read(contractServiceProvider).cardStatement(c),
                  builder: (context, s) {
                    return Card(
                      child: ListTile(
                        title: Text(
                          'Outstanding ${s.data?['outstanding'] ?? '…'} ${c.currency}',
                        ),
                        subtitle: Text(
                          'Billed ${s.data?['billed'] ?? '…'} · unbilled ${s.data?['unbilled'] ?? '…'}\nOlder / opening ${s.data?['olderOrOpening'] ?? '…'} · due ${s.data?['due']?.toString().substring(0, 10) ?? '…'}',
                        ),
                        trailing: TextButton(
                          onPressed: () =>
                              _manualPayment(context, ref, c, card: true),
                          child: const Text('Pay card'),
                        ),
                      ),
                    );
                  },
                ),
              if (c.interestMethod == 'manual')
                OutlinedButton(
                  onPressed: () => _manualPayment(context, ref, c),
                  child: const Text('Add agreed payment'),
                ),
              if (c.kind != ContractKind.creditCard)
                OutlinedButton(
                  onPressed: () async {
                    final paid = rows
                        .where((p) => p.paid)
                        .fold(Amount.zero, (sum, p) => sum + p.principal);
                    await financeForm(
                      context,
                      title: 'Early settlement',
                      fields: [
                        FinanceField(
                          'principal',
                          'Outstanding principal',
                          initial: '${c.principal - paid}',
                          numeric: true,
                        ),
                        const FinanceField(
                          'interest',
                          'Agreed final interest / fee',
                          initial: '0',
                          numeric: true,
                        ),
                      ],
                      save: (j) async {
                        if (c.accountId == null) {
                          throw StateError('No linked cash account');
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
                  child: const Text('Record early settlement'),
                ),
              for (final p in rows)
                Card(
                  child: ListTile(
                    title: Text(
                      '${p.date.toIso8601String().substring(0, 10)} · ${p.total.fixed()} ${c.currency}',
                    ),
                    subtitle: Text(
                      'Principal ${p.principal.fixed()} · interest ${p.interest.fixed()}${p.paid ? ' · Confirmed' : ''}',
                    ),
                    trailing: p.paid
                        ? IconButton(
                            tooltip: 'Reverse confirmed payment',
                            icon: const Icon(Icons.undo),
                            onPressed: () async {
                              final reverse = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Reverse payment?'),
                                  content: const Text(
                                    'This reverses the linked cash entries and marks the payment unpaid.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Reverse'),
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
                                title:
                                    'Confirm actual ${p.total.fixed()} ${c.currency}',
                                fields: [
                                  FinanceField(
                                    'account',
                                    'Cash account · record actual payment now',
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
                                submit: 'Confirm',
                                save: (j) => ref
                                    .read(contractServiceProvider)
                                    .confirm(
                                      p.id,
                                      accountId: int.parse(j['account']!),
                                    ),
                              );
                            },
                            child: const Text('Confirm'),
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

Future<void> _manualPayment(
  BuildContext context,
  WidgetRef ref,
  FinanceContract c, {
  bool card = false,
}) async {
  await financeForm(
    context,
    title: card ? 'Pay credit card' : 'Add agreed payment',
    fields: [
      FinanceField('date', 'Due date', initial: today(), date: true),
      const FinanceField('principal', 'Principal amount', numeric: true),
      const FinanceField(
        'interest',
        'Interest amount',
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
          throw ArgumentError('Enter a positive payment');
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
