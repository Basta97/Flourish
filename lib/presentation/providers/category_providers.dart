import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database.dart';
import 'database_provider.dart';

export 'database_provider.dart';

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllCategories();
});

final categoryByIdProvider = FutureProvider.family<Category?, int>((
  ref,
  id,
) async {
  final db = ref.watch(databaseProvider);
  return db.getCategoryById(id);
});
