import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final accountDaoProvider = Provider<AppDatabase>((ref) => ref.watch(databaseProvider));
final transactionDaoProvider = Provider<AppDatabase>((ref) => ref.watch(databaseProvider));
final categoryDaoProvider = Provider<AppDatabase>((ref) => ref.watch(databaseProvider));
final budgetDaoProvider = Provider<AppDatabase>((ref) => ref.watch(databaseProvider));
