import 'finance_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database.dart';
import 'database_provider.dart';

export 'database_provider.dart';

final accountsProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllAccounts();
});

final totalBalanceProvider = Provider<AsyncValue<double>>(
  (ref) => ref.watch(wealthProvider).whenData((w) {
    if (!w.complete) {
      throw StateError('Some prices or exchange rates are unavailable');
    }
    return w.netWorth.toDouble();
  }),
);

final accountByIdProvider = FutureProvider.family<Account?, int>((
  ref,
  id,
) async {
  ref.watch(accountsProvider);
  final db = ref.watch(databaseProvider);
  return db.getAccountById(id);
});
