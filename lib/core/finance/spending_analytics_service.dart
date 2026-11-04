import '../../data/database/database.dart';
import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';
import 'recurring_service.dart';
import 'transaction_classifier.dart';
import 'valuation_service.dart';

/// Spending of one top-level category (subcategories rolled up).
class CategorySpend {
  /// Null when the category was deleted.
  final Category? category;
  final Amount amount;
  final int count;
  const CategorySpend(this.category, this.amount, this.count);
}

/// Spending at one merchant.
class MerchantSpend {
  final String name;
  final Amount amount;
  final int count;
  const MerchantSpend(this.name, this.amount, this.count);
}

/// Income and spending of one reporting period.
class PeriodTotals {
  final DateTime start;
  final Amount income;
  final Amount spending;
  final int missing;
  const PeriodTotals(this.start, this.income, this.spending, this.missing);
  Amount get net => income - spending;
}

/// Everything the spending screens show for one reporting period, in the
/// reporting currency. Built by [SpendingAnalyticsService.period].
class SpendingPeriod {
  final DateTime start;
  final DateTime end;
  final String currency;
  final Amount income;

  /// Spending net of refunds.
  final Amount spending;

  /// Entries left out because no exchange rate was available.
  final int missing;

  /// Spending per calendar day of the period, index 0 is [start].
  final List<Amount> daily;

  /// The previous period's spending per day, for the pace comparison.
  final List<Amount> previousDaily;
  final Amount previousSpending;
  final List<CategorySpend> categories;
  final List<CategorySpend> incomeSources;
  final List<MerchantSpend> merchants;
  final Map<int, Amount> byAccount;
  final Map<String?, Amount> byMethod;
  final Map<int, Amount> byInstrument;
  final Map<String, Amount> byCurrency;

  /// Fees and interest keyed by fee type ('fx', 'late', 'interest', …).
  final Map<String, Amount> fees;

  /// Recurring expenses still due before the period ends.
  final Amount upcoming;

  /// Sum of monthly budget limits, or null when no budget is set.
  final Amount? budget;

  /// Spending in the categories those budgets cover, so the comparison
  /// leaves out categories without a budget.
  final Amount budgetSpent;

  const SpendingPeriod({
    required this.start,
    required this.end,
    required this.currency,
    required this.income,
    required this.spending,
    required this.missing,
    required this.daily,
    required this.previousDaily,
    required this.previousSpending,
    required this.categories,
    required this.incomeSources,
    required this.merchants,
    required this.byAccount,
    required this.byMethod,
    required this.byInstrument,
    required this.byCurrency,
    required this.fees,
    required this.upcoming,
    required this.budget,
    required this.budgetSpent,
  });

  int get days => daily.length;
  Amount get net => income - spending;

  /// Days of the period that have passed, counting today.
  int elapsedDays(DateTime now) {
    if (!now.isAfter(start)) return 0;
    if (!now.isBefore(end)) return days;
    return DateTime(
          now.year,
          now.month,
          now.day,
        ).difference(DateTime(start.year, start.month, start.day)).inDays +
        1;
  }

  Amount averageDaily(DateTime now) {
    final elapsed = elapsedDays(now);
    return elapsed == 0 ? Amount.zero : spending / Amount.fromNum(elapsed);
  }

  /// Expected spending by the period's end. With a previous month, adds
  /// what was spent in the same remaining days then (so a rent paid on the
  /// 1st is not extrapolated across the month); otherwise carries today's
  /// pace forward. Never less than the recurring expenses still due.
  Amount projected(DateTime now) {
    final elapsed = elapsedDays(now);
    final remaining = days - elapsed;
    if (remaining <= 0) return spending;
    final Amount rest;
    if (previousSpending > Amount.zero) {
      rest = previousDaily.skip(elapsed).fold(Amount.zero, (a, b) => a + b);
    } else {
      rest = averageDaily(now) * Amount.fromNum(remaining);
    }
    return spending + (rest > upcoming ? rest : upcoming);
  }

