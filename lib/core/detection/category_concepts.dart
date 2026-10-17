/// Local category knowledge: concept → merchant/keyword triggers and the
/// category names that usually represent it. Used when there is no user rule
/// or merchant memory yet, and to match AI proposals to existing categories.
class CategoryConcept {
  const CategoryConcept({
    required this.key,
    required this.type,
    required this.triggers,
    required this.names,
    required this.icon,
  });

  final String key;
  final String type;

  /// Lower-case whole-word triggers found in the message or merchant.
  final List<String> triggers;

  /// Lower-case category names (and synonyms) that mean this concept.
  final List<String> names;

  /// Icon used if the category has to be created.
  final String icon;
}

class CategoryConcepts {
  CategoryConcepts._();

  static const all = <CategoryConcept>[
    CategoryConcept(
      key: 'groceries',
      type: 'expense',
      triggers: [
        'carrefour',
        'spinneys',
        'hyperone',
        'metro market',
        'seoudi',
        'kazyon',
        'lulu',
        'panda',
        'tamimi',
        'danube',
        'supermarket',
        'hypermarket',
        'grocery',
        'groceries',
        'كارفور',
        'سوبر ماركت',
        'هايبر',
      ],
      names: ['groceries', 'grocery', 'supermarket', 'food & drinks', 'food'],
      icon: 'local_grocery_store',
    ),
    CategoryConcept(
      key: 'food',
      type: 'expense',
      triggers: [
        'restaurant',
        'cafe',
        'coffee',
        'starbucks',
        'costa',
        'cafe nero',
        'mcdonald',
        'kfc',
        'burger',
        'pizza',
        'talabat',
        'elmenus',
        'deliveroo',
        'hungerstation',
        'jahez',
        'careem food',
        'مطعم',
        'كافيه',
        'طلبات',
      ],
      names: ['food & drinks', 'food', 'restaurants', 'dining', 'eating out'],
      icon: 'restaurant',
    ),
    CategoryConcept(
      key: 'transport',
      type: 'expense',
      triggers: [
        'uber',
        'careem',
        'didi',
        'indrive',
        'swvl',
        'taxi',
        'metro ticket',
        'parking',
        'fuel',
        'petrol',
        'gas station',
        'shell',
        'adnoc',
        'enoc',
        'wataniya',
        'chillout',
        'بنزين',
        'أوبر',
        'كريم',
      ],
      names: ['transport', 'transportation', 'car', 'travel', 'fuel'],
      icon: 'directions_car',
    ),
    CategoryConcept(
      key: 'shopping',
      type: 'expense',
      triggers: [
        'amazon',
        'noon',
        'jumia',
        'shein',
        'ikea',
        'zara',
        'h&m',
        'mall',
        'store',
        'apple store',
        'ali express',
        'aliexpress',
        'temu',
        'نون',
        'أمازون',
      ],
      names: ['shopping', 'clothes', 'retail'],
      icon: 'shopping_bag',
    ),
    CategoryConcept(
      key: 'bills',
      type: 'expense',
      triggers: [
        'electricity',
        'water bill',
        'internet',
        'we internet',
        'etisalat',
        'vodafone',
        'orange',
        'stc',
        'du ',
        'dewa',
        'telecom',
        'mobile bill',
        'recharge',
        'كهرباء',
        'فاتورة',
        'شحن رصيد',
      ],
      names: ['bills & utilities', 'bills', 'utilities'],
      icon: 'receipt_long',
    ),
    CategoryConcept(
      key: 'entertainment',
      type: 'expense',
      triggers: [
        'netflix',
        'spotify',
        'anghami',
        'shahid',
        'osn',
        'youtube premium',
        'playstation',
        'steam',
        'xbox',
        'cinema',
        'vox',
        'نتفليكس',
      ],
      names: ['entertainment', 'subscriptions', 'fun'],
      icon: 'movie',
    ),
    CategoryConcept(
      key: 'health',
      type: 'expense',
      triggers: [
        'pharmacy',
        'seif',
        'el ezaby',
        'ezaby',
        'hospital',
        'clinic',
        'doctor',
        'lab ',
        'gym',
        'صيدلية',
        'مستشفى',
      ],
      names: ['health', 'medical', 'healthcare', 'fitness'],
      icon: 'favorite',
    ),
    CategoryConcept(
      key: 'education',
      type: 'expense',
      triggers: [
        'school',
        'university',
        'udemy',
        'coursera',
        'tuition',
        'bookstore',
        'مدرسة',
        'جامعة',
      ],
      names: ['education', 'learning', 'courses'],
      icon: 'school',
    ),
    CategoryConcept(
      key: 'housing',
      type: 'expense',
      triggers: ['rent', 'landlord', 'maintenance fee', 'إيجار'],
      names: ['housing', 'rent', 'home'],
      icon: 'home',
    ),
    CategoryConcept(
      key: 'salary',
      type: 'income',
      triggers: ['salary', 'payroll', 'wages', 'راتب', 'مرتب'],
      names: ['salary', 'payroll', 'wages'],
      icon: 'payments',
    ),
    CategoryConcept(
      key: 'refund',
      type: 'income',
      triggers: ['refund', 'reversal', 'cashback', 'استرداد'],
      names: ['refunds', 'refund', 'cashback'],
      icon: 'currency_exchange',
    ),
  ];

  static CategoryConcept? byKey(String? key) {
    if (key == null) return null;
    for (final c in all) {
      if (c.key == key) return c;
    }
    return null;
  }

  /// First concept whose trigger appears as a whole word in [text].
  static CategoryConcept? match(String text, {String? type}) {
    final lower = ' ${text.toLowerCase()} ';
    for (final concept in all) {
      if (type != null && concept.type != type) continue;
      for (final trigger in concept.triggers) {
        if (_hasWord(lower, trigger)) return concept;
      }
    }
    return null;
  }

  static bool _hasWord(String haystack, String word) {
    final w = word.trim();
    if (w.isEmpty) return false;
    final ascii = RegExp(r'^[a-z0-9 &]+$').hasMatch(w);
    if (!ascii) return haystack.contains(w);
    return RegExp(
      '(?<![a-z0-9])${RegExp.escape(w)}(?![a-z0-9])',
    ).hasMatch(haystack);
  }
}
