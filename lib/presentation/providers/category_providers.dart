import '../../core/finance/system_categories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database.dart';
import 'database_provider.dart';

export 'database_provider.dart';

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllCategories();
});

/// Categories a person can choose for a manual entry: hidden system
/// categories (transfers, principal, investment legs) are left out so real
/// spending can never be filed somewhere totals ignore.
final pickableCategoriesProvider = Provider<AsyncValue<List<Category>>>(
  (ref) => ref.watch(categoriesProvider).whenData(SystemCategories.pickable),
);

final categoryByIdProvider = FutureProvider.family<Category?, int>((
  ref,
  id,
) async {
  final db = ref.watch(databaseProvider);
  return db.getCategoryById(id);
});