  /// Percent change against the previous period, or null without history.
  double? changeVsPrevious() => previousSpending > Amount.zero
      ? (spending.toDouble() - previousSpending.toDouble()) /
            previousSpending.toDouble() *
            100
      : null;
}

/// The one place cash-flow totals are computed: classifies every entry with
/// [TransactionClassifier] and values it once in the reporting currency.
class SpendingAnalyticsService {
  final FinanceStore store;
  final ValuationService valuation;
  const SpendingAnalyticsService(this.store, this.valuation);

  AppDatabase get db => store.db;

  /// The reporting period starting in [month] for a month start [day].
  static (DateTime, DateTime) bounds(DateTime month, int day) {
    day = day.clamp(1, 28);
    return (
      DateTime(month.year, month.month, day),
      DateTime(month.year, month.month + 1, day),
    );
  }

  /// The month whose period contains [now].
  static DateTime monthOf(DateTime now, int day) {
    final month = DateTime(now.year, now.month);
    return now.day < day.clamp(1, 28)
        ? DateTime(month.year, month.month - 1)
        : month;
  }

  Future<Map<int, int>> _parents() async => {
    for (final p in await store.list('categoryParents'))
      int.parse(p['child'].toString()): p['parent'] as int,
  };

  static int _root(int id, Map<int, int> parents) {
    final seen = <int>{id};
    var current = id;
    for (var p = parents[id]; p != null && seen.add(p); p = parents[p]) {
      current = p;
    }
    return current;
  }

  /// Cash-flow entries between [start] and [end] with their reporting-currency
  /// value (null when no rate exists). Refunds are returned negative.
  Future<List<(Transaction, FlowClass, Amount?, Json?)>> _flows(
    List<Transaction> transactions,
    DateTime start,
    DateTime end,
    String currency,
    Map<int, Category> categories,
  ) async {
    final inRange = transactions
        .where(
          (t) =>
              !t.transactionDate.isBefore(start) &&
              t.transactionDate.isBefore(end),
        )
        .toList();
    final details = await store.transactionDetailsFor(inRange.map((t) => t.id));
    final out = <(Transaction, FlowClass, Amount?, Json?)>[];
    for (final t in inRange) {
      final flow = TransactionClassifier.classify(
        t,
        details[t.id],
        categories[t.categoryId],
      );
      if (!flow.isCashFlow) continue;
      final value = await valuation.transactionValue(t.id, currency);
      out.add((
        t,
        flow,
        value == null || flow != FlowClass.refund ? value : -value,
        details[t.id],
      ));
    }
    return out;
  }

