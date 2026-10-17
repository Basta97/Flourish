/// Known senders. A match tells the parser which currency to assume when the
/// message omits one, and labels the candidate so the account resolver can
/// prefer an account at that bank.
class BankProfile {
  const BankProfile(this.id, this.name, this.markers, {this.defaultCurrency});

  final String id;
  final String name;

  /// Lower-case substrings that identify the sender.
  final List<String> markers;
  final String? defaultCurrency;
}

class BankProfiles {
  BankProfiles._();

  static const all = <BankProfile>[
    BankProfile('cib', 'CIB', [
      'cib',
      'commercial international bank',
    ], defaultCurrency: 'EGP'),
    BankProfile('nbe', 'National Bank of Egypt', [
      'nbe',
      'national bank of egypt',
      'البنك الأهلي',
      'الأهلي المصري',
    ], defaultCurrency: 'EGP'),
    BankProfile('banque_misr', 'Banque Misr', [
      'banque misr',
      'bm online',
      'بنك مصر',
    ], defaultCurrency: 'EGP'),
    BankProfile('qnb', 'QNB', ['qnb'], defaultCurrency: null),
    BankProfile('instapay', 'InstaPay', [
      'instapay',
      'انستاباي',
      'إنستاباي',
    ], defaultCurrency: 'EGP'),
    BankProfile('vodafone_cash', 'Vodafone Cash', [
      'vodafone cash',
      'فودافون كاش',
    ], defaultCurrency: 'EGP'),
    BankProfile('emirates_nbd', 'Emirates NBD', [
      'emirates nbd',
      'enbd',
    ], defaultCurrency: 'AED'),
    BankProfile('adcb', 'ADCB', ['adcb'], defaultCurrency: 'AED'),
    BankProfile('fab', 'First Abu Dhabi Bank', [
      'first abu dhabi',
      'fab card',
    ], defaultCurrency: 'AED'),
    BankProfile('al_rajhi', 'Al Rajhi Bank', [
      'al rajhi',
      'alrajhi',
      'الراجحي',
    ], defaultCurrency: 'SAR'),
    BankProfile('snb', 'Saudi National Bank', [
      'alahli',
      'snb',
      'الأهلي السعودي',
    ], defaultCurrency: 'SAR'),
    BankProfile('apple_pay', 'Apple Pay', ['apple pay']),
  ];

  static BankProfile? detect(String lowerText) {
    for (final profile in all) {
      for (final marker in profile.markers) {
        if (_containsWord(lowerText, marker)) return profile;
      }
    }
    return null;
  }

  /// Short ASCII markers like "cib" must not match inside other words.
  static bool _containsWord(String text, String marker) {
    if (!RegExp(r'^[a-z ]+$').hasMatch(marker) || marker.length > 5) {
      return text.contains(marker);
    }
    return RegExp(
      '(?<![a-z])${RegExp.escape(marker)}(?![a-z])',
    ).hasMatch(text);
  }
}
