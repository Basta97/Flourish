import 'currency_catalog.dart';
import 'package:drift/drift.dart' show Variable;
import 'valuation_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';

abstract interface class FxRateProvider {
  Future<List<MarketObservation>> fetch(
    String base,
    Set<String> quotes, {
    DateTime? at,
  });
}

abstract interface class QuoteProvider {
  Future<MarketObservation?> fetch(Holding holding);
}

class FrankfurterProvider implements FxRateProvider, CurrencyCatalogProvider {
  @override
  Future<List<CurrencyInfo>> currencies() async {
    final response = await client
        .get(Uri.https('api.frankfurter.dev', '/v2/currencies'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Currency catalog unavailable');
    }
    return (jsonDecode(response.body) as List)
        .map((j) => CurrencyInfo.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  final http.Client client;
  FrankfurterProvider(this.client);
  @override
  Future<List<MarketObservation>> fetch(
    String base,
    Set<String> quotes, {
    DateTime? at,
  }) async {
    final response = await client
        .get(
          Uri.https('api.frankfurter.dev', '/v2/rates', {
            'base': base,
            'quotes': quotes.join(','),
            if (at != null) 'date': at.toIso8601String().substring(0, 10),
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('FX provider unavailable (${response.statusCode})');
    }
    final rows = jsonDecode(response.body) as List;
    return rows
        .map(
          (r) => MarketObservation(
            key: '${r['base']}/${r['quote']}',
            currency: r['quote'],
            source: at == null
                ? 'Frankfurter reference'
                : 'Frankfurter historical reference',
            value: amountOf(r['rate']),
            effectiveAt: DateTime.parse(r['date']).toUtc(),
            retrievedAt: DateTime.now().toUtc(),
          ),
        )
        .toList();
  }
}

class PublicQuoteProvider implements QuoteProvider {
  final http.Client client;
  final Future<String?> Function() apiKey;
  final FinanceStore store;
  PublicQuoteProvider(this.client, this.store, this.apiKey);
  @override
  Future<MarketObservation?> fetch(Holding h) async {
    Uri url;
    String? securityCurrency;
    if (h.kind == AssetKind.gold) {
      url = Uri.https('api.gold-api.com', '/price/XAU');
    } else if (h.kind == AssetKind.crypto && h.symbol.isNotEmpty) {
      url = Uri.https(
        'api.coinbase.com',
        '/v2/prices/${h.symbol.toUpperCase()}-USD/spot',
      );
    } else if ((h.kind == AssetKind.stock || h.kind == AssetKind.fund) &&
        h.exchange.toUpperCase() != 'EGX') {
      final key = await apiKey();
      if (key == null || key.isEmpty || h.symbol.isEmpty) return null;
      final day = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final count =
          (await store.get('providerUsage', day))?['count'] as int? ?? 0;
      if (count >= 25) {
        throw StateError(
          'Alpha Vantage daily allowance reached; cached prices retained',
        );
      }
      await store.put('providerUsage', day, {'count': count + 1});
      final instrument = await store.get('instrumentInfo', h.symbol);
      securityCurrency = instrument?['currency'] as String?;
      if (securityCurrency == null) {
        if (count >= 24) {
          throw StateError(
            'Insufficient daily quote allowance for instrument lookup',
          );
        }
        await store.put('providerUsage', day, {'count': count + 2});
        final response = await client
            .get(
              Uri.https('www.alphavantage.co', '/query', {
                'function': 'SYMBOL_SEARCH',
                'keywords': h.symbol,
                'apikey': key,
              }),
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw StateError('Instrument metadata unavailable');
        }
        final matches =
            (jsonDecode(response.body)['bestMatches'] as List? ?? [])
                .cast<Json>();
        final match = matches
            .where(
              (m) =>
                  m['1. symbol'].toString().toUpperCase() ==
                  h.symbol.toUpperCase(),
            )
            .firstOrNull;
        securityCurrency = match?['8. currency'] as String?;
        if (securityCurrency == null) {
          throw StateError(
            'Confirm the provider ticker or enter a manual quote',
          );
        }
        await store.put('instrumentInfo', h.symbol, {
          'currency': securityCurrency,
        });
      }
      url = Uri.https('www.alphavantage.co', '/query', {
        'function': 'GLOBAL_QUOTE',
        'symbol': h.symbol,
        'apikey': key,
      });
    } else {
      return null;
    }
    final response = await client.get(url).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Price provider unavailable (${response.statusCode})');
    }
    final j = jsonDecode(response.body) as Json;
    final now = DateTime.now().toUtc();
    if (h.kind == AssetKind.gold) {
      if (j['currency'] != 'USD') {
        throw StateError('Unexpected gold quote currency');
      }
      return MarketObservation(
        key: h.id,
        currency: 'USD',
        source: 'Gold API spot estimate',
        value:
            amountOf(j['price']) /
            Amount('31.1034768') *
            Amount('${h.karat}') /
            Amount('24'),
        effectiveAt: DateTime.parse(j['updatedAt']),
        retrievedAt: now,
      );
    }
    if (h.kind == AssetKind.crypto) {
      return MarketObservation(
        key: h.id,
        currency: 'USD',
        source: 'Coinbase spot',
        value: amountOf((j['data'] as Json)['amount']),
        effectiveAt: now,
        retrievedAt: now,
      );
    }
    final quote = j['Global Quote'] as Json?;
    if (quote == null || quote['05. price'] == null) {
      throw StateError('No supported end-of-day quote for ${h.symbol}');
    }
    return MarketObservation(
      key: h.id,
      currency: securityCurrency!,
      source: 'Alpha Vantage end of day',
      value: amountOf(quote['05. price']),
      effectiveAt: DateTime.parse(quote['07. latest trading day']),
      retrievedAt: now,
    );
  }
}

class MarketDataService {
  final FinanceStore store;
  final FxRateProvider fx;
  final QuoteProvider quotes;
  MarketDataService(this.store, this.fx, this.quotes);
  bool refreshing = false;
  final List<String> warnings = [];
  Future<void> save(String collection, MarketObservation observation) async {
    if (observation.value <= Amount.zero) {
      throw ArgumentError('Price or rate must be positive');
    }
    if (observation.effectiveAt.isAfter(
      DateTime.now().add(const Duration(minutes: 5)),
    )) {
      throw ArgumentError('Observation cannot be in the future');
    }
    await store.put(
      collection,
      '${observation.key}:${observation.manual ? 'manual' : 'auto'}:${observation.effectiveAt.toIso8601String()}',
      observation.toJson(),
    );
  }

  Future<void> clearManual(String collection, String key) async {
    final rows = await store.db
        .customSelect(
          'SELECT id,payload FROM finance_records WHERE collection = ?',
          variables: [Variable(collection)],
        )
        .get();
    for (final row in rows) {
      final j = jsonDecode(row.read<String>('payload')) as Json;
      if (j['key'] == key && j['manual'] == true) {
        await store.remove(collection, row.read<String>('id'));
      }
    }
  }

  final Map<String, Future<void>> _pairRequests = {};
  Future<void> refreshPairs(
    String base,
    Set<String> quotes, {
    bool force = false,
  }) {
    final sorted = quotes.where((q) => q != base).toList()..sort();
    final key = '$base/${sorted.join(',')}';
    return _pairRequests.putIfAbsent(
      key,
      () => _refreshPairs(base, sorted.toSet(), force).whenComplete(() {
        _pairRequests.remove(key);
      }),
    );
  }

  Future<void> _refreshPairs(
    String base,
    Set<String> quotes,
    bool force,
  ) async {
    final rows = (await store.list(
      'fx',
    )).map(MarketObservation.fromJson).toList();
    final needed = quotes
        .where(
          (q) =>
              force ||
              !rows.any(
                (r) =>
                    r.key == '$base/$q' &&
                    !r.manual &&
                    !r.source.contains('historical') &&
                    DateTime.now().difference(r.retrievedAt) <
                        const Duration(hours: 24),
              ),
        )
        .toSet();
    if (needed.isEmpty) return;
    final fetched = await fx.fetch(base, needed);
    for (final r in fetched) {
      await save('fx', r);
    }
    if (needed.any((q) => !fetched.any((r) => r.key == '$base/$q'))) {
      throw StateError('Some currency pairs are unavailable');
    }
  }

  Future<void> refresh({
    required String reportingCurrency,
    bool force = false,
  }) async {
    if (refreshing) return;
    refreshing = true;
    warnings.clear();
    try {
      final holdings = await PortfolioRepository(store).getAll();
      final contracts = await ContractRepository(store).getAll();
      final accounts = await store.db.getAllAccounts();
      final currencies = {
        reportingCurrency,
        'USD',
        ...accounts.map((a) => a.currency),
        ...holdings.map((h) => h.currency),
        ...contracts.map((c) => c.currency),
      };
      final observations = [
        ...await store.list('fx'),
        ...await store.list('prices'),
      ].map(MarketObservation.fromJson).toList();
      final now = DateTime.now();
      bool fresh(String key) => observations.any(
        (o) =>
            o.key == key &&
            !o.manual &&
            !o.source.contains('historical') &&
            now.difference(o.retrievedAt).inHours < 24,
      );
      final requests = <String, Set<String>>{};
      for (final currency in currencies) {
        // Only currencies actually used by finances, never the full catalog.
        // Keep cross-account conversions available without changing valuation semantics.
        requests[currency] = currencies.where((c) => c != currency).toSet();
      }
      for (final favorite in await store.list('fxFavorites')) {
        final parts = '${favorite['pair']}'.split('/');
        if (parts.length == 2) {
          requests.putIfAbsent(parts[0], () => {}).add(parts[1]);
        }
      }
      for (final entry in requests.entries) {
        try {
          await refreshPairs(entry.key, entry.value, force: force);
        } catch (_) {
          warnings.add(
            'Could not refresh ${entry.key} exchange rates; cached values retained.',
          );
        }
      }
      // Backfill missing historical FX in bounded batches; incomplete records stay visible.
      final valuation = ValuationService(store);
      var historicalRequests = 0;
      final attempted = <String>{};
      for (final t in await store.db.getAllTransactions()) {
        if (historicalRequests >= 31) {
          warnings.add(
            'More historical exchange rates will be fetched on the next refresh.',
          );
          break;
        }
        final account = accounts.where((a) => a.id == t.accountId).firstOrNull;
        if (account == null || account.currency == reportingCurrency) continue;
        if (await valuation.transactionValue(t.id, reportingCurrency) != null) {
          continue;
        }
        final key =
            '${account.currency}/${t.transactionDate.toIso8601String().substring(0, 10)}';
        if (!attempted.add(key)) continue;
        historicalRequests++;
        try {
          for (final rate in await fx.fetch(account.currency, {
            reportingCurrency,
          }, at: t.transactionDate)) {
            await save('fx', rate);
          }
          await valuation.transactionValue(t.id, reportingCurrency);
        } catch (_) {
          warnings.add('Historical conversion unavailable for $key.');
        }
      }
      for (final h in holdings.where((h) => h.valuation != 'manual')) {
        if (!force && fresh(h.id)) continue;
        try {
          final quote = await quotes.fetch(h);
          if (quote != null) {
            await save('prices', quote);
          } else {
            warnings.add('${h.name}: enter a dated manual quote.');
          }
        } catch (_) {
          warnings.add('${h.name}: quote unavailable; cached values retained.');
        }
      }
    } finally {
      refreshing = false;
      store.db.notifyFinanceChanged();
    }
  }
}
