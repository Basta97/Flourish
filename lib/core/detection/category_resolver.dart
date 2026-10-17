import '../../data/database/database.dart' show Category;
import '../utils/icon_utils.dart';
import 'category_concepts.dart';
import 'transaction_candidate.dart';

/// "Always put Talabat in Food" — created by the user from the review screen.
class CategoryRule {
  const CategoryRule({
    required this.id,
    required this.pattern,
    required this.matchType,
    required this.categoryId,
    required this.type,
    this.priority = 0,
  });

  final String id;
  final String pattern;

  /// 'merchant' (exact merchant key), 'contains' (text contains) or 'regex'.
  final String matchType;
  final int categoryId;
  final String type;
  final int priority;

  bool matches(TransactionCandidate c) {
    final p = pattern.toLowerCase();
    switch (matchType) {
      case 'merchant':
        return c.merchantKey.isNotEmpty && c.merchantKey == p;
      case 'regex':
        try {
          return RegExp(pattern, caseSensitive: false).hasMatch(c.rawText);
        } on FormatException {
          return false;
        }
      default:
        return p.isNotEmpty &&
            ('${c.merchant} ${c.rawText}').toLowerCase().contains(p);
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pattern': pattern,
    'matchType': matchType,
    'categoryId': categoryId,
    'type': type,
    'priority': priority,
  };

  factory CategoryRule.fromJson(Map<String, dynamic> j) => CategoryRule(
    id: j['id'] as String,
    pattern: j['pattern'] as String,
    matchType: j['matchType'] as String? ?? 'contains',
    categoryId: j['categoryId'] as int,
    type: j['type'] as String,
    priority: j['priority'] as int? ?? 0,
  );
}

/// What the user chose last time for a merchant.
class MerchantMemory {
  const MerchantMemory({
    required this.merchantKey,
    required this.type,
    required this.categoryId,
    required this.hits,
    required this.lastUsed,
  });

  final String merchantKey;
  final String type;
  final int categoryId;
  final int hits;
  final DateTime lastUsed;

  String get id => idFor(type, merchantKey);
  static String idFor(String type, String key) => '$type|$key';

  Map<String, dynamic> toJson() => {
    'merchantKey': merchantKey,
    'type': type,
    'categoryId': categoryId,
    'hits': hits,
    'lastUsed': lastUsed.toIso8601String(),
  };

  factory MerchantMemory.fromJson(Map<String, dynamic> j) => MerchantMemory(
    merchantKey: j['merchantKey'] as String,
    type: j['type'] as String,
    categoryId: j['categoryId'] as int,
    hits: j['hits'] as int? ?? 1,
    lastUsed: DateTime.tryParse(j['lastUsed'] as String? ?? '') ?? DateTime(2000),
  );
}

enum CategoryReason { rule, memory, history, ai, aiNew, concept, conceptNew, fallback }

class CategoryResolution {
  const CategoryResolution({
    required this.reason,
    required this.confidence,
    this.categoryId,
    this.proposed,
  });

  /// An existing category, or null when [proposed] must be created first.
  final int? categoryId;
  final ProposedCategory? proposed;
  final CategoryReason reason;
  final double confidence;

  bool get isNew => categoryId == null && proposed != null;
}

/// Picks a category for a candidate: user rules → merchant memory → past
/// notes → AI pick → AI proposal → keyword concept → "Other".
class CategoryResolver {
  CategoryResolver({
    required List<Category> categories,
    this.rules = const [],
    this.memory = const [],
    this.history = const [],
    this.allowNewCategories = true,
  }) : categories = List.unmodifiable(categories);

  final List<Category> categories;
  final List<CategoryRule> rules;
  final List<MerchantMemory> memory;

  /// (note, type, categoryId) of existing transactions, newest first.
  final List<(String, String, int)> history;
  final bool allowNewCategories;

