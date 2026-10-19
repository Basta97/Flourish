import '../../domain/finance/models.dart';

/// The only data exposed to native widgets. Private snapshots have no totals.
class HomeWidgetSnapshot {
  static Json create({
    required bool hidden,
    required String currency,
    required String locale,
    required DateTime updatedAt,
    required DateTime periodEnd,
    required Map<String, String> labels,
    String? income,
    String? spending,
    bool empty = false,
    int missingRates = 0,
  }) => {
    'version': 1,
    'hidden': hidden,
    'currency': currency,
    'locale': locale,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'periodEnd': periodEnd.millisecondsSinceEpoch,
    'empty': empty,
    'missingRates': missingRates,
    ...labels,
    if (!hidden) ...{'income': income, 'spending': spending},
  };
}
