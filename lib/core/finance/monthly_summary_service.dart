import '../../data/database/database.dart';
import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';
import 'transaction_classifier.dart';
import 'valuation_service.dart';

class MonthlySummaryService {
  final FinanceStore store;
  final ValuationService valuation;
  const MonthlySummaryService(this.store, this.valuation);
  static (DateTime, DateTime) period(DateTime now, int day) {
    day = day.clamp(1, 28);
    var start = DateTime(now.year, now.month, day);
    if (start.isAfter(now)) start = DateTime(now.year, now.month - 1, day);
    return (start, DateTime(start.year, start.month + 1, day));
  }

  Future<(Amount, Amount, int)> calculate(
    List<Transaction> transactions,
    String currency, {
    int day = 1,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final (start, end) = period(now, day);
    var income = Amount.zero, expense = Amount.zero, missing = 0;
    final inRange = transactions
        .where(
          (t) =>
              !t.transactionDate.isBefore(start) &&
              t.transactionDate.isBefore(end),
        )
        .toList();
    final details = await store.transactionDetailsFor(inRange.map((t) => t.id));
    final categories = {
      for (final c in await store.db.getAllCategories()) c.id: c,
    };
    for (final t in inRange) {
      final flow = TransactionClassifier.classify(
        t,
        details[t.id],
        categories[t.categoryId],
      );
      if (!flow.isCashFlow) continue;
      final value = await valuation.transactionValue(t.id, currency);
      if (value == null) {
        missing++;
      } else if (flow == FlowClass.income) {
        income += value;
      } else if (flow == FlowClass.refund) {
        expense -= value;
      } else {
        expense += value;
      }
    }
    return (income, expense, missing);
  }
}
