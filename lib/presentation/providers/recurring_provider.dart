import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database.dart';
import 'database_provider.dart';

export 'database_provider.dart';

final recurringTransactionsProvider =
    StreamProvider<List<RecurringTransaction>>((ref) {
      final db = ref.watch(databaseProvider);
      return db.watchAllRecurringTransactions();
    });
