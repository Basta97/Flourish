import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database.dart';
import 'database_provider.dart';

export 'database_provider.dart';

final accountsProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllAccounts();
});

final totalBalanceProvider = FutureProvider<double>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getNetWorth();
});

final accountByIdProvider = FutureProvider.family<Account?, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.getAccountById(id);
});