  Future<SpendingPeriod> period(
    List<Transaction> transactions,
    DateTime month,
    String currency, {
    int day = 1,
    DateTime? now,
  }) async {
    now ??= DateTime.now();
    final (start, end) = bounds(month, day);
    final (previous, _) = bounds(DateTime(month.year, month.month - 1), day);
    final categories = {for (final c in await db.getAllCategories()) c.id: c};
    final parents = await _parents();
    final flows = await _flows(
      transactions,
      previous,
      end,
      currency,
      categories,
    );
    final days = end.difference(start).inHours ~/ 24;
    final previousDays = start.difference(previous).inHours ~/ 24;
    final daily = List.filled(days, Amount.zero),
        previousDaily = List.filled(previousDays, Amount.zero);
    var income = Amount.zero, spending = Amount.zero, prior = Amount.zero;
    var missing = 0;
    final byCategory = <int, (Amount, int)>{},
        bySource = <int, (Amount, int)>{},
        byMerchant = <String, (String, Amount, int)>{},
        byAccount = <int, Amount>{},
        byInstrument = <int, Amount>{};
    final byMethod = <String?, Amount>{},
        byCurrency = <String, Amount>{},
        fees = <String, Amount>{};
    void add<K>(Map<K, Amount> to, K key, Amount value) =>
        to[key] = (to[key] ?? Amount.zero) + value;
    final accounts = {for (final a in await db.getAllAccounts()) a.id: a};
    final budgets = (await db.getAllBudgets())
        .where((b) => b.period == 'monthly')
        .toList();
    final budgeted = {for (final b in budgets) b.categoryId};
    bool isBudgeted(int id) {
      final seen = <int>{};
      for (int? c = id; c != null && seen.add(c); c = parents[c]) {
        if (budgeted.contains(c)) return true;
      }
      return false;
    }

    var budgetSpent = Amount.zero;
    for (final (t, flow, value, d) in flows) {
      if (value == null) {
        if (!t.transactionDate.isBefore(start)) missing++;
        continue;
      }
      final date = DateTime(
        t.transactionDate.year,
        t.transactionDate.month,
        t.transactionDate.day,
      );
      if (t.transactionDate.isBefore(start)) {
        if (flow == FlowClass.income) continue;
        prior += value;
        final i = date.difference(previous).inHours ~/ 24;
        if (i >= 0 && i < previousDays) previousDaily[i] += value;
        continue;
      }
      final root = _root(t.categoryId, parents);
      if (flow == FlowClass.income) {
        income += value;
        final (sum, n) = bySource[root] ?? (Amount.zero, 0);
        bySource[root] = (sum + value, n + 1);
        continue;
      }
      spending += value;
      if (isBudgeted(t.categoryId)) budgetSpent += value;
      final i = date.difference(start).inHours ~/ 24;
      if (i >= 0 && i < days) daily[i] += value;
      final (sum, n) = byCategory[root] ?? (Amount.zero, 0);
      byCategory[root] = (sum + value, n + (flow == FlowClass.refund ? 0 : 1));
      final merchant = t.merchant?.trim();
      if (merchant != null && merchant.isNotEmpty) {
        final key = merchant.toLowerCase();
        final (name, total, count) =
            byMerchant[key] ?? (merchant, Amount.zero, 0);
        byMerchant[key] = (name, total + value, count + 1);
      }
      add(byAccount, t.accountId, value);
      add(byMethod, t.paymentMethod, value);
      if (t.paymentInstrumentId case final id?) add(byInstrument, id, value);
      add(
        byCurrency,
        (d?['original'] as Map?)?['currency'] as String? ??
            accounts[t.accountId]?.currency ??
            currency,
        value,
      );
      if (d?['kind'] == 'fee' || d?['kind'] == 'contractInterest') {
        add(
          fees,
          d?['kind'] == 'contractInterest'
              ? 'interest'
              : (d?['feeType'] as String? ?? 'other'),
          value,
        );
      }
    }
    List<CategorySpend> ranked(Map<int, (Amount, int)> groups) => [
      for (final MapEntry(:key, value: (sum, n)) in groups.entries)
        if (sum > Amount.zero) CategorySpend(categories[key], sum, n),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
    return SpendingPeriod(
      start: start,
      end: end,
      currency: currency,
      income: income,
      spending: spending,
      missing: missing,
      daily: daily,
      previousDaily: previousDaily,
      previousSpending: prior,
      categories: ranked(byCategory),
      incomeSources: ranked(bySource),
      merchants: [
        for (final (name, total, count) in byMerchant.values)
          if (total > Amount.zero) MerchantSpend(name, total, count),
      ]..sort((a, b) => b.amount.compareTo(a.amount)),
      byAccount: byAccount,
      byMethod: byMethod,
      byInstrument: byInstrument,
      byCurrency: byCurrency,
      fees: fees,
      upcoming: await _upcoming(now, start, end, currency, accounts),
      budget: await _monthlyBudget(budgets, currency, parents),
      budgetSpent: budgetSpent,
    );
  }

  /// Income and spending for [count] periods ending with [month], oldest
  /// first. One pass over the whole range so each entry is valued once.
  Future<List<PeriodTotals>> series(
    List<Transaction> transactions,
    DateTime month,
    String currency, {
    int count = 6,
    int day = 1,
  }) async {
    final months = [
      for (var i = count - 1; i >= 0; i--)
        DateTime(month.year, month.month - i),
    ];
    final (first, _) = bounds(months.first, day);
    final (_, last) = bounds(months.last, day);
    final categories = {for (final c in await db.getAllCategories()) c.id: c};
    final flows = await _flows(transactions, first, last, currency, categories);
    final income = List.filled(count, Amount.zero),
        spending = List.filled(count, Amount.zero),
        missing = List.filled(count, 0);
    for (final (t, flow, value, _) in flows) {
      final i = months.lastIndexWhere(
        (m) => !t.transactionDate.isBefore(bounds(m, day).$1),
      );
      if (i < 0) continue;
      if (value == null) {
        missing[i]++;
      } else if (flow == FlowClass.income) {
        income[i] += value;
      } else {
        spending[i] += value;
      }
    }
    return [
      for (var i = 0; i < count; i++)
        PeriodTotals(
          bounds(months[i], day).$1,
          income[i],
          spending[i],
          missing[i],
        ),
    ];
  }

  /// Active recurring expenses still to post from [now] until [end].
  Future<Amount> _upcoming(
    DateTime now,
    DateTime start,
    DateTime end,
    String currency,
    Map<int, Account> accounts,
  ) async {
    if (!now.isBefore(end)) return Amount.zero;
    final from = now.isAfter(start) ? now : start;
    var total = Amount.zero;
    for (final r in await db.getActiveRecurringTransactions()) {
      if (r.type != 'expense' || r.toAccountId != null) continue;
      final account = accounts[r.accountId];
      if (account == null) continue;
      final dates = [
        for (final d in _occurrences(r, end))
          if (!d.isBefore(from) && d.isBefore(end)) d,
      ];
      if (dates.isEmpty) continue;
      final value = await valuation.convert(
        Amount.fromNum(r.amount) * Amount.fromNum(dates.length),
        account.currency,
        currency,
      );
      if (value != null) total += value;
    }
    return total;
  }

  static List<DateTime> _occurrences(RecurringTransaction r, DateTime end) {
    final until = r.endDate != null && r.endDate!.isBefore(end)
        ? r.endDate!
        : end;
    if (!RecurringService.frequencies.contains(r.frequency)) return const [];
    return RecurringService.occurrences(r.nextDate, r.frequency, until);
  }

  /// Sum of monthly budget limits in [currency]. Budgets on a subcategory of
  /// another budgeted category are already covered by the parent's limit.
  Future<Amount?> _monthlyBudget(
    List<Budget> budgets,
    String currency,
    Map<int, int> parents,
  ) async {
    if (budgets.isEmpty) return null;
    final budgeted = {for (final b in budgets) b.categoryId};
    final versions = await store.list('budgetVersions');
    var total = Amount.zero;
    for (final b in budgets) {
      var covered = false;
      final seen = <int>{b.categoryId};
      for (
        var p = parents[b.categoryId];
        p != null && seen.add(p);
        p = parents[p]
      ) {
        if (budgeted.contains(p)) covered = true;
      }
      if (covered) continue;
      final latest = versions.where((v) => v['budgetId'] == b.id).toList()
        ..sort((x, y) => y['date'].toString().compareTo(x['date'].toString()));
      final meta = await store.get('budgetCurrencies', '${b.id}');
      final limit = latest.isEmpty
          ? Amount.fromNum(b.amount)
          : Amount(latest.first['amount'].toString());
      final unit = latest.isEmpty
          ? (meta?['currency'] as String?) ?? currency
          : latest.first['currency'] as String;
      final value = await valuation.convert(limit, unit, currency);
      if (value != null) total += value;
    }
    return total;
  }
}
