import 'fx_policy.dart';
import '../../domain/finance/models.dart';
import '../../data/finance/finance_store.dart';

class ValuedItem {
  final String id, name, group, currency, source;
  final Amount original;
  final Amount? converted;
  final Amount? gain;
  final Amount? fxGain;
  final DateTime? effectiveAt;
  final bool liability, liquid;
  const ValuedItem({
    required this.id,
    required this.name,
    required this.group,
    required this.currency,
    required this.original,
    this.converted,
    this.gain,
    this.fxGain,
    this.source = '',
    this.effectiveAt,
    this.liability = false,
    this.liquid = false,
  });
}

class WealthSummary {
  final String currency;
  final List<ValuedItem> items;
  const WealthSummary(this.currency, this.items);
  bool get complete => items.every((i) => i.converted != null);
  bool get stale => items.any(
    (i) =>
        i.effectiveAt != null &&
        DateTime.now().difference(i.effectiveAt!).inHours > 72,
  );
  Amount get assets => items
      .where((i) => !i.liability)
      .fold(Amount.zero, (s, i) => s + (i.converted ?? Amount.zero));
  Amount get liabilities => items
      .where((i) => i.liability)
      .fold(Amount.zero, (s, i) => s + (i.converted ?? Amount.zero));
  Amount get netWorth => assets - liabilities;
  Amount get liquid => items
      .where((i) => i.liquid)
      .fold(Amount.zero, (s, i) => s + (i.converted ?? Amount.zero));
}

class RateResolution {
  final Amount rate;
  final MarketObservation? observation;
  final bool inverse;
  const RateResolution(this.rate, this.observation, {this.inverse = false});
  bool get manual => observation?.manual ?? false;
  Amount convert(Amount value) =>
      inverse ? value / observation!.value : value * rate;
}

class ValuationService {
  final FinanceStore store;
  ValuationService(this.store);
  Future<MarketObservation?> observation(
    String collection,
    String key, {
    DateTime? at,
    bool automaticOnly = false,
  }) async {
    final matches = (await store.list(collection))
        .map(MarketObservation.fromJson)
        .where(
          (o) =>
              o.key == key &&
              (!automaticOnly ||
                  (!o.manual && !o.source.contains('historical'))) &&
              (at == null || FxPolicy.usableFor(o.effectiveAt, at)),
        )
        .toList();
    // Current values: a manual quote stays authoritative until cleared.
    // Dated values: a manual quote wins only inside the historical window.
    matches.sort((a, b) {
      if (a.manual != b.manual) return a.manual ? -1 : 1;
      return b.effectiveAt.compareTo(a.effectiveAt);
    });
    return matches.firstOrNull;
  }

  Future<RateResolution?> resolveRate(
    String from,
    String to, {
    DateTime? at,
    bool automaticOnly = false,
  }) async {
    if (from == to) return RateResolution(Amount.one, null);
    final direct = await observation(
      'fx',
      '$from/$to',
      at: at,
      automaticOnly: automaticOnly,
    );
    final inverse = await observation(
      'fx',
      '$to/$from',
      at: at,
      automaticOnly: automaticOnly,
    );
    if (direct?.manual == true) return RateResolution(direct!.value, direct);
    if (inverse?.manual == true) {
      return RateResolution(
        Amount.one / inverse!.value,
        inverse,
        inverse: true,
      );
    }
    if (direct != null) return RateResolution(direct.value, direct);
    return inverse == null
        ? null
        : RateResolution(Amount.one / inverse.value, inverse, inverse: true);
  }

  Future<Amount?> convert(
    Amount amount,
    String from,
    String to, {
    DateTime? at,
  }) async {
    if (amount == Amount.zero) return amount;
    final resolved = await resolveRate(from, to, at: at);
    return resolved?.convert(amount);
  }

  Future<Amount?> transactionValue(int id, String currency) async {
    final t = await store.db.getTransactionById(id);
    if (t == null) return null;
    final d = await store.transactionDetails(id);
    final account = await store.db.getAccountById(t.accountId);
    if (account == null) return null;
    final originalCurrency = d?['currency'] as String? ?? account.currency;
    final amount = d == null ? Amount.fromNum(t.amount) : amountOf(d['amount']);
    if (originalCurrency == currency) return amount;
    final rate = (d?['rates'] as Json?)?[currency];
    final ratedAt = (d?['ratesAt'] as Json?)?[currency] as String?;
    if (rate != null &&
        (ratedAt == null ||
            FxPolicy.usableFor(DateTime.parse(ratedAt), t.transactionDate))) {
      return amount * amountOf(rate);
    }
    final direct = await observation(
      'fx',
      '$originalCurrency/$currency',
      at: t.transactionDate,
    );
    final inverse = direct != null
        ? null
        : await observation(
            'fx',
            '$currency/$originalCurrency',
            at: t.transactionDate,
          );
    final used = direct ?? inverse;
    if (used == null) return null;
    final unitRate = direct != null ? direct.value : Amount.one / used.value;
    await store.setTransactionDetails(id, {
      ...?d,
      'amount': '$amount',
      'currency': originalCurrency,
      'kind':
          d?['kind'] ?? (t.linkedTransactionId != null ? 'transfer' : 'cash'),
      'rates': {...?(d?['rates'] as Json?), currency: '$unitRate'},
      'ratesAt': {
        ...?(d?['ratesAt'] as Json?),
        currency: used.effectiveAt.toIso8601String(),
      },
    });
    return amount * unitRate;
  }

