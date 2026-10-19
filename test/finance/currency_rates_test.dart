import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/data/finance/finance_store.dart';
import 'package:flourish/core/finance/currency_catalog.dart';
import 'package:flourish/core/finance/market_data_service.dart';
import 'package:flourish/core/finance/valuation_service.dart';
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/domain/finance/models.dart';

class _NoQuotes implements QuoteProvider {
  @override
  Future<MarketObservation?> fetch(Holding holding) async => null;
}

void main() {
  late AppDatabase db;
  late FinanceStore store;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = FinanceStore(db);
  });
  tearDown(() => db.close());
  test(
    'provider catalog caches and offline bundle covers expanded currencies',
    () async {
      var calls = 0;
      final provider = FrankfurterProvider(
        MockClient((request) async {
          calls++;
          return http.Response(
            jsonEncode([
              {'iso_code': 'EGP', 'name': 'Egyptian Pound'},
              {'iso_code': 'BRL', 'name': 'Brazilian Real'},
            ]),
            200,
          );
        }),
      );
      final catalog = CurrencyCatalog(store, provider);
      expect(CurrencyCatalog.bundled.length, greaterThan(100));
      expect(CurrencyCatalog.bundled.any((c) => c.code == 'BRL'), true);
      expect((await catalog.load()).length, 2);
      await catalog.load();
      expect(calls, 1);
      final offline = CurrencyCatalog(
        store,
        FrankfurterProvider(MockClient((_) async => http.Response('', 503))),
      );
      expect((await offline.load(force: true)).map((c) => c.code), [
        'EGP',
        'BRL',
      ]);
    },
  );
  test('selected pair requests deduplicate, cache and force-refresh', () async {
    var calls = 0;
    final provider = FrankfurterProvider(
      MockClient((request) async {
        calls++;
        expect(request.url.queryParameters['base'], 'USD');
        expect(request.url.queryParameters['quotes'], 'EGP');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return http.Response(
          '[{"base":"USD","quote":"EGP","rate":50.123456,"date":"2026-10-19"}]',
          200,
        );
      }),
    );
    final market = MarketDataService(store, provider, _NoQuotes());
    await Future.wait([
      market.refreshPairs('USD', {'EGP'}),
      market.refreshPairs('USD', {'EGP'}),
    ]);
    expect(calls, 1);
    await market.refreshPairs('USD', {'EGP'});
    expect(calls, 1);
    await market.refreshPairs('USD', {'EGP'}, force: true);
    expect(calls, 2);
    expect(
      (await ValuationService(store).resolveRate('USD', 'EGP'))!.rate,
      Amount('50.123456'),
    );
  });
  test(
    'manual inverse wins over automatic direct, reference remains separate',
    () async {
      final market = MarketDataService(
        store,
        FrankfurterProvider(MockClient((_) async => http.Response('', 503))),
        _NoQuotes(),
      );
      MarketObservation observation(String pair, String value, bool manual) =>
          MarketObservation(
            key: pair,
            currency: pair.split('/').last,
            source: manual ? 'Manual' : 'Frankfurter reference',
            value: Amount(value),
            effectiveAt: DateTime.now().toUtc(),
            retrievedAt: DateTime.now().toUtc(),
            manual: manual,
          );
      await market.save('fx', observation('USD/EGP', '55', true));
      await market.save('fx', observation('EGP/USD', '0.02', false));
      final valuation = ValuationService(store);
      final rate = await valuation.resolveRate('EGP', 'USD');
      expect(rate!.manual, true);
      expect(rate.inverse, true);
      expect(await valuation.convert(Amount('110'), 'EGP', 'USD'), Amount('2'));
      expect(
        (await valuation.resolveRate('EGP', 'USD', automaticOnly: true))!.rate,
        Amount('0.02'),
      );
      await market.clearManual('fx', 'USD/EGP');
      expect((await valuation.resolveRate('EGP', 'USD'))!.manual, false);
      expect((await valuation.resolveRate('EGP', 'EGP'))!.rate, Amount.one);
      expect(await valuation.resolveRate('CAD', 'BRL'), isNull);
    },
  );
  test('missing pair reports failure but preserves cached rates', () async {
    final provider = FrankfurterProvider(
      MockClient((_) async => http.Response('[]', 200)),
    );
    final market = MarketDataService(store, provider, _NoQuotes());
    await expectLater(market.refreshPairs('USD', {'BRL'}), throwsStateError);
  });
  test('ISO minor units include zero, three and four decimal currencies', () {
    expect(CurrencyFormatter.decimalsFor('JPY'), 0);
    expect(CurrencyFormatter.decimalsFor('KWD'), 3);
    expect(CurrencyFormatter.decimalsFor('IQD'), 3);
    expect(CurrencyFormatter.decimalsFor('CLF'), 4);
    expect(CurrencyFormatter.decimalsFor('EGP'), 2);
  });
}
