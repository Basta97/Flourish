import 'package:intl/intl.dart' show DateFormat;
import '../providers/locale_providers.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/finance/currency_catalog.dart';
import '../../core/finance/valuation_service.dart';
import '../../core/utils/amount_parser.dart';
import '../../core/utils/currency_formatter.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/global_search_button.dart';
import '../providers/finance_providers.dart';
import '../providers/theme_providers.dart';
import '../wealth/finance_form.dart';
import 'currency_picker.dart';

class ExchangeRatesScreen extends ConsumerStatefulWidget {
  const ExchangeRatesScreen({super.key});
  @override
  ConsumerState<ExchangeRatesScreen> createState() => _ExchangeRatesState();
}

class _ExchangeRatesState extends ConsumerState<ExchangeRatesScreen> {
  final amount = TextEditingController(text: '1');
  String base = 'USD', quote = 'EGP';
  RateResolution? effective, reference;
  List<CurrencyInfo> currencies = CurrencyCatalog.bundled;
  Set<String> favorites = {};
  Map<String, RateResolution?> favoriteRates = {};
  bool loading = false, failed = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    quote = ref.read(defaultCurrencyProvider);
    if (base == quote) base = 'EUR';
    unawaited(load());
  }

  @override
  void dispose() {
    generation++;
    amount.dispose();
    super.dispose();
  }

  Future<void> load({bool force = false}) async {
    final request = ++generation, b = base, q = quote;
    setState(() {
      loading = true;
      failed = false;
      effective = null;
      reference = null;
    });
    final store = ref.read(financeStoreProvider),
        valuation = ref.read(valuationProvider),
        market = ref.read(marketDataProvider);
    final catalog = ref.read(currencyCatalogProvider);
    unawaited(
      catalog.load(force: force).then((rows) {
        if (mounted) setState(() => currencies = rows);
      }),
    );
    try {
      final cached = await valuation.resolveRate(b, q),
          cachedReference = await valuation.resolveRate(
            b,
            q,
            automaticOnly: true,
          );
      if (mounted && request == generation) {
        setState(() {
          effective = cached;
          reference = cachedReference;
        });
      }
      final saved = (await store.list(
        'fxFavorites',
      )).map((j) => '${j['pair']}').toSet();
      if (mounted) setState(() => favorites = saved);
      final requests = <String, Set<String>>{
        b: {q},
      };
      for (final pair in saved) {
        final parts = pair.split('/');
        if (parts.length == 2) {
          requests.putIfAbsent(parts.first, () => {}).add(parts.last);
        }
      }
      var failure = false;
      for (final e in requests.entries) {
        try {
          await market.refreshPairs(e.key, e.value, force: force);
        } catch (_) {
          failure = true;
        }
      }
      final resolved = await valuation.resolveRate(b, q),
          auto = await valuation.resolveRate(b, q, automaticOnly: true);
      final favRates = <String, RateResolution?>{};
      for (final pair in saved) {
        final p = pair.split('/');
        if (p.length == 2) {
          favRates[pair] = await valuation.resolveRate(p.first, p.last);
        }
      }
      if (mounted && request == generation) {
        setState(() {
          effective = resolved;
          reference = auto;
          failed = failure;
          favoriteRates = favRates;
        });
      }
    } catch (_) {
      if (mounted && request == generation) setState(() => failed = true);
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> favorite(String pair) async {
    final store = ref.read(financeStoreProvider);
    if (favorites.contains(pair)) {
      await store.remove('fxFavorites', pair);
    } else {
      await store.put('fxFavorites', pair, {'pair': pair});
    }
    if (mounted) await load();
  }

  Future<void> editOverride() async {
    final l = context.l10n;
    await financeForm(
      context,
      title: l.manualExchangeRate,
      fields: [
        FinanceField('rate', l.oneSourceUnitEquals, numeric: true),
        FinanceField(
          'date',
          l.effectiveDate,
          initial: DateTime.now().toIso8601String().substring(0, 10),
          date: true,
        ),
      ],
      save: (j) async {
        if (base == quote) throw ArgumentError(l.chooseDifferentCurrencies);

        // FX rates may need more decimals than monetary amounts.
        final rate = AmountParser.decimal(j['rate']!);
        if (rate <= Amount.zero) throw ArgumentError(l.amountAboveZero);
        await ref
            .read(marketDataProvider)
            .save(
              'fx',
              MarketObservation(
                key: '$base/$quote',
                currency: quote,
                source: 'Manual reference override',
                value: rate,
                effectiveAt: DateTime.parse(j['date']!),
                retrievedAt: DateTime.now(),
                manual: true,
              ),
            );
      },
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, hidden = ref.watch(hideAmountsProvider);
    final parsed = AmountParser.parse(
      amount.text,
      currency: base,
      allowZero: true,
    );
    final converted = parsed.value == null || effective == null
        ? null
        : effective!.convert(parsed.value!);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.exchangeRates),
        actions: const [GlobalSearchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () => load(force: true),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              l.currencyConverter,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CurrencyField(
                    value: base,
                    label: l.from,
                    onChanged: (v) {
                      setState(() => base = v);
                      unawaited(load());
                    },
                  ),
                ),
                IconButton(
                  tooltip: l.transfer,
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: () {
                    setState(() {
                      final previous = base;
                      base = quote;
                      quote = previous;
                    });
                    unawaited(load());
                  },
                ),
                Expanded(
                  child: CurrencyField(
                    value: quote,
                    label: l.to,
                    onChanged: (v) {
                      setState(() => quote = v);
                      unawaited(load());
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l.amount,
                errorText: parsed.error,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            SelectableText(
              converted == null
                  ? '—'
                  : hidden
                  ? '••••'
                  : '$quote ${converted.fixed(CurrencyFormatter.decimalsFor(quote))}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (loading) const LinearProgressIndicator(),
            if (failed)
              ListTile(
                title: Text(l.rateRefreshFailed),
                trailing: IconButton(
                  tooltip: l.searchRetry,
                  icon: const Icon(Icons.refresh),
                  onPressed: () => load(force: true),
                ),
              ),
            if (!loading && effective == null) Text(l.rateUnavailable),
            if (effective != null) _rate(l.effectiveRate, effective!),
            if (reference != null && effective?.manual == true)
              _rate(l.referenceRate, reference!),
            Text(l.cachedRateNotice),
            Wrap(
              spacing: 12,
              children: [
                TextButton.icon(
                  onPressed: base == quote ? null : editOverride,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l.addOverride),
                ),
                if (effective?.manual == true)
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(marketDataProvider)
                          .clearManual('fx', effective!.observation!.key);
                      if (mounted) await load();
                    },
                    child: Text(l.resumeAutomaticRate),
                  ),
                IconButton(
                  tooltip: l.favoritePairs,
                  icon: Icon(
                    favorites.contains('$base/$quote')
                        ? Icons.star
                        : Icons.star_border,
                  ),
                  onPressed: base == quote
                      ? null
                      : () => favorite('$base/$quote'),
                ),
              ],
            ),
            const Divider(),
            Text(
              l.favoritePairs,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final pair in favorites)
              ListTile(
                title: Text(pair),
                subtitle: Text(
                  favoriteRates[pair]?.rate.toString() ?? l.rateUnavailable,
                ),
                trailing: IconButton(
                  tooltip: l.delete,
                  icon: const Icon(Icons.star),
                  onPressed: () => favorite(pair),
                ),
                onTap: () {
                  final p = pair.split('/');
                  setState(() {
                    base = p.first;
                    quote = p.last;
                  });
                  unawaited(load());
                },
              ),
            const Divider(),
            Text(
              l.searchCurrency,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final currency in CurrencyCatalog.prominent)
              ListTile(
                title: Text(currency),
                subtitle: Text(
                  currencies
                          .where((r) => r.code == currency)
                          .firstOrNull
                          ?.name ??
                      currency,
                ),
                trailing: Text(
                  favoriteRates['$base/$currency']?.rate.toString() ?? '',
                ),
                onTap: () {
                  setState(() => quote = currency);
                  unawaited(load());
                },
              ),
            TextButton.icon(
              icon: const Icon(Icons.search),
              label: Text(l.searchCurrency),
              onPressed: () async {
                final selected = await pickCurrency(context, selected: quote);
                if (selected != null && mounted) {
                  setState(() => quote = selected);
                  await load();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _rate(String label, RateResolution rate) {
    final l = context.l10n, o = rate.observation;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text('1 $base = ${rate.rate} $quote'),
          ),
        ],
      ),
      subtitle: Text(
        [
          if (o != null) o.source,
          if (rate.manual) l.manualOverride,
          if (o != null)
            '${l.rateAsOf}: \u2066${DateFormat('yyyy-MM-dd', 'en').format(o.effectiveAt.toLocal())}\u2069',
          if (o != null)
            '${l.rateFetched}: \u2066${DateFormat('yyyy-MM-dd HH:mm', 'en').format(o.retrievedAt.toLocal())}\u2069',
          if (o != null &&
              DateTime.now().difference(o.retrievedAt) >=
                  const Duration(hours: 24))
            l.rateStale,
        ].join('\n'),
      ),
    );
  }
}
