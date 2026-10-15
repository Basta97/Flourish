import '../../core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/finance_providers.dart';
import '../providers/account_providers.dart';
import '../providers/theme_providers.dart';
import '../../core/finance/valuation_service.dart';
import '../../data/finance/finance_store.dart';
import 'finance_form.dart';
import 'widgets/asset_tile.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../shared/widgets/shimmer_loading.dart';

Map<String, String> get currencies => {
  for (final currency in AppConstants.currencies) currency: currency,
};
String today() => DateTime.now().toIso8601String().substring(0, 10);
Amount number(Map<String, String> j, String key) => Amount(j[key]!);

class HoldingsView extends ConsumerWidget {
  const HoldingsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdings = ref.watch(holdingsProvider);
    final wealth = ref.watch(wealthProvider).valueOrNull;
    final currency = ref.watch(defaultCurrencyProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        FilledButton.icon(
          onPressed: () => addHolding(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Add holding'),
        ),
        const SizedBox(height: 16),
        ...holdings.when(
          data: (items) => items.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(Sp.sm),
                    child: WealthHint(
                      'Add gold, investments, property, crypto, or another asset. Existing holdings do not change your cash balance.',
                    ),
                  ),
                ]
              : [
                  AssetGroup(
                    children: [
                      for (final h in items)
                        () {
                          final v = wealth?.items
                              .where((v) => v.id == h.id)
                              .firstOrNull;
                          final (icon, tint) = assetStyle(h.kind);
                          final gain = v?.gain;
                          return AssetTile(
                            key: ValueKey(h.id),
                            icon: icon,
                            tint: tint,
                            title: h.name,
                            subtitle:
                                '${h.kind.name} · ${h.quantity} ${h.unit}${h.custody.isEmpty ? '' : ' · ${h.custody}'}\n${v?.source ?? 'Missing price'}${v?.effectiveAt == null ? '' : ' · ${v!.effectiveAt!.toIso8601String().substring(0, 10)}'}',
                            value: v?.converted == null
                                ? 'Needs price'
                                : CurrencyFormatter.format(
                                    v!.converted!.toDouble(),
                                    currency: currency,
                                  ),
                            valueTone: v?.converted == null
                                ? FlourishPalette.of(context).warning
                                : null,
                            secondary: gain == null
                                ? 'Cost ${h.costBasis?.fixed() ?? 'unknown'} ${h.currency}'
                                : '${gain >= Amount.zero ? '+' : ''}${gain.fixed()} $currency',
                            onTap: () => showHolding(context, ref, h, v),
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
}

Future<void> addHolding(BuildContext context, WidgetRef ref) async {
  final currency = ref.read(defaultCurrencyProvider);
  await financeForm(
    context,
    title: 'Add holding',
    fields: [
      const FinanceField('name', 'Asset name'),
      FinanceField(
        'kind',
        'Asset class',
        initial: 'gold',
        options: {for (final k in AssetKind.values) k.name: k.name},
      ),
      const FinanceField(
        'quantity',
        'Quantity / weight in grams',
        initial: '1',
        numeric: true,
      ),
      FinanceField(
        'currency',
        'Acquisition currency',
        initial: currency,
        options: currencies,
      ),
      const FinanceField(
        'cost',
        'Total cost of your share (blank if unknown)',
        required: false,
        numeric: true,
      ),
      const FinanceField('symbol', 'Ticker / crypto symbol', required: false),
      const FinanceField(
        'exchange',
        'Exchange (EGX, NASDAQ, etc.)',
        required: false,
      ),
      const FinanceField('custody', 'Where it is held', required: false),
      const FinanceField(
        'ownership',
        'Ownership fraction (1 = 100%)',
        initial: '1',
        numeric: true,
      ),
      const FinanceField(
        'karat',
        'Gold karat',
        initial: '24',
        options: {'24': '24K', '22': '22K', '21': '21K', '18': '18K'},
      ),
      const FinanceField(
        'valuation',
        'Price source',
        initial: 'manual',
        options: {
          'manual': 'Dated manual prices',
          'automatic': 'Free market feed when supported',
        },
      ),
      const FinanceField(
        'price',
        'Current unit / gram resale price (optional)',
        required: false,
        numeric: true,
      ),
      FinanceField('date', 'Opening date', initial: today(), date: true),
    ],
    save: (j) async {
      final id = ref.read(financialLedgerProvider).newId();
      final kind = AssetKind.values.byName(j['kind']!);
      final h = Holding(
        id: id,
        name: j['name']!,
        kind: kind,
        quantity: number(j, 'quantity'),
        currency: j['currency']!,
        openedAt: DateTime.parse(j['date']!),
        costBasis: j['cost']!.isEmpty ? null : number(j, 'cost'),
        symbol: j['symbol']!,
        exchange: j['exchange']!,
        custody: j['custody']!,
        ownership: number(j, 'ownership'),
        karat: int.parse(j['karat']!),
        valuation: j['valuation']!,
        unit: kind == AssetKind.gold ? 'grams' : 'units',
      );
      final price = j['price']!.isEmpty ? null : number(j, 'price');
      if (price != null && price <= Amount.zero) {
        throw ArgumentError('Price must be positive');
      }
      await ref.read(databaseProvider).transaction(() async {
        await ref.read(financialLedgerProvider).openHolding(h);
        if (price != null) {
          await ref
              .read(marketDataProvider)
              .save(
                'prices',
                MarketObservation(
                  key: id,
                  currency: h.currency,
                  source: 'Manual resale quote',
                  value: price,
                  effectiveAt: DateTime.now(),
                  retrievedAt: DateTime.now(),
                  manual: true,
                ),
              );
        }
      });
    },
  );
}

Future<void> setHoldingPrice(
  BuildContext context,
  WidgetRef ref,
  Holding h,
) async {
  await financeForm(
    context,
    title: 'Value ${h.name}',
    fields: [
      const FinanceField(
        'price',
        'Resale price per unit / gram',
        numeric: true,
      ),
      FinanceField(
        'currency',
        'Quote currency',
        initial: h.currency,
        options: currencies,
      ),
      FinanceField('date', 'Quote date', initial: today(), date: true),
      const FinanceField('source', 'Source', initial: 'Manual resale quote'),
    ],
    save: (j) => ref
        .read(marketDataProvider)
        .save(
          'prices',
          MarketObservation(
            key: h.id,
            currency: j['currency']!,
            source: j['source']!,
            value: number(j, 'price'),
            effectiveAt: DateTime.parse(j['date']!),
            retrievedAt: DateTime.now(),
            manual: true,
          ),
        ),
  );
}

Future<void> showHolding(
  BuildContext context,
  WidgetRef ref,
  Holding h,
  ValuedItem? v,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Above the floating nav bar, which lives outside the tab navigator.
    useRootNavigator: true,
    backgroundColor: AppColors.elevatedSurface(context),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(
              builder: (_) {
                final (icon, tint) = assetStyle(h.kind);
                return Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: tint, size: 26),
                );
              },
            ),
            const SizedBox(height: Sp.md),
            Text(h.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: Sp.xs),
            Text(
              '${h.quantity} ${h.unit} · ownership ${h.ownership * Amount('100')}%',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: Sp.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Sp.md),
              decoration: BoxDecoration(
                color: AppColors.mutedSurface(context),
                borderRadius: BorderRadius.circular(Rad.md),
              ),
              child: Column(
                children: [
                  Text(
                    'UNREALIZED GAIN',
                    style: AppTextStyles.eyebrow.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: Sp.xs),
                  Text(
                    v?.gain?.fixed() ?? 'Unknown — cost or price unavailable',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.number.copyWith(
                      color: v?.gain == null
                          ? AppColors.textSecondary(context)
                          : v!.gain! >= Amount.zero
                          ? AppColors.income
                          : AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.lg),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final action in [
                  'Buy',
                  'Sell',
                  'Set price',
                  'Use feed',
                  if (h.kind == AssetKind.property) 'Link mortgage',
                  'Adjust',
                  'Income',
                  'Split',
                  'Activity',
                ])
                  OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(sheet);
                      if (action == 'Link mortgage') {
                        final loans =
                            (ref.read(contractsProvider).valueOrNull ?? [])
                                .where((c) => c.kind == ContractKind.loan);
                        await financeForm(
                          context,
                          title: 'Link property and mortgage',
                          fields: [
                            FinanceField(
                              'loan',
                              'Existing obligation (counted once in net worth)',
                              initial: h.linkedContractId ?? 'none',
                              options: {
                                'none': 'No linked mortgage',
                                for (final c in loans) c.id: c.name,
                              },
                            ),
                          ],
                          save: (j) => ref
                              .read(financialLedgerProvider)
                              .linkPropertyDebt(
                                h.id,
                                j['loan'] == 'none' ? null : j['loan'],
                              ),
                        );
                        return;
                      }
                      if (action == 'Use feed') {
                        if ([
                          AssetKind.property,
                          AssetKind.custom,
                        ].contains(h.kind)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'This asset uses dated manual appraisals.',
                              ),
                            ),
                          );
                          return;
                        }
                        await ref
                            .read(marketDataProvider)
                            .clearManual('prices', h.id);
                        await PortfolioRepository(
                          ref.read(financeStoreProvider),
                        ).save(h.copy(valuation: 'automatic'));
                        await ref
                            .read(marketDataProvider)
                            .refresh(
                              reportingCurrency: ref.read(
                                defaultCurrencyProvider,
                              ),
                              force: true,
                            );
                        return;
                      }
                      if (action == 'Adjust') {
                        await financeForm(
                          context,
                          title: 'Adjust holding with an audit record',
                          fields: [
                            FinanceField(
                              'quantity',
                              'Correct quantity',
                              initial: '${h.quantity}',
                              numeric: true,
                            ),
                            FinanceField(
                              'cost',
                              'Total acquisition cost (blank if unknown)',
                              initial: h.costBasis?.toString() ?? '',
                              required: false,
                              numeric: true,
                            ),
                            FinanceField(
                              'custody',
                              'Custody / location',
                              initial: h.custody,
                              required: false,
                            ),
                            const FinanceField(
                              'reason',
                              'Reason for adjustment',
                            ),
                          ],
                          save: (j) => ref
                              .read(financialLedgerProvider)
                              .adjustHolding(
                                h.id,
                                quantity: number(j, 'quantity'),
                                costBasis: j['cost']!.isEmpty
                                    ? null
                                    : number(j, 'cost'),
                                custody: j['custody']!,
                                reason: j['reason']!,
                              ),
                        );
                        return;
                      }
                      if (action == 'Set price') {
                        await setHoldingPrice(context, ref, h);
                        return;
                      }
                      if (action == 'Activity') {
                        await showActivity(context, ref, h);
                        return;
                      }
                      if (action == 'Split') {
                        await financeForm(
                          context,
                          title: 'Stock split / quantity adjustment',
                          fields: [
                            const FinanceField(
                              'ratio',
                              'New units per old unit',
                              numeric: true,
                            ),
                          ],
                          save: (j) => ref
                              .read(financialLedgerProvider)
                              .split(h.id, number(j, 'ratio')),
                        );
                        return;
                      }
                      final accounts =
                          ref.read(accountsProvider).valueOrNull ?? [];
                      if (accounts.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Create a cash account first'),
                          ),
                        );
                        return;
                      }
                      await financeForm(
                        context,
                        title: '$action ${h.name}',
                        fields: [
                          FinanceField(
                            'account',
                            'Cash account',
                            initial: '${accounts.first.id}',
                            options: {
                              for (final a in accounts)
                                '${a.id}': '${a.name} (${a.currency})',
                            },
                          ),
                          if (action == 'Income')
                            const FinanceField(
                              'kind',
                              'Income type',
                              initial: 'dividend',
                              options: {
                                'dividend': 'Dividend',
                                'interest': 'Interest',
                                'rent': 'Rent',
                              },
                            ),
                          if (action != 'Income')
                            const FinanceField(
                              'quantity',
                              'Quantity',
                              numeric: true,
                            ),
                          FinanceField(
                            'amount',
                            action == 'Income'
                                ? 'Actual income in account currency'
                                : 'Price per unit in ${h.currency}',
                            numeric: true,
                          ),
                          if (action != 'Income') ...[
                            const FinanceField(
                              'cash',
                              'Actual gross cash in account currency (optional)',
                              numeric: true,
                              required: false,
                            ),
                            const FinanceField(
                              'fee',
                              'Fee in account currency',
                              initial: '0',
                              numeric: true,
                            ),
                          ],
                          FinanceField(
                            'date',
                            'Transaction date',
                            initial: today(),
                            date: true,
                          ),
                        ],
                        save: (j) async {
                          final ledger = ref.read(financialLedgerProvider);
                          if (action == 'Income') {
                            await ledger.distribution(
                              h.id,
                              int.parse(j['account']!),
                              number(j, 'amount'),
                              ActivityKind.values.byName(j['kind']!),
                              date: DateTime.parse(j['date']!),
                            );
                          } else {
                            await ledger.trade(
                              holdingId: h.id,
                              kind: action == 'Buy'
                                  ? ActivityKind.buy
                                  : ActivityKind.sell,
                              quantity: number(j, 'quantity'),
                              unitPrice: number(j, 'amount'),
                              accountId: int.parse(j['account']!),
                              fee: number(j, 'fee'),
                              cashAmount: j['cash']!.isEmpty
                                  ? null
                                  : number(j, 'cash'),
                              date: DateTime.parse(j['date']!),
                            );
                          }
                        },
                      );
                    },
                    child: Text(action),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showActivity(
  BuildContext context,
  WidgetRef ref,
  Holding h,
) async {
  final activity = await PortfolioRepository(
    ref.read(financeStoreProvider),
  ).activity(h.id);
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('${h.name} activity'),
      content: SizedBox(
        width: 480,
        height: 400,
        child: ListView(
          children: [
            for (final e in activity)
              ListTile(
                title: Text('${e['kind']} · ${e['quantity'] ?? ''}'),
                subtitle: Text(
                  '${e['date']}\n${e['amount'] ?? 'Unknown cost'} ${e['currency'] ?? ''}${e['realizedGain'] == null ? '' : ' · Gain ${e['realizedGain']}'}',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
