import '../../data/database/database.dart';

/// Suggests a category for a note or merchant name, from the person's own
/// history first and then from common merchants and words (English and
/// Arabic, with Egyptian merchants included).
class CategorySuggester {
  CategorySuggester._();

  /// Keyword → icon of the default category it belongs to. Matching by icon
  /// keeps working after people rename their categories.
  static const _keywords = <String, String>{
    // Food and groceries
    'coffee': 'restaurant', 'starbucks': 'restaurant', 'costa': 'restaurant',
    'lunch': 'restaurant', 'dinner': 'restaurant', 'food': 'restaurant',
    'grocery': 'restaurant', 'restaurant': 'restaurant', 'cafe': 'restaurant',
    'talabat': 'restaurant', 'elmenus': 'restaurant', 'breadfast': 'restaurant',
    'carrefour': 'restaurant',
    'spinneys': 'restaurant',
    'metro market': 'restaurant',
    'kazyon': 'restaurant', 'seoudi': 'restaurant', 'gourmet': 'restaurant',
    'طلبات': 'restaurant', 'مطعم': 'restaurant', 'كارفور': 'restaurant',
    'سوبر ماركت': 'restaurant', 'قهوة': 'restaurant',
    // Transport
    'uber': 'directions_car',
    'careem': 'directions_car',
    'indrive': 'directions_car',
    'didi': 'directions_car',
    'swvl': 'directions_car',
    'taxi': 'directions_car',
    'fuel': 'directions_car',
    'petrol': 'directions_car',
    'gas station': 'directions_car',
    'parking': 'directions_car',
    'أوبر': 'directions_car',
    'بنزين': 'directions_car',
    // Income
    'salary': 'payments', 'paycheck': 'payments', 'payroll': 'payments',
    'wage': 'payments', 'مرتب': 'payments', 'راتب': 'payments',
    // Entertainment and subscriptions
    'netflix': 'movie', 'spotify': 'movie', 'shahid': 'movie', 'osn': 'movie',
    'watch it': 'movie',
    'anghami': 'movie',
    'cinema': 'movie',
    'سينما': 'movie',
    // Health
    'gym': 'favorite', 'doctor': 'favorite', 'pharmacy': 'favorite',
    'hospital': 'favorite', 'clinic': 'favorite', 'ezaby': 'favorite',
    'seif': 'favorite', 'صيدلية': 'favorite', 'دكتور': 'favorite',
    // Housing
    'rent': 'home', 'إيجار': 'home', 'ايجار': 'home',
    // Bills and utilities
    'electricity': 'receipt_long', 'water bill': 'receipt_long',
    'internet': 'receipt_long',
    'fawry': 'receipt_long',
    'vodafone': 'receipt_long',
    'etisalat': 'receipt_long',
    'orange': 'receipt_long',
    'we internet': 'receipt_long',
    'كهرباء': 'receipt_long', 'مياه': 'receipt_long', 'فاتورة': 'receipt_long',
    'فوري': 'receipt_long',
    // Shopping
    'amazon': 'shopping_bag', 'noon': 'shopping_bag', 'jumia': 'shopping_bag',
    'clothes': 'shopping_bag', 'zara': 'shopping_bag', 'ikea': 'shopping_bag',
    // Education
    'book': 'school',
    'course': 'school',
    'tuition': 'school',
    'مدرسة': 'school',
  };

  /// The best category id among [categories] (already filtered to what may
  /// be picked), or null when nothing matches.
  static int? suggest(
    String text,
    List<Transaction> pastTransactions, {
    required List<Category> categories,
    String? type,
  }) {
    final lower = text.trim().toLowerCase();
    if (lower.length < 3) return null;
    final eligible = {
      for (final c in categories)
        if (type == null || c.type == type) c.id: c,
    };
    final scores = <int, int>{};
    for (final t in pastTransactions) {
      if (!eligible.containsKey(t.categoryId)) continue;
      final note = t.note?.trim().toLowerCase();
      if (note != null &&
          note.length >= 3 &&
          (lower.contains(note) || note.contains(lower))) {
        scores[t.categoryId] = (scores[t.categoryId] ?? 0) + 3;
      }
    }
    for (final entry in _keywords.entries) {
      if (!_hasWord(lower, entry.key)) continue;
      for (final c in eligible.values) {
        if (c.icon == entry.value || c.name.toLowerCase().contains(entry.key)) {
          scores[c.id] = (scores[c.id] ?? 0) + 6;
        }
      }
    }
    if (scores.isEmpty) return null;
    return (scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  /// Whole-word match, so "book" does not hit "Facebook" nor "rent"
  /// "current". Arabic has no word boundaries in RegExp, so it matches as a
  /// plain substring after a space or the start.
  static bool _hasWord(String text, String word) {
    if (RegExp(r'^[a-z0-9 ]+$').hasMatch(word)) {
      return RegExp(
        '(?<![a-z0-9])${RegExp.escape(word)}(?![a-z0-9])',
      ).hasMatch(text);
    }
    return RegExp('(?:^|\\s|ال)${RegExp.escape(word)}').hasMatch(text);
  }
}
