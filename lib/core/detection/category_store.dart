import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../data/database/database.dart';
import '../../data/finance/finance_store.dart';
import '../theme/app_colors.dart';
import 'category_resolver.dart';
import 'transaction_candidate.dart';

/// Persistence for the category intelligence: user rules and merchant memory
/// live in `finance_records`, so they are included in backups.
class CategoryLearningStore {
  CategoryLearningStore(this.db, this.store);

  final AppDatabase db;
  final FinanceStore store;

  static const rulesCollection = 'categoryRules';
  static const memoryCollection = 'merchantMemory';

  Future<List<CategoryRule>> rules() async =>
      (await store.list(rulesCollection)).map(CategoryRule.fromJson).toList();

  Future<List<MerchantMemory>> memory() async =>
      (await store.list(memoryCollection)).map(MerchantMemory.fromJson).toList();

  Future<void> addRule({
    required String pattern,
    required int categoryId,
    required String type,
    String matchType = 'merchant',
  }) async {
    final id = const Uuid().v4();
    await store.put(
      rulesCollection,
      id,
      CategoryRule(
        id: id,
        pattern: pattern.trim().toLowerCase(),
        matchType: matchType,
        categoryId: categoryId,
        type: type,
        priority: 10,
      ).toJson(),
    );
  }

  Future<void> removeRule(String id) => store.remove(rulesCollection, id);

  /// Records the user's final choice so the same merchant is categorised the
  /// same way next time.
  Future<void> learn({
    required String merchantKey,
    required String type,
    required int categoryId,
  }) async {
    if (merchantKey.trim().length < 2) return;
    final id = MerchantMemory.idFor(type, merchantKey);
    final prior = await store.get(memoryCollection, id);
    final previous = prior == null ? null : MerchantMemory.fromJson(prior);
    await store.put(
      memoryCollection,
      id,
      MerchantMemory(
        merchantKey: merchantKey,
        type: type,
        categoryId: categoryId,
        // Changing the category resets confidence in the old answer.
        hits: previous?.categoryId == categoryId ? previous!.hits + 1 : 1,
        lastUsed: DateTime.now(),
      ).toJson(),
      notify: false,
    );
  }

  /// Recent (note, type, categoryId) triples for history voting.
  Future<List<(String, String, int)>> history({int limit = 500}) async {
    final rows = await db.getAllTransactions();
    rows.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    return [
      for (final t in rows.take(limit))
        if ((t.note ?? '').trim().isNotEmpty) (t.note!, t.type, t.categoryId),
    ];
  }

  Future<CategoryResolver> resolver({bool allowNewCategories = true}) async =>
      CategoryResolver(
        categories: await db.getAllCategories(),
        rules: await rules(),
        memory: await memory(),
        history: await history(),
        allowNewCategories: allowNewCategories,
      );

  /// Creates [proposal] unless a similar category already exists, links it
  /// under its parent, and returns the id to use. Call inside the same DB
  /// transaction as the transaction insert.
  Future<int> ensureCategory(ProposedCategory proposal) async {
    final categories = await db.getAllCategories();
    final resolver = CategoryResolver(categories: categories);
    final existing = resolver.findSimilar(proposal.name, proposal.type);
    if (existing != null) return existing.id;
    final clean = CategoryResolver.sanitize(proposal);
    final id = await db.insertCategory(
      CategoriesCompanion.insert(
        name: clean.name,
        icon: clean.icon,
        color:
            AppColors.categoryPalette[clean.colorIndex %
                AppColors.categoryPalette.length],
        type: clean.type,
        sortOrder: Value(categories.length),
      ),
    );
    final parent = clean.parentName == null
        ? null
        : resolver.findSimilar(clean.parentName!, clean.type);
    if (parent != null) {
      await CategoryHierarchy.assignParent(
        store,
        [...categories, Category(
          id: id,
          name: clean.name,
          icon: clean.icon,
          color: 0,
          type: clean.type,
          isDefault: false,
          sortOrder: categories.length,
        )],
        child: id,
        parent: parent.id,
      );
    }
    return id;
  }
}

/// Parent/child links between categories (`categoryParents` collection).
class CategoryHierarchy {
  CategoryHierarchy._();

  static Future<void> assignParent(
    FinanceStore store,
    List<Category> categories, {
    required int child,
    required int? parent,
  }) async {
    if (parent == null) {
      await store.remove('categoryParents', '$child');
      return;
    }
    final c = categories.where((x) => x.id == child).firstOrNull;
    final p = categories.where((x) => x.id == parent).firstOrNull;
    if (child == parent || c == null || p == null || c.type != p.type) {
      throw ArgumentError('Choose different categories of the same type');
    }
    final relationships = await store.list('categoryParents');
    var cursor = parent;
    final seen = {child};
    while (true) {
      if (!seen.add(cursor)) {
        throw ArgumentError('Category hierarchy cannot contain a cycle');
      }
      final next =
          relationships.where((r) => r['child'] == cursor).firstOrNull?['parent']
              as int?;
      if (next == null) break;
      cursor = next;
    }
    await store.put('categoryParents', '$child', {
      'child': child,
      'parent': parent,
    });
  }
}
