import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/data/finance/finance_store.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/core/finance/contract_service.dart';
import 'package:flourish/core/finance/valuation_service.dart';
import 'package:flourish/core/finance/market_data_service.dart';
import 'package:flourish/domain/finance/models.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

void main() {
  late AppDatabase db;
  late FinancialLedgerService ledger;
  late FinanceStore store;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = FinancialLedgerService(db);
    store = ledger.store;
  });
  tearDown(() async {
    await db.close();
  });
  Future<int> account(
    String name, {
    String currency = 'EGP',
    String balance = '1000',
    String type = 'bank',
  }) => db.insertAccount(
    AccountsCompanion.insert(
      name: name,
      type: type,
      color: 0xFF000000,
      icon: 'account_balance',
      currency: Value(currency),
      balance: Value(Amount(balance).toDouble()),
    ),
  );
  Holding holding(
    String id, {
    String quantity = '0',
    String? cost = '0',
    String currency = 'EGP',
    AssetKind kind = AssetKind.stock,
    int karat = 24,
  }) => Holding(
    id: id,
    name: id,
    kind: kind,
    quantity: Amount(quantity),
    currency: currency,
    costBasis: cost == null ? null : Amount(cost),
    openedAt: DateTime(2026, 1, 1),
    ownership: Amount.one,
    karat: karat,
  );
  Future<void> rate(
    String from,
    String to,
    String value, {
    DateTime? date,
    bool manual = false,
  }) => store.put(
    'fx',
    '$from/$to:${date ?? DateTime(2026, 1, 1)}:$manual',
    MarketObservation(
      key: '$from/$to',
      currency: to,
      source: 'Acceptance fixture',
      value: Amount(value),
      effectiveAt: date ?? DateTime(2026, 1, 1),
      retrievedAt: date ?? DateTime(2026, 1, 1),
      manual: manual,
    ).toJson(),
  );

  test('decimal arithmetic retains fractional units exactly', () {
    expect('${Amount('0.1') + Amount('0.2')}', '0.3');
    expect('${Amount('0.00000001') * Amount('12345678')}', '0.12345678');
    expect(Amount.fromNum(1e-8), Amount('0.00000001'));
  });
  test(
    'editing the same account replaces the old expense, preserving note snapshots',
    () async {
      final id = await account('Cash');
      final tx = await ledger.recordCash(
        accountId: id,
        amount: Amount('100'),
        type: 'expense',
      );
      final current = (await db.getTransactionById(tx))!;
      await ledger.updateTransactionAndUpdateBalance(
        current.copyWith(amount: 150),
      );
      expect(await store.balance(id), Amount('850'));
      await ledger.deleteTransactionAndUpdateBalance(tx);
      expect(await store.balance(id), Amount('1000'));
    },
  );
  test(
    'exact cash reversal does not lose precision at the legacy REAL boundary',
    () async {
      final id = await account('Cash');
      final tx = await ledger.recordCash(
        accountId: id,
        amount: Amount('0.123456789123456789'),
        type: 'expense',
      );
      await ledger.deleteTransactionAndUpdateBalance(tx);
      expect(await store.balance(id), Amount('1000'));
    },
  );
  test('cross-currency transfer edits and deletes both legs and fee', () async {
    final usd = await account('USD', currency: 'USD'),
        egp = await account('EGP', balance: '0');
    await ledger.transfer(
      fromAccountId: usd,
      toAccountId: egp,
      amount: Amount('100'),
      received: Amount('5000'),
      fee: Amount('2'),
    );
    expect(await store.balance(usd), Amount('898'));
    expect(await store.balance(egp), Amount('5000'));
    final original = (await db.getAllTransactions()).firstWhere(
      (t) => t.linkedTransactionId != null,
    );
    await ledger.transfer(
      fromAccountId: usd,
      toAccountId: egp,
      amount: Amount('50'),
      received: Amount('2600'),
      fee: Amount('1'),
      editId: original.id,
    );
    expect(await store.balance(usd), Amount('949'));
    expect(await store.balance(egp), Amount('2600'));
    final incoming = (await db.getAllTransactions()).firstWhere(
      (t) => t.type == 'income',
    );
    await ledger.deleteTransactionAndUpdateBalance(incoming.id);
    expect(await store.balance(usd), Amount('1000'));
    expect(await store.balance(egp), Amount.zero);
    expect(await db.getAllTransactions(), isEmpty);
  });
  test(
    'invalid cross-currency transfers roll back without touching balances',
    () async {
      final from = await account('USD', currency: 'USD'),
          to = await account('EGP');
      await expectLater(
        ledger.transfer(
          fromAccountId: from,
          toAccountId: to,
          amount: Amount('10'),
        ),
        throwsArgumentError,
      );
      expect(await store.balance(from), Amount('1000'));
      expect(await db.getAllTransactions(), isEmpty);
    },
  );
  test(
    'historical spending snapshot remains fixed after refreshed FX',
    () async {
      final id = await account('USD', currency: 'USD');
      await rate('USD', 'EGP', '50');
      final tx = await ledger.recordCash(
        accountId: id,
        amount: Amount('10'),
        type: 'expense',
        date: DateTime(2026, 1, 2),
      );
      await rate('USD', 'EGP', '60', date: DateTime(2026, 2, 1));
      final valuation = ValuationService(store);
      expect(await valuation.transactionValue(tx, 'EGP'), Amount('500'));
      expect(
        await valuation.convert(Amount('10'), 'USD', 'EGP'),
        Amount('600'),
      );
    },
  );
  test(
    'purchase, partial sale, fees, and split reconcile cash and weighted cost',
    () async {
      final id = await account('Cash');
      await ledger.openHolding(holding('stock'));
      await ledger.trade(
        holdingId: 'stock',
        kind: ActivityKind.buy,
        quantity: Amount('10'),
        unitPrice: Amount('20'),
        accountId: id,
        fee: Amount('2'),
      );
      expect(await store.balance(id), Amount('798'));
      expect((await ledger.portfolio.get('stock'))!.costBasis, Amount('202'));
      await ledger.trade(
        holdingId: 'stock',
        kind: ActivityKind.sell,
        quantity: Amount('4'),
        unitPrice: Amount('30'),
        accountId: id,
        fee: Amount('1'),
      );
      final h = (await ledger.portfolio.get('stock'))!;
      expect(h.quantity, Amount('6'));
      expect(h.costBasis, Amount('121.2'));
      expect(await store.balance(id), Amount('917'));
      final sale = (await ledger.portfolio.activity(
        'stock',
      )).firstWhere((a) => a['kind'] == 'sell');
      expect(amountOf(sale['realizedGain']), Amount('38.2'));
      await ledger.split('stock', Amount('2'));
      expect((await ledger.portfolio.get('stock'))!.quantity, Amount('12'));
      expect((await ledger.portfolio.get('stock'))!.costBasis, Amount('121.2'));
      await expectLater(
        ledger.trade(
          holdingId: 'stock',
          kind: ActivityKind.sell,
          quantity: Amount('13'),
          unitPrice: Amount('1'),
          accountId: id,
        ),
        throwsArgumentError,
      );
      expect(await store.balance(id), Amount('917'));
    },
  );
  test('unknown opening cost is never replaced with zero', () async {
    final id = await account('Cash');
    await ledger.openHolding(holding('unknown', quantity: '2', cost: null));
    await ledger.trade(
      holdingId: 'unknown',
      kind: ActivityKind.buy,
      quantity: Amount.one,
      unitPrice: Amount('20'),
      accountId: id,
    );
    expect((await ledger.portfolio.get('unknown'))!.costBasis, isNull);
  });
  test(
    'missing prices mark wealth incomplete rather than pretending to be zero',
    () async {
      await account('Cash');
      await ledger.openHolding(
        holding(
          'property',
          quantity: '1',
          cost: '500',
          kind: AssetKind.property,
        ),
      );
      final value = await ValuationService(store).summary('EGP');
      expect(value.complete, isFalse);
      expect(value.netWorth, Amount('1000'));
      expect(
        value.items.firstWhere((i) => i.id == 'property').converted,
        isNull,
      );
    },
  );
  test('manual gold quote overrides a newer automated estimate', () async {
    await ledger.openHolding(
      holding(
        'gold',
        kind: AssetKind.gold,
        quantity: '10',
        cost: '100',
        karat: 21,
      ),
    );
    final now = DateTime.now();
    for (final manual in [true, false]) {
      await store.put(
        'prices',
        '$manual',
        MarketObservation(
          key: 'gold',
          currency: 'EGP',
          source: manual ? 'Local resale' : 'Spot estimate',
          value: Amount(manual ? '4000' : '3900'),
          effectiveAt: manual ? now.subtract(const Duration(days: 1)) : now,
          retrievedAt: now,
          manual: manual,
        ).toJson(),
      );
    }
    final summary = await ValuationService(store).summary('EGP');
    expect(summary.assets, Amount('40000'));
    expect(
      summary.items.firstWhere((i) => i.id == 'gold').source,
      'Local resale',
    );
  });
  test('gold quote transforms troy ounces and purity exactly', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"currency":"USD","price":3110.34768,"updatedAt":"2026-01-01T00:00:00Z"}',
        200,
      ),
    );
    final provider = PublicQuoteProvider(client, store, () async => null);
    final quote = await provider.fetch(
      holding('gold', kind: AssetKind.gold, karat: 21),
    );
    expect(quote!.value, Amount('87.5'));
    client.close();
  });
  test(
    'certificate expected coupons do not change cash; confirmation is idempotent',
    () async {
      final id = await account('Cash');
      final c = FinanceContract(
        id: 'certificate',
        name: 'Certificate',
        kind: ContractKind.certificate,
        currency: 'EGP',
        principal: Amount('1200'),
        annualRate: Amount('12'),
        start: DateTime(2026, 1, 31),
        maturity: DateTime(2027, 1, 31),
        accountId: id,
      );
      final service = ContractService(ledger);
      await service.create(c);
      final payments = await ContractRepository(store).payments(c.id);
      expect(payments.length, 12);
      expect(payments.first.date, DateTime(2026, 2, 28));
      expect(payments[1].date, DateTime(2026, 3, 31));
      expect(payments.first.interest, Amount('12'));
      expect(await store.balance(id), Amount('1000'));
      await service.confirm(payments.first.id);
      await service.confirm(payments.first.id);
      expect(await store.balance(id), Amount('1012'));
    },
  );
  test(
    'loan repayments separate interest expense and reduce principal',
    () async {
      final id = await account('Cash');
      final c = FinanceContract(
        id: 'loan',
        name: 'Loan',
        kind: ContractKind.loan,
        currency: 'EGP',
        principal: Amount('1200'),
        annualRate: Amount('12'),
        start: DateTime(2026, 1, 1),
        maturity: DateTime(2027, 1, 1),
        accountId: id,
      );
      final service = ContractService(ledger);
      await service.create(c);
      final p = (await ContractRepository(store).payments(c.id)).first;
      await service.confirm(p.id);
      expect(await store.balance(id), Amount('888'));
      final wealth = await ValuationService(store).summary('EGP');
      expect(wealth.liabilities, Amount('1100'));
      expect(wealth.netWorth, Amount('-212'));
    },
  );
  test(
    'recurring catch-up anchors month end and concurrent retries do not duplicate',
    () async {
      final id = await account('Cash'),
          category = (await db.getAllCategories()).firstWhere(
            (c) => c.type == 'income',
          );
      await db.insertRecurringTransaction(
        RecurringTransactionsCompanion.insert(
          accountId: id,
          categoryId: category.id,
          amount: 10,
          type: 'income',
          frequency: 'monthly',
          nextDate: DateTime(2026, 1, 31),
        ),
      );
      await Future.wait([
        db.processDueRecurringTransactions(now: DateTime(2026, 3, 31)),
        db.processDueRecurringTransactions(now: DateTime(2026, 3, 31)),
      ]);
      expect((await db.getAllTransactions()).length, 3);
      expect(await store.balance(id), Amount('1030'));
      expect(
        (await db.getActiveRecurringTransactions()).single.nextDate,
        DateTime(2026, 4, 30),
      );
    },
  );
  test(
    'holding gains separate market appreciation from FX on acquisition cost',
    () async {
      await rate('USD', 'EGP', '40', date: DateTime(2026, 1, 1));
      await ledger.openHolding(
        holding('dollar-stock', quantity: '1', cost: '100', currency: 'USD'),
      );
      await rate('USD', 'EGP', '50', date: DateTime(2026, 2, 1));
      await store.put(
        'prices',
        'quote',
        MarketObservation(
          key: 'dollar-stock',
          currency: 'USD',
          source: 'Acceptance price',
          value: Amount('110'),
          effectiveAt: DateTime(2026, 2, 1),
          retrievedAt: DateTime(2026, 2, 1),
        ).toJson(),
      );
      final item = (await ValuationService(
        store,
      ).summary('EGP')).items.firstWhere((i) => i.id == 'dollar-stock');
      expect(item.converted, Amount('5500'));
      expect(item.gain, Amount('500'));
      expect(item.fxGain, Amount('1000'));
    },
  );
  test(
    'reducing-balance payments settle exactly, including currency rounding',
    () async {
      final c = FinanceContract(
        id: 'reducing',
        name: 'Loan',
        kind: ContractKind.loan,
        currency: 'EGP',
        principal: Amount('1000'),
        annualRate: Amount('13'),
        start: DateTime(2026, 1, 31),
        maturity: DateTime(2027, 1, 31),
        interestMethod: 'reducing',
      );
      final rows = ContractService(ledger).schedule(c);
      expect(
        rows.fold(Amount.zero, (sum, p) => sum + p.principal),
        Amount('1000'),
      );
      expect(rows.first.interest, Amount('10.83'));
      expect(rows[1].date, DateTime(2026, 3, 31));
      for (final p in rows) {
        expect(p.principal >= Amount.zero, isTrue);
        expect(p.interest >= Amount.zero, isTrue);
      }
    },
  );
  test(
    'linked credit billing does not count the card liability twice',
    () async {
      final cash = await account('Cash'),
          card = await account('Card', type: 'credit', balance: '100');
      final c = FinanceContract(
        id: 'card',
        name: 'Card billing',
        kind: ContractKind.creditCard,
        currency: 'EGP',
        principal: Amount.zero,
        annualRate: Amount.zero,
        start: DateTime(2026, 1, 1),
        maturity: DateTime(2027, 1, 1),
        accountId: cash,
        cardAccountId: card,
      );
      await ContractService(ledger).create(c);
      expect(
        (await ValuationService(store).summary('EGP')).liabilities,
        Amount('100'),
      );
      await ledger.transfer(
        fromAccountId: cash,
        toAccountId: card,
        amount: Amount('40'),
      );
      expect(await store.balance(card), Amount('60'));
      expect(
        (await ValuationService(store).summary('EGP')).netWorth,
        Amount('900'),
      );
    },
  );
  test('automatic security quotes use the verified market currency', () async {
    final client = MockClient(
      (request) async => http.Response(
        request.url.queryParameters['function'] == 'SYMBOL_SEARCH'
            ? '{"bestMatches":[{"1. symbol":"IBM","8. currency":"USD"}]}'
            : '{"Global Quote":{"05. price":"200","07. latest trading day":"2026-10-14"}}',
        200,
      ),
    );
    final h = Holding(
      id: 'ibm',
      name: 'IBM',
      kind: AssetKind.stock,
      quantity: Amount.one,
      currency: 'EGP',
      openedAt: DateTime(2026, 1, 1),
      ownership: Amount.one,
      symbol: 'IBM',
      exchange: 'NYSE',
      valuation: 'automatic',
    );
    final quote = await PublicQuoteProvider(
      client,
      store,
      () async => 'acceptance-key',
    ).fetch(h);
    expect(quote!.currency, 'USD');
    expect(quote.value, Amount('200'));
    client.close();
  });
  test(
    'confirmed loan payments reverse as a whole and cannot be deleted by one leg',
    () async {
      final id = await account('Cash');
      final c = FinanceContract(
        id: 'reversible',
        name: 'Loan',
        kind: ContractKind.loan,
        currency: 'EGP',
        principal: Amount('1200'),
        annualRate: Amount('12'),
        start: DateTime(2026, 1, 1),
        maturity: DateTime(2027, 1, 1),
        accountId: id,
      );
      final service = ContractService(ledger);
      await service.create(c);
      final p = (await ContractRepository(store).payments(c.id)).first;
      await service.confirm(p.id);
      final tx = (await db.getAllTransactions()).first;
      await expectLater(
        ledger.deleteTransactionAndUpdateBalance(tx.id),
        throwsStateError,
      );
      await service.reverseConfirmation(p.id);
      expect(await store.balance(id), Amount('1000'));
      expect(
        (await ContractRepository(store).payments(c.id)).first.paid,
        isFalse,
      );
      expect(await db.getAllTransactions(), isEmpty);
    },
  );
  test(
    'early settlement reversal restores the original pending schedule',
    () async {
      final id = await account('Cash', balance: '5000');
      final c = FinanceContract(
        id: 'early',
        name: 'Loan',
        kind: ContractKind.loan,
        currency: 'EGP',
        principal: Amount('1200'),
        annualRate: Amount('12'),
        start: DateTime(2026, 1, 1),
        maturity: DateTime(2027, 1, 1),
        accountId: id,
      );
      final service = ContractService(ledger);
      await service.create(c);
      await service.earlySettle(c.id, id, Amount('1200'), Amount('20'));
      expect(await store.balance(id), Amount('3780'));
      final p = (await ContractRepository(store).payments(c.id)).single;
      await service.reverseConfirmation(p.id);
      expect(await store.balance(id), Amount('5000'));
      expect((await ContractRepository(store).payments(c.id)).length, 12);
    },
  );
  test('failed providers keep cached prices and expose staleness', () async {
    final h = Holding(
      id: 'cached',
      name: 'Gold',
      kind: AssetKind.gold,
      quantity: Amount('2'),
      currency: 'EGP',
      openedAt: DateTime(2026, 1, 1),
      ownership: Amount.one,
      valuation: 'automatic',
    );
    await ledger.openHolding(h);
    final old = DateTime.now().subtract(const Duration(days: 4));
    await store.put(
      'prices',
      'cached-price',
      MarketObservation(
        key: h.id,
        currency: 'EGP',
        source: 'Last successful quote',
        value: Amount('3000'),
        effectiveAt: old,
        retrievedAt: old,
      ).toJson(),
    );
    final client = MockClient((_) async => http.Response('Unavailable', 503));
    final market = MarketDataService(
      store,
      FrankfurterProvider(client),
      PublicQuoteProvider(client, store, () async => null),
    );
    await market.refresh(reportingCurrency: 'EGP');
    final wealth = await ValuationService(store).summary('EGP');
    expect(wealth.assets, Amount('6000'));
    expect(wealth.complete, isTrue);
    expect(wealth.stale, isTrue);
    expect(market.warnings, isNotEmpty);
    client.close();
  });
  test(
    'shared property valuation and linked mortgages do not double count debt',
    () async {
      final loan = FinanceContract(
        id: 'mortgage',
        name: 'Mortgage',
        kind: ContractKind.loan,
        currency: 'EGP',
        principal: Amount('300'),
        annualRate: Amount.zero,
        start: DateTime(2026, 1, 1),
        maturity: DateTime(2027, 1, 1),
        interestMethod: 'manual',
      );
      await ContractService(ledger).create(loan);
      for (final id in ['property-a', 'property-b']) {
        await ledger.openHolding(
          Holding(
            id: id,
            name: id,
            kind: AssetKind.property,
            quantity: Amount.one,
            currency: 'EGP',
            openedAt: DateTime(2026, 1, 1),
            ownership: Amount('0.5'),
          ),
        );
        await ledger.linkPropertyDebt(id, loan.id);
        await store.put(
          'prices',
          id,
          MarketObservation(
            key: id,
            currency: 'EGP',
            source: 'Manual appraisal',
            value: Amount('1000'),
            effectiveAt: DateTime(2026, 1, 1),
            retrievedAt: DateTime(2026, 1, 1),
            manual: true,
          ).toJson(),
        );
      }
      final wealth = await ValuationService(store).summary('EGP');
      expect(wealth.assets, Amount('1000'));
      expect(wealth.liabilities, Amount('300'));
      expect(wealth.netWorth, Amount('700'));
    },
  );
  test(
    'a newly downloaded historical rate never suppresses the current daily refresh',
    () async {
      await account('USD cash', currency: 'USD', balance: '1');
      await store.put(
        'fx',
        'old-rate',
        MarketObservation(
          key: 'USD/EGP',
          currency: 'EGP',
          source: 'Frankfurter historical reference',
          value: Amount('40'),
          effectiveAt: DateTime(2020, 1, 1),
          retrievedAt: DateTime.now(),
        ).toJson(),
      );
      var refreshed = false;
      final client = MockClient((request) async {
        final base = request.url.queryParameters['base'];
        if (base == 'USD') {
          refreshed = true;
          return http.Response(
            '[{"date":"2026-10-14","base":"USD","quote":"EGP","rate":60}]',
            200,
          );
        }
        return http.Response(
          '[{"date":"2026-10-14","base":"EGP","quote":"USD","rate":0.0166666667}]',
          200,
        );
      });
      await MarketDataService(
        store,
        FrankfurterProvider(client),
        PublicQuoteProvider(client, store, () async => null),
      ).refresh(reportingCurrency: 'EGP');
      expect(refreshed, isTrue);
      expect(
        await ValuationService(store).convert(Amount.one, 'USD', 'EGP'),
        Amount('60'),
      );
      client.close();
    },
  );
}
