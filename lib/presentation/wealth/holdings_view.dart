import 'package:flourish/l10n/l10n.dart';
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
import '../../core/utils/amount_parser.dart';
import '../../shared/widgets/shimmer_loading.dart';

Map<String, String> get currencies => {
  for (final currency in AppConstants.currencies) currency: currency,
};
String today() => DateTime.now().toIso8601String().substring(0, 10);
Amount number(Map<String, String> j, String key) =>
    AmountParser.decimal(j[key]!);

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
          label: Text(context.l10n.addHolding),
        ),
        const SizedBox(height: 16),
        ...holdings.when(
          data: (items) => items.isEmpty
              ? [
                  Padding(
                    padding: EdgeInsets.all(Sp.sm),
                    child: WealthHint(context.l10n.addHoldingHelp),
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
                                '${assetKindLabel(context.l10n, h.kind)} · ${h.quantity} ${h.unit}${h.custody.isEmpty ? '' : ' · ${h.custody}'}\n${v?.source ?? context.l10n.missingPrice}${v?.effectiveAt == null ? '' : ' · ${v!.effectiveAt!.toIso8601String().substring(0, 10)}'}',
                            value: v?.converted == null
                                ? context.l10n.needsPrice
                                : CurrencyFormatter.format(
                                    v!.converted!.toDouble(),
                                    currency: currency,
                                  ),
                            valueTone: v?.converted == null
                                ? FlourishPalette.of(context).warning
                                : null,
                            secondary: gain == null
                                ? context.l10n.costUnknown(
                                    h.costBasis?.fixed() ??
                                        context.l10n.unknown,
                                    h.currency,
                                  )
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
    title: context.l10n.addHolding,
    fields: [
      FinanceField('name', context.l10n.assetName),
      FinanceField(
        'kind',
        context.l10n.assetClass,
        initial: 'gold',
        options: {
          for (final k in AssetKind.values)
            k.name: assetKindLabel(context.l10n, k),
        },
      ),
      FinanceField(
        'quantity',
        context.l10n.quantityGrams,
        initial: '1',
        numeric: true,
      ),
      FinanceField(
        'currency',
        context.l10n.acquisitionCurrency,
        initial: currency,
        options: currencies,
      ),
      FinanceField(
        'cost',
        context.l10n.totalCostShare,
        required: false,
        numeric: true,
      ),
      FinanceField('symbol', context.l10n.tickerSymbol, required: false),
      FinanceField('exchange', context.l10n.exchangeHint, required: false),
      FinanceField('custody', context.l10n.whereHeld, required: false),
      FinanceField(
        'ownership',
        context.l10n.ownershipFraction,
        initial: '1',
        numeric: true,
      ),
      FinanceField(
        'karat',
        context.l10n.goldKarat,
        initial: '24',
        options: {'24': '24K', '22': '22K', '21': '21K', '18': '18K'},
      ),
      FinanceField(
        'valuation',
        context.l10n.priceSource,
        initial: 'manual',
        options: {
          'manual': context.l10n.datedManualPrices,
          'automatic': context.l10n.freeMarketFeed,
        },
      ),
      FinanceField(
        'price',
        context.l10n.currentResalePrice,
        required: false,
        numeric: true,
      ),
      FinanceField(
        'date',
        context.l10n.openingDate,
        initial: today(),
        date: true,
      ),
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
        throw ArgumentError(context.l10n.priceMustBePositive);
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
    title: context.l10n.valueNamed(h.name),
    fields: [
      FinanceField('price', context.l10n.resalePricePerUnit, numeric: true),
      FinanceField(
        'currency',
        context.l10n.quoteCurrency,
        initial: h.currency,
        options: currencies,
      ),
      FinanceField(
        'date',
        context.l10n.quoteDate,
        initial: today(),
        date: true,
      ),
      FinanceField(
        'source',
        context.l10n.source,
        initial: 'Manual resale quote',
      ),
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
              context.l10n.ownershipLine(
                '${h.quantity}',
                h.unit,
                '${h.ownership * Amount('100')}',
              ),
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
                    context.l10n.unrealizedGainCaps,
                    style: AppTextStyles.eyebrow.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: Sp.xs),
                  Text(
                    v?.gain?.fixed() ?? context.l10n.gainUnknown,
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
                          title: context.l10n.linkPropertyMortgage,
                          fields: [
                            FinanceField(
                              'loan',
                              context.l10n.existingObligation,
                              initial: h.linkedContractId ?? 'none',
                              options: {
                                'none': context.l10n.noLinkedMortgage,
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
                            SnackBar(
                              content: Text(context.l10n.manualAppraisals),
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
                          title: context.l10n.adjustHoldingAudit,
                          fields: [
                            FinanceField(
                              'quantity',
                              context.l10n.correctQuantity,
                              initial: '${h.quantity}',
                              numeric: true,
                            ),
                            FinanceField(
                              'cost',
                              context.l10n.totalAcquisitionCost,
                              initial: h.costBasis?.toString() ?? '',
                              required: false,
                              numeric: true,
                            ),
                            FinanceField(
                              'custody',
                              context.l10n.custodyLocation,
                              initial: h.custody,
                              required: false,
                            ),
                            FinanceField('reason', context.l10n.adjustReason),
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
                          title: context.l10n.stockSplit,
                          fields: [
                            FinanceField(
                              'ratio',
                              context.l10n.newUnitsPerOld,
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
                          SnackBar(
                            content: Text(context.l10n.createCashAccountFirst),
                          ),
                        );
                        return;
                      }
                      await financeForm(
                        context,
                        title:
                            '${_actionLabel(context.l10n, action)} ${h.name}',
                        fields: [
                          FinanceField(
                            'account',
                            context.l10n.cashAccount,
                            initial: '${accounts.first.id}',
                            options: {
                              for (final a in accounts)
                                '${a.id}': '${a.name} (${a.currency})',
                            },
                          ),
                          if (action == 'Income')
                            FinanceField(
                              'kind',
                              context.l10n.incomeType,
                              initial: 'dividend',
                              options: {
                                'dividend': context.l10n.dividend,
                                'interest': context.l10n.interest,
                                'rent': context.l10n.rent,
                              },
                            ),
                          if (action != 'Income')
                            FinanceField(
                              'quantity',
                              context.l10n.quantity,
                              numeric: true,
                            ),
                          FinanceField(
                            'amount',
                            action == 'Income'
                                ? context.l10n.actualIncomeInAccount
                                : context.l10n.pricePerUnitIn(h.currency),
                            numeric: true,
                          ),
                          if (action != 'Income') ...[
                            FinanceField(
                              'cash',
                              context.l10n.actualGrossCash,
                              numeric: true,
                              required: false,
                            ),
                            FinanceField(
                              'fee',
                              context.l10n.feeInAccount,
                              initial: '0',
                              numeric: true,
                            ),
                          ],
                          FinanceField(
                            'date',
                            context.l10n.transactionDate,
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
                    child: Text(_actionLabel(context.l10n, action)),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

String assetKindLabel(AppLocalizations l, AssetKind kind) => switch (kind) {
  AssetKind.gold => l.assetGold,
  AssetKind.stock => l.assetStock,
  AssetKind.fund => l.assetFund,
  AssetKind.crypto => l.assetCrypto,
  AssetKind.property => l.assetProperty,
  AssetKind.custom => l.assetCustom,
};

String _actionLabel(AppLocalizations l, String action) => switch (action) {
  'Buy' => l.buy,
  'Sell' => l.sell,
  'Set price' => l.setPrice,
  'Use feed' => l.useFeed,
  'Link mortgage' => l.linkMortgage,
  'Adjust' => l.adjust,
  'Income' => l.income,
  'Split' => l.split,
  'Activity' => l.activity,
  _ => action,
};

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
      title: Text(context.l10n.activityOf(h.name)),
      content: SizedBox(
        width: 480,
        height: 400,
        child: ListView(
          children: [
            for (final e in activity)
              ListTile(
                title: Text('${e['kind']} · ${e['quantity'] ?? ''}'),
                subtitle: Text(
                  '${e['date']}\n${e['amount'] ?? context.l10n.unknownCost} ${e['currency'] ?? ''}${e['realizedGain'] == null ? '' : ' · ${context.l10n.gainLabel('${e['realizedGain']}')}'}',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ],
    ),
  );
}
