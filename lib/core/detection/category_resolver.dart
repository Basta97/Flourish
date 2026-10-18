import 'package:drift/drift.dart' show Value;

import '../../data/database/database.dart';
import '../../data/finance/finance_store.dart';
import '../finance/system_categories.dart';
import '../theme/app_colors.dart';
import '../utils/icon_utils.dart';
import 'category_concepts.dart';

/// A category to create because nothing existing fits (from the AI or the
/// local concept table). Created only when the person confirms.
class ProposedCategory {
  const ProposedCategory({
    required this.name,
    required this.type,
    required this.icon,
    required this.colorIndex,
    this.parentName,
  });

  final String name;
  final String type;
  final String icon;
  final int colorIndex;
  final String? parentName;

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'icon': icon,
    'colorIndex': colorIndex,
    if (parentName != null) 'parentName': parentName,
  };

  static ProposedCategory? fromJson(Map<String, dynamic>? j) {
    if (j == null || j['name'] is! String || j['type'] is! String) return null;
    return ProposedCategory(
      name: j['name'] as String,
      type: j['type'] as String,
      icon: j['icon'] as String? ?? 'category',
      colorIndex: j['colorIndex'] as int? ?? 0,
      parentName: j['parentName'] as String?,
    );
  }

  String get label =>
      parentName == null ? name : '$name (under $parentName)';
}

/// What the resolver knows about a payment.
class CategoryQuery {
  const CategoryQuery({
    required this.type,
    this.merchant = '',
    this.text = '',
    this.aiCategoryId,
    this.aiProposed,
  });

  final String type;
  final String merchant;
  final String text;
  final int? aiCategoryId;
  final ProposedCategory? aiProposed;
}

class CategoryResolution {
  const CategoryResolution({this.categoryId, this.proposed});
  final int? categoryId;
  final ProposedCategory? proposed;
  bool get found => categoryId != null || proposed != null;
}

/// The AI and concept stages of category matching, plus near-duplicate
/// detection so "Foods" never sits next to "Food". Merchant rules and the
/// person's history are handled by the caller first.
class CategoryResolver {
  CategoryResolver(Iterable<Category> categories, {this.allowNew = true})
    : categories = SystemCategories.pickable(categories);

  final List<Category> categories;
  final bool allowNew;

  /// The AI's pick: an existing category, or its proposal (merged into a
  /// similar existing one when there is one).
  CategoryResolution fromAi(CategoryQuery q) {
    final ofType = categories.where((c) => c.type == q.type);
    if (q.aiCategoryId != null && ofType.any((c) => c.id == q.aiCategoryId)) {
      return CategoryResolution(categoryId: q.aiCategoryId);
    }
    final p = q.aiProposed;
    if (p == null || p.type != q.type) return const CategoryResolution();
    final similar = findSimilar(p.name, q.type);
    if (similar != null) return CategoryResolution(categoryId: similar.id);
    return allowNew
        ? CategoryResolution(proposed: sanitize(p))
        : const CategoryResolution();
  }

  /// The local concept table ("Spinneys" → groceries): an existing category
  /// that means it, else a proposal.
  CategoryResolution fromConcept(CategoryQuery q) {
    final concept =
        CategoryConcepts.match(q.merchant, type: q.type) ??
        CategoryConcepts.match(q.text, type: q.type);
    if (concept == null) return const CategoryResolution();
    for (final name in concept.names) {
      final hit = findSimilar(name, q.type);
      if (hit != null) return CategoryResolution(categoryId: hit.id);
    }
    if (!allowNew) return const CategoryResolution();
    return CategoryResolution(
      proposed: ProposedCategory(
        name: _title(concept.names.first),
        type: q.type,
        icon: concept.icon,
        colorIndex: CategoryConcepts.all.indexOf(concept) % 12,
      ),
    );
  }

  /// An existing category of [type] meaning the same as [name]: equal after
  /// normalising ("Food & Drinks" = "food and drink") or a near spelling.
  Category? findSimilar(String name, String type) {
    final target = _norm(name);
    if (target.isEmpty) return null;
    final ofType = categories.where((c) => c.type == type).toList();
    for (final c in ofType) {
      if (_norm(c.name) == target) return c;
    }
    for (final c in ofType) {
      final n = _norm(c.name);
      if (n.length >= 4 &&
          target.length >= 4 &&
          similarity(n, target) >= 0.85) {
        return c;
      }
    }
    return null;
  }

  /// [findSimilar], or a category that means the same thing under another
  /// name ("Food" → "Food & Drinks", "Restaurants" → "Food & Drinks").
  /// Used for parents, where a near match is better than a second category.
  Category? findRelated(String name, String type) {
    final direct = findSimilar(name, type);
    if (direct != null) return direct;
    final n = name.toLowerCase().trim();
    for (final concept in CategoryConcepts.all) {
      if (concept.type != type || !concept.names.contains(n)) continue;
      for (final other in concept.names) {
        final hit = findSimilar(other, type);
        if (hit != null) return hit;
      }
    }
    return null;
  }

  /// Keeps proposals inside what the app can render and store.
  static ProposedCategory sanitize(ProposedCategory p) {
    var name = p.name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length > 30) name = name.substring(0, 30).trim();
    final parent = p.parentName?.trim();
    return ProposedCategory(
      name: _title(name),
      type: p.type,
      icon: IconUtils.categoryIcons.containsKey(p.icon) ? p.icon : 'category',
      colorIndex: p.colorIndex.clamp(0, 11),
      parentName: parent == null || parent.isEmpty ? null : parent,
    );
  }

  static String _norm(String name) {
    var n = name
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (n.length > 4 && n.endsWith('s') && !n.endsWith('ss')) {
      n = n.substring(0, n.length - 1);
    }
    return n;
  }

  static String _title(String s) => s
      .split(' ')
      .map(
        (w) => w.isEmpty || w == '&' || w == 'and'
            ? w
            : '${w[0].toUpperCase()}${w.substring(1)}',
      )
      .join(' ');

  /// Levenshtein similarity in [0, 1].
  static double similarity(String a, String b) {
    if (a == b) return 1;
    if (a.isEmpty || b.isEmpty) return 0;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final best = prev[j] + 1 < cur[j - 1] + 1 ? prev[j] + 1 : cur[j - 1] + 1;
        cur[j] = best < prev[j - 1] + cost ? best : prev[j - 1] + cost;
      }
      prev = cur;
    }
    final longest = a.length > b.length ? a.length : b.length;
    return 1 - prev[b.length] / longest;
  }

  /// Creates [proposal] unless a similar category exists (then returns that
  /// one) and links it under its parent. Run inside the booking transaction.
  static Future<int> ensure(
    AppDatabase db,
    FinanceStore store,
    ProposedCategory proposal,
  ) async {
    final all = await db.getAllCategories();
    final resolver = CategoryResolver(all);
    final existing = resolver.findSimilar(proposal.name, proposal.type);
    if (existing != null) return existing.id;
    final clean = sanitize(proposal);
    final id = await db.insertCategory(
      CategoriesCompanion.insert(
        name: clean.name,
        icon: clean.icon,
        color: AppColors.categoryPalette[clean.colorIndex %
            AppColors.categoryPalette.length],
        type: clean.type,
        sortOrder: Value(all.length),
      ),
    );
    final parent = clean.parentName == null
        ? null
        : resolver.findRelated(clean.parentName!, clean.type);
    // A brand-new category has no children, so linking it cannot loop.
    if (parent != null) {
      await store.put('categoryParents', '$id', {
        'child': id,
        'parent': parent.id,
      });
    }
    return id;
  }
}
