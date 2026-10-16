import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database.dart';
import 'database_provider.dart';
import 'finance_providers.dart';

export 'database_provider.dart';

final recurringTransactionsProvider =
    StreamProvider<List<RecurringTransaction>>((ref) {
      final db = ref.watch(databaseProvider);
      return db.watchAllRecurringTransactions();
    });

/// Rule id → why it could not post on the last run.
final recurringWarningsProvider = StreamProvider<Map<int, String>>((
  ref,
) async* {
  final service = ref.watch(recurringServiceProvider);
  yield await service.warnings();
  await for (final _ in ref.watch(databaseProvider).financeChanges.stream) {
    yield await service.warnings();
  }
});