  CategoryResolution resolve(TransactionCandidate c, {String? type}) {
    final t = type ?? c.type;
    final ofType = categories.where((x) => x.type == t).toList();
    bool valid(int? id) => id != null && ofType.any((x) => x.id == id);

    final sortedRules = [...rules]
      ..sort((a, b) => b.priority.compareTo(a.priority));
    for (final rule in sortedRules) {
      if (rule.type == t && valid(rule.categoryId) && rule.matches(c)) {
        return CategoryResolution(
          categoryId: rule.categoryId,
          reason: CategoryReason.rule,
          confidence: 0.98,
        );
      }
    }

    if (c.merchantKey.isNotEmpty) {
      final remembered = memory
          .where(
            (m) =>
                m.type == t &&
                m.merchantKey == c.merchantKey &&
                valid(m.categoryId),
          )
          .toList()
        ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
      if (remembered.isNotEmpty) {
        final m = remembered.first;
        return CategoryResolution(
          categoryId: m.categoryId,
          reason: CategoryReason.memory,
          confidence: (0.7 + 0.05 * m.hits.clamp(0, 5)).clamp(0.0, 0.95),
        );
      }
      final fromHistory = _fromHistory(c.merchantKey, t, valid);
      if (fromHistory != null) {
        return CategoryResolution(
          categoryId: fromHistory,
          reason: CategoryReason.history,
          confidence: 0.6,
        );
      }
    }

    if (valid(c.aiCategoryId)) {
      return CategoryResolution(
        categoryId: c.aiCategoryId,
        reason: CategoryReason.ai,
        confidence: 0.75,
      );
    }

    final proposal = c.aiProposedCategory;
    if (proposal != null && proposal.type == t) {
      final existing = findSimilar(proposal.name, t);
      if (existing != null) {
        return CategoryResolution(
          categoryId: existing.id,
          reason: CategoryReason.ai,
          confidence: 0.7,
        );
      }
      if (allowNewCategories) {
        return CategoryResolution(
          proposed: sanitize(proposal),
          reason: CategoryReason.aiNew,
          confidence: 0.65,
        );
      }
    }

    final concept = CategoryConcepts.byKey(c.categoryHint);
    if (concept != null && concept.type == t) {
      for (final name in concept.names) {
        final hit = findSimilar(name, t);
        if (hit != null) {
          return CategoryResolution(
            categoryId: hit.id,
            reason: CategoryReason.concept,
            confidence: 0.6,
          );
        }
      }
      if (allowNewCategories) {
        return CategoryResolution(
          proposed: ProposedCategory(
            name: _title(concept.names.first),
            type: t,
            icon: concept.icon,
            colorIndex: CategoryConcepts.all.indexOf(concept) % 12,
          ),
          reason: CategoryReason.conceptNew,
          confidence: 0.5,
        );
      }
    }

    final other =
        ofType.where((x) => _norm(x.name) == 'other').firstOrNull ??
        ofType.firstOrNull;
    return CategoryResolution(
      categoryId: other?.id,
      reason: CategoryReason.fallback,
      confidence: 0.2,
    );
  }

  /// Resolves a whole batch, creating at most [maxNew] distinct new
  /// categories; later proposals reuse an earlier proposal with the same name
  /// or fall back to their parent / "Other".
  List<CategoryResolution> resolveAll(
    List<TransactionCandidate> candidates, {
    int maxNew = 5,
  }) {
    final accepted = <String, ProposedCategory>{};
    return [
      for (final c in candidates)
        () {
          final r = resolve(c);
          final proposed = r.proposed;
          if (proposed == null) return r;
          final key = '${proposed.type}|${_norm(proposed.name)}';
          final same = accepted[key];
          if (same != null) {
            return CategoryResolution(
              proposed: same,
              reason: r.reason,
              confidence: r.confidence,
            );
          }
          if (accepted.length < maxNew) {
            accepted[key] = proposed;
            return r;
          }
          final parent = proposed.parentName == null
              ? null
              : findSimilar(proposed.parentName!, proposed.type);
          final fallback = parent != null
              ? CategoryResolution(
                  categoryId: parent.id,
                  reason: r.reason,
                  confidence: r.confidence * 0.8,
                )
              : CategoryResolver(
                  categories: categories,
                  allowNewCategories: false,
                ).resolve(c);
          return fallback;
        }(),
    ];
  }

  int? _fromHistory(String key, String type, bool Function(int?) valid) {
    if (key.length < 3) return null;
    final votes = <int, int>{};
    for (final (note, t, categoryId) in history) {
      if (t != type || !valid(categoryId)) continue;
      if (note.toLowerCase().contains(key)) {
        votes[categoryId] = (votes[categoryId] ?? 0) + 1;
      }
    }
    if (votes.isEmpty) return null;
    return (votes.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  /// An existing category of [type] that means the same as [name]: equal
  /// after normalising, a shared concept, or a near spelling ("Foods").
  Category? findSimilar(String name, String type) {
    final target = _norm(name);
    if (target.isEmpty) return null;
    final ofType = categories.where((c) => c.type == type).toList();
    for (final c in ofType) {
      if (_norm(c.name) == target) return c;
    }
    for (final c in ofType) {
      final n = _norm(c.name);
      if (n.length >= 4 && target.length >= 4 && similarity(n, target) >= 0.85) {
        return c;
      }
    }
    return null;
  }

  /// Keeps AI proposals inside what the UI can render.
  static ProposedCategory sanitize(ProposedCategory p) {
    var name = p.name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length > 30) name = name.substring(0, 30).trim();
    return ProposedCategory(
      name: _title(name),
      type: p.type,
      icon: IconUtils.categoryIcons.containsKey(p.icon) ? p.icon : 'category',
      colorIndex: p.colorIndex.clamp(0, 11),
      parentName: p.parentName?.trim().isEmpty ?? true ? null : p.parentName,
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
        cur[j] = [
          prev[j] + 1,
          cur[j - 1] + 1,
          prev[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    final longest = a.length > b.length ? a.length : b.length;
    return 1 - prev[b.length] / longest;
  }
}
