import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/finance/spending_analytics_service.dart';
import '../../core/services/preferences_service.dart';
import 'finance_providers.dart';
import 'theme_providers.dart';
import 'transaction_providers.dart';

export '../../core/finance/spending_analytics_service.dart';

/// The day each reporting month starts on (1–28), kept in sync with the
/// preference so every screen agrees on what "this month" means.
final monthStartDayProvider = Provider<int>((ref) {
  final sub = PreferencesService.changes.stream
      .where((key) => key == 'month_start_day')
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return PreferencesService.getInt(
    'month_start_day',
    defaultValue: 1,
  ).clamp(1, 28);
});

/// Subcategory → parent category ids.
final categoryParentsProvider = FutureProvider<Map<int, int>>((ref) async {
  ref.watch(financeRevisionProvider);
  return {
    for (final p
        in await ref.watch(financeStoreProvider).list('categoryParents'))
      int.parse(p['child'].toString()): p['parent'] as int,
  };
});

final spendingAnalyticsProvider = Provider(
  (ref) => SpendingAnalyticsService(
    ref.watch(financeStoreProvider),
    ref.watch(valuationProvider),
  ),
);

/// The month the Insights screens are looking at; starts on the current one.
final selectedMonthProvider = StateProvider<DateTime>(
  (ref) => SpendingAnalyticsService.monthOf(
    DateTime.now(),
    ref.watch(monthStartDayProvider),
  ),
);

/// The month containing today, for "this month" summaries.
final currentMonthProvider = Provider<DateTime>(
  (ref) => SpendingAnalyticsService.monthOf(
    DateTime.now(),
    ref.watch(monthStartDayProvider),
  ),
);

final spendingPeriodProvider = FutureProvider.family<SpendingPeriod, DateTime>((
  ref,
  month,
) async {
  ref.watch(financeRevisionProvider);
  final transactions = await ref.watch(transactionsProvider.future);
  return ref
      .watch(spendingAnalyticsProvider)
      .period(
        transactions,
        month,
        ref.watch(defaultCurrencyProvider),
        day: ref.watch(monthStartDayProvider),
      );
});

/// Income and spending for the [count] months ending with the given month.
final spendingSeriesProvider =
    FutureProvider.family<List<PeriodTotals>, (DateTime, int)>((
      ref,
      key,
    ) async {
      ref.watch(financeRevisionProvider);
      final transactions = await ref.watch(transactionsProvider.future);
      return ref
          .watch(spendingAnalyticsProvider)
          .series(
            transactions,
            key.$1,
            ref.watch(defaultCurrencyProvider),
            count: key.$2,
            day: ref.watch(monthStartDayProvider),
          );
    });
