import '../models/category.dart';

/// Repository abstraction for category operations.
abstract class CategoryRepository {
  Future<List<Category>> getAll();
  Stream<List<Category>> watchAll();
  Future<Category?> getById(int id);
  Future<int> insert(Category category);
  Future<bool> update(Category category);
  Future<int> delete(int id);
  Future<void> deleteAndReassign(int id);
  Future<int> getTransactionCount(int categoryId);
}
