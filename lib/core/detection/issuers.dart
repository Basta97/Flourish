/// Egyptian banks and wallets Flourish recognises. Sender patterns match the
/// SMS sender id or the notification title; they are deliberately loose and
/// only ever narrow down a match, never decide one on their own.
class Issuer {
  final String id, name, arabicName;

  /// bank or wallet.
  final String kind;
  final List<RegExp> senders;
  const Issuer(
    this.id,
    this.name,
    this.arabicName,
    this.kind, {
    this.senders = const [],
  });

  bool matchesSender(String? sender) =>
      sender != null && senders.any((p) => p.hasMatch(sender));
}

class Issuers {
  Issuers._();

  static final all = [
    Issuer(
      'cib',
      'CIB',
      'البنك التجاري الدولي',
      'bank',
      senders: [
        RegExp(r'\bCIB\b', caseSensitive: false),
        RegExp('التجاري الدولي'),
      ],
    ),
    Issuer(
      'nbe',
      'National Bank of Egypt',
      'البنك الأهلي المصري',
      'bank',
      senders: [
        RegExp(r'\bNBE\b', caseSensitive: false),
        RegExp(r'Al ?Ahly', caseSensitive: false),
        RegExp('الأهلي|الاهلي'),
      ],
    ),
    Issuer(
      'banque_misr',
      'Banque Misr',
      'بنك مصر',
      'bank',
      senders: [
        RegExp(r'Banque ?Misr|\bBM\b|BanqueMisr', caseSensitive: false),
        RegExp('بنك مصر'),
      ],
    ),
    Issuer(
      'qnb',
      'QNB',
      'بنك قطر الوطني',
      'bank',
      senders: [RegExp(r'\bQNB', caseSensitive: false)],
    ),
    Issuer(
      'hsbc_eg',
      'HSBC Egypt',
      'إتش إس بي سي',
      'bank',
      senders: [RegExp(r'\bHSBC', caseSensitive: false)],
    ),
    Issuer(
      'alexbank',
      'Alexbank',
      'بنك الإسكندرية',
      'bank',
      senders: [
        RegExp(r'ALEX ?BANK', caseSensitive: false),
        RegExp('بنك الإسكندرية|بنك الاسكندرية'),
      ],
    ),
    Issuer(
      'banque_du_caire',
      'Banque du Caire',
      'بنك القاهرة',
      'bank',
      senders: [
        RegExp(r'\bBDC\b|Banque du Caire', caseSensitive: false),
        RegExp('بنك القاهرة'),
      ],
    ),
    Issuer(
      'aaib',
      'AAIB',
      'البنك العربي الأفريقي',
      'bank',
      senders: [RegExp(r'\bAAIB\b', caseSensitive: false)],
    ),
    Issuer(
      'adib',
      'ADIB Egypt',
      'مصرف أبوظبي الإسلامي',
      'bank',
      senders: [RegExp(r'\bADIB\b', caseSensitive: false)],
    ),
    Issuer(
      'instapay',
      'InstaPay',
      'إنستاباي',
      'wallet',
      senders: [
        RegExp(r'insta ?pay|\bIPN\b', caseSensitive: false),
        RegExp('انستا ?باي|إنستاباي'),
      ],
    ),
    Issuer(
      'vodafone_cash',
      'Vodafone Cash',
      'فودافون كاش',
      'wallet',
      senders: [
        RegExp(r'vodafone ?cash|VF-?Cash', caseSensitive: false),
        RegExp('فودافون كاش'),
      ],
    ),
    Issuer(
      'etisalat_cash',
      'e& cash',
      'اتصالات كاش',
      'wallet',
      senders: [
        RegExp(r'(etisalat|e&) ?cash', caseSensitive: false),
        RegExp('اتصالات كاش'),
      ],
    ),
    Issuer(
      'orange_cash',
      'Orange Cash',
      'أورنج كاش',
      'wallet',
      senders: [
        RegExp(r'orange ?(cash|money)', caseSensitive: false),
        RegExp('أورنج كاش|اورنج كاش'),
      ],
    ),
    Issuer(
      'we_pay',
      'WE Pay',
      'وي باي',
      'wallet',
      senders: [RegExp(r'\bWE ?Pay\b', caseSensitive: false)],
    ),
    Issuer(
      'fawry',
      'Fawry',
      'فوري',
      'wallet',
      senders: [RegExp(r'\bfawry', caseSensitive: false), RegExp('فوري')],
    ),
    Issuer(
      'valu',
      'valU',
      'ڤاليو',
      'wallet',
      senders: [
        RegExp(r'\bvalu\b', caseSensitive: false),
        RegExp('فاليو|ڤاليو'),
      ],
    ),
  ];

  static Issuer? byId(String? id) =>
      id == null ? null : all.where((i) => i.id == id).firstOrNull;

  /// The issuer whose sender pattern matches [sender] or, failing that,
  /// whose name appears in [text].
  static Issuer? match({String? sender, String? text}) {
    for (final i in all) {
      if (i.matchesSender(sender)) return i;
    }
    if (text == null) return null;
    for (final i in all) {
      if (i.matchesSender(text)) return i;
    }
    return null;
  }
}
