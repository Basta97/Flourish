import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/date_range.dart';
import '../../data/database/database.dart';
import 'database_provider.dart';

export 'database_provider.dart';

final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllTransactions();
});

final transactionsByAccountProvider =
    StreamProvider.family<List<Transaction>, int>((ref, accountId) {
      final db = ref.watch(databaseProvider);
      return db.watchTransactionsByAccount(accountId);
    });

final transactionsByDateRangeProvider =
    StreamProvider.family<List<Transaction>, DateRange>((ref, range) {
      final db = ref.watch(databaseProvider);
      return db.watchTransactionsByDateRange(range.start, range.end);
    });
