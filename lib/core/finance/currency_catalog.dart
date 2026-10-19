import 'dart:async';
import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';
import 'currency_data.dart';

class CurrencyInfo {
  final String code, name, symbol;
  const CurrencyInfo(this.code, this.name, [this.symbol = '']);
  factory CurrencyInfo.fromJson(Json j) => CurrencyInfo(
    j['iso_code'] as String,
    j['name'] as String,
    j['symbol'] as String? ?? '',
  );
  Json toJson() => {'iso_code': code, 'name': name, 'symbol': symbol};
}

abstract interface class CurrencyCatalogProvider {
  Future<List<CurrencyInfo>> currencies();
}

class CurrencyCatalog {
  final FinanceStore store;
  final CurrencyCatalogProvider provider;
  CurrencyCatalog(this.store, this.provider);
  static const prominent = ['EGP', 'USD', 'EUR', 'GBP', 'SAR', 'AED', 'KWD'];
  static List<CurrencyInfo> get bundled => [
    for (final e in bundledCurrencyNames.entries) CurrencyInfo(e.key, e.value),
  ];
  List<CurrencyInfo> _current = bundled;
  List<CurrencyInfo> get current => List.unmodifiable(_current);
  Future<List<CurrencyInfo>>? _pending;
  Future<List<CurrencyInfo>> load({bool force = false}) =>
      _pending ??= _load(force).whenComplete(() => _pending = null);
  Future<List<CurrencyInfo>> _load(bool force) async {
    final saved = await store.get('currencyCatalog', 'active');
    if (saved?['currencies'] is List) {
      _current = (saved!['currencies'] as List)
          .map((j) => CurrencyInfo.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    }
    final fetched = DateTime.tryParse('${saved?['fetchedAt']}');
    if (!force &&
        fetched != null &&
        DateTime.now().difference(fetched) < const Duration(days: 7)) {
      return current;
    }
    try {
      final rows = await provider.currencies();
      if (rows.isEmpty ||
          rows.any((c) => !RegExp(r'^[A-Z]{3}$').hasMatch(c.code))) {
        throw const FormatException('Invalid currency catalog');
      }
      _current = rows;
      await store.put('currencyCatalog', 'active', {
        'fetchedAt': DateTime.now().toUtc().toIso8601String(),
        'currencies': rows.map((r) => r.toJson()).toList(),
      }, notify: false);
    } catch (_) {
      /* Offline: bundled or last successful catalog remains available. */
    }
    return current;
  }
}
