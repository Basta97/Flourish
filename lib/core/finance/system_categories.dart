import 'package:drift/drift.dart';
import '../../data/database/database.dart';

/// A category the ledger books automatically (transfers, fees, principal…).
class SystemCategory {
  final String key, name, type, icon;
  final int color;

  /// Hidden categories never appear in pickers: picking one would make real
  /// spending disappear from totals (e.g. filing groceries as a transfer).
  final bool hidden;

  /// Earlier names of this category, merged into it by maintenance.
  final List<String> legacyNames;
  const SystemCategory(
    this.key,
    this.name,
    this.type, {
    required this.icon,
    required this.color,
    this.hidden = false,
    this.legacyNames = const [],
  });
}

class SystemCategories {
  SystemCategories._();

  static const all = [
    SystemCategory(
      'transfer_out',
      'Transfer Out',
      'expense',
      icon: 'north_east',
      color: 0xFF8B5CF6,
      hidden: true,
      legacyNames: ['Transfer transfer'],
    ),
    SystemCategory(
      'transfer_in',
      'Transfer In',
      'income',
      icon: 'south_west',
      color: 0xFF0EA5E9,
      hidden: true,
      legacyNames: ['Transfer transfer'],
    ),
    SystemCategory(
      'investment_buy',
      'Investment purchases',
      'expense',
      icon: 'trending_up',
      color: 0xFF4F46E5,
      hidden: true,
      legacyNames: ['Transfer asset'],
    ),
    SystemCategory(
      'investment_sell',
      'Investment sales',
      'income',
      icon: 'trending_up',
      color: 0xFF4F46E5,
      hidden: true,
      legacyNames: ['Transfer asset'],
    ),
    SystemCategory(
      'principal_out',
      'Principal paid',
      'expense',
      icon: 'account_balance',
      color: 0xFF4F46E5,
      hidden: true,
      legacyNames: ['Transfer principal'],
    ),
    SystemCategory(
      'principal_in',
      'Principal received',
      'income',
      icon: 'account_balance',
      color: 0xFF4F46E5,
      hidden: true,
      legacyNames: ['Transfer principal'],
    ),
    SystemCategory(
      'bank_fees',
      'Bank fees',
      'expense',
      icon: 'receipt_long',
      color: 0xFFDC2626,
    ),
    SystemCategory(
      'investment_fees',
      'Investment fees',
      'expense',
      icon: 'receipt_long',
      color: 0xFF9333EA,
    ),
    SystemCategory(
      'interest_paid',
      'Interest & charges',
      'expense',
      icon: 'percent',
      color: 0xFFB91C1C,
    ),
    SystemCategory(
      'interest_earned',
      'Interest earned',
      'income',
      icon: 'percent',
      color: 0xFF059669,
    ),
    SystemCategory(
      'other_expense',
      'Other',
      'expense',
      icon: 'more_horiz',
      color: 0xFF6B7280,
    ),
    SystemCategory(
      'other_income',
      'Other income',
      'income',
      icon: 'more_horiz',
      color: 0xFF6B7280,
    ),
  ];

  static SystemCategory byKey(String key) =>
      all.firstWhere((c) => c.key == key);

  /// The system category behind [category], if any: by its stored key, or
  /// by a legacy name that maintenance has not merged yet.
  static SystemCategory? of(Category? category) {
    if (category == null) return null;
    final key = category.systemKey;
    if (key != null) return all.where((c) => c.key == key).firstOrNull;
    for (final c in all) {
      if (c.type == category.type && c.legacyNames.contains(category.name)) {
        return c;
      }
    }
    return null;
  }

  /// Tags existing categories that carry a system name with their key, so
  /// they keep working after being renamed.
  static Future<void> backfillKeys(AppDatabase db) async {
    for (final c in all) {
      final tagged = await db
          .customSelect(
            'SELECT id FROM categories WHERE system_key = ?',
            variables: [Variable(c.key)],
          )
          .get();
      if (tagged.isNotEmpty) continue;
      await db.customStatement(
        'UPDATE categories SET system_key = ? WHERE id = '
        '(SELECT MIN(id) FROM categories WHERE type = ? AND name = ? '
        'AND system_key IS NULL)',
        [c.key, c.type, c.name],
      );
    }
  }

  static bool isHidden(Category? category) => of(category)?.hidden ?? false;
  static bool isSystem(Category? category) => of(category) != null;

  /// Categories a person may pick for a manual entry.
  static List<Category> pickable(Iterable<Category> categories) =>
      categories.where((c) => !isHidden(c)).toList();

  /// The category the ledger uses for a booking of [kind]/[type].
  static String keyFor(String kind, String type, {String? feeType}) =>
      switch ((kind, type)) {
        ('transfer', 'income') => 'transfer_in',
        ('transfer', _) => 'transfer_out',
        ('asset', 'income') => 'investment_sell',
        ('asset', _) => 'investment_buy',
        ('principal', 'income') => 'principal_in',
        ('principal', _) => 'principal_out',
        ('contractInterest', 'income') => 'interest_earned',
        ('contractInterest', _) => 'interest_paid',
        ('fee', _) when feeType == 'investment' => 'investment_fees',
        ('fee', _) => 'bank_fees',
        (_, 'income') => 'other_income',
        _ => 'other_expense',
      };

  /// The id of system category [key], created when missing.
  static Future<int> idFor(AppDatabase db, String key) async {
    final c = byKey(key);
    final tagged =
        await (db.select(db.categories)
              ..where((t) => t.systemKey.equals(key))
              ..limit(1))
            .getSingleOrNull();
    if (tagged != null) return tagged.id;
    final named =
        await (db.select(db.categories)
              ..where(
                (t) =>
                    t.type.equals(c.type) &
                    t.name.equals(c.name) &
                    t.systemKey.isNull(),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.id)])
              ..limit(1))
            .getSingleOrNull();
    if (named != null) {
      await (db.update(db.categories)..where((t) => t.id.equals(named.id)))
          .write(CategoriesCompanion(systemKey: Value(key)));
      return named.id;
    }
    return db.insertCategory(
      CategoriesCompanion.insert(
        name: c.name,
        icon: c.icon,
        color: c.color,
        type: c.type,
        isDefault: const Value(true),
        sortOrder: const Value(900),
        systemKey: Value(key),
      ),
    );
  }
}