  Future<WealthSummary> summary(String currency) async {
    final items = <ValuedItem>[];
    for (final a in await store.db.getAllAccounts()) {
      final details = await store.get('accountDetails', '${a.id}');
      if (details?['included'] == false) continue;
      final amount = await store.balance(a.id);
      final liability = a.type == 'credit'
          ? amount >= Amount.zero
          : amount < Amount.zero;
      final signed = amount.abs;
      final rate = a.currency == currency
          ? null
          : await observation('fx', '${a.currency}/$currency');
      items.add(
        ValuedItem(
          id: 'account:${a.id}',
          name: a.name,
          group: details?['group'] ?? 'Cash',
          currency: a.currency,
          original: signed,
          converted: await convert(signed, a.currency, currency),
          liability: liability,
          liquid:
              !liability && a.type != 'credit' && details?['archived'] != true,
          source: rate?.source ?? 'Account balance',
          effectiveAt: rate?.effectiveAt,
        ),
      );
    }
    for (final h in await PortfolioRepository(store).getAll()) {
      final quote = await observation('prices', h.id);
      final original = quote == null
          ? Amount.zero
          : quote.value * h.quantity * h.ownership;
      final converted = h.quantity == Amount.zero
          ? Amount.zero
          : quote == null
          ? null
          : await convert(original, quote.currency, currency);
      final historicalCost = await _historicalBasis(h, currency);
      final cost = h.costBasis == null
          ? null
          : await convert(h.costBasis!, h.currency, currency);
      items.add(
        ValuedItem(
          id: h.id,
          name: h.name,
          group: h.kind.name,
          currency: quote?.currency ?? h.currency,
          original: original,
          converted: converted,
          gain: converted != null && cost != null ? converted - cost : null,
          fxGain: cost != null && historicalCost != null
              ? cost - historicalCost
              : null,
          source: quote?.source ?? 'Missing price',
          effectiveAt: quote?.effectiveAt,
        ),
      );
    }
    final repository = ContractRepository(store);
    for (final c in await repository.getAll()) {
      if (c.kind == ContractKind.creditCard && c.cardAccountId != null) {
        continue;
      }
      final paid = (await repository.payments(
        c.id,
      )).where((p) => p.paid).fold(Amount.zero, (s, p) => s + p.principal);
      final outstanding = c.principal - paid;
      items.add(
        ValuedItem(
          id: c.id,
          name: c.name,
          group: c.kind.name,
          currency: c.currency,
          original: outstanding,
          converted: await convert(outstanding, c.currency, currency),
          liability: c.isDebt,
          source: 'Recorded principal',
        ),
      );
    }
    return WealthSummary(currency, items);
  }

  Future<Amount?> _historicalBasis(Holding h, String currency) async {
    final rows = (await store.list(
      'activity',
    )).where((a) => a['holdingId'] == h.id).toList();
    rows.sort((a, b) {
      final order = dateOf(a['date']).compareTo(dateOf(b['date']));
      return order != 0
          ? order
          : (a['sequence'] as int? ?? 0).compareTo(b['sequence'] as int? ?? 0);
    });
    Amount? basis = Amount.zero;
    var units = Amount.zero;
    for (final e in rows) {
      final kind = e['kind'];
      if (['opening', 'buy', 'adjustment'].contains(kind)) {
        Amount? cost;
        final cacheKey = '${e['id']}:$currency';
        final cached = await store.get('basisSnapshots', cacheKey);
        if (cached != null) {
          cost = amountOf(cached['amount']);
        } else if (e['amount'] != null) {
          if (kind == 'buy' && e['transactionId'] != null) {
            cost = await transactionValue(e['transactionId'] as int, currency);
            if (e['feeId'] != null) {
              final fee = await transactionValue(e['feeId'] as int, currency);
              cost = cost != null && fee != null ? cost + fee : null;
            }
          } else {
            cost = await convert(
              amountOf(e['amount']),
              e['currency'] as String,
              currency,
              at: dateOf(e['date']),
            );
          }
          if (cost != null) {
            await store.put('basisSnapshots', cacheKey, {
              'amount': '$cost',
            }, notify: false);
          }
        }
        if (kind == 'buy') {
          basis = basis != null && cost != null ? basis + cost : null;
          units += amountOf(e['quantity']);
        } else {
          basis = cost;
          units = amountOf(e['quantity']);
        }
      } else if (kind == 'sell') {
        final quantity = amountOf(e['quantity']);
        if (basis != null && units > Amount.zero) {
          basis -= basis * quantity / units;
        }
        units -= quantity;
      } else if (kind == 'split') {
        units *= amountOf(e['ratio']);
      }
    }
    return basis;
  }

  Future<void> snapshot(String currency) async {
    final value = await summary(currency);
    if (!value.complete) return;
    final day = DateTime.now().toIso8601String().substring(0, 10);
    await store.put('snapshots', '$day:$currency', {
      'date': day,
      'currency': currency,
      'assets': '${value.assets}',
      'liabilities': '${value.liabilities}',
      'netWorth': '${value.netWorth}',
      'stale': value.stale,
    }, notify: false);
  }
}
