import 'package:drift/drift.dart' hide Column;
import '../../data/database/database.dart' as drift;
import '../../domain/models/category.dart';
import '../../domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this._db);

  final drift.AppDatabase _db;

  Category _map(drift.Category c) => Category(
    id: c.id,
    name: c.name,
    icon: c.icon,
    color: c.color,
    type: c.type,
    isDefault: c.isDefault,
    sortOrder: c.sortOrder,
  );

  drift.CategoriesCompanion _toCompanion(Category c) =>
      drift.CategoriesCompanion(
        id: c.id == 0 ? const Value.absent() : Value(c.id),
        name: Value(c.name),
        icon: Value(c.icon),
        color: Value(c.color),
        type: Value(c.type),
        isDefault: Value(c.isDefault),
        sortOrder: Value(c.sortOrder),
      );

  @override
  Future<List<Category>> getAll() async {
    final rows = await _db.getAllCategories();
    return rows.map(_map).toList();
  }

  @override
  Stream<List<Category>> watchAll() {
    return _db.watchAllCategories().map((rows) => rows.map(_map).toList());
  }

  @override
  Future<Category?> getById(int id) async {
    final row = await _db.getCategoryById(id);
    return row == null ? null : _map(row);
  }

  @override
  Future<int> insert(Category category) =>
      _db.insertCategory(_toCompanion(category));

  @override
  Future<bool> update(Category category) => _db.updateCategory(
    drift.Category(
      id: category.id,
      name: category.name,
      icon: category.icon,
      color: category.color,
      type: category.type,
      isDefault: category.isDefault,
      sortOrder: category.sortOrder,
    ),
  );

  @override
  Future<int> delete(int id) => _db.deleteCategory(id);

  @override
  Future<void> deleteAndReassign(int id) =>
      _db.deleteCategoryAndReassignTransactions(id);

  @override
  Future<int> getTransactionCount(int categoryId) =>
      _db.getCategoryTransactionCount(categoryId);
}
