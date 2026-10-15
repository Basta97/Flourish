/// How an entry was paid. Instruments (cards, wallets) carry one of these as
/// their kind; cash has no instrument.
class PaymentMethods {
  PaymentMethods._();

  static const all = [
    'cash',
    'debit_card',
    'credit_card',
    'prepaid_card',
    'mobile_wallet',
    'instapay',
    'bank_transfer',
    'bnpl',
    'other',
  ];

  /// Kinds a saved instrument can have.
  static const instrumentKinds = [
    'debit_card',
    'credit_card',
    'prepaid_card',
    'mobile_wallet',
    'instapay',
    'bank_transfer',
    'bnpl',
    'other',
  ];

  static const networks = [
    'visa',
    'mastercard',
    'meeza',
    'amex',
    'unionpay',
    'other',
  ];

  static String label(String method) => switch (method) {
    'cash' => 'Cash',
    'debit_card' => 'Debit card',
    'credit_card' => 'Credit card',
    'prepaid_card' => 'Prepaid card',
    'mobile_wallet' => 'Mobile wallet',
    'instapay' => 'InstaPay',
    'bank_transfer' => 'Bank transfer',
    'bnpl' => 'Installments (BNPL)',
    _ => 'Other',
  };

  static String networkLabel(String? network) => switch (network) {
    'visa' => 'Visa',
    'mastercard' => 'Mastercard',
    'meeza' => 'Meeza',
    'amex' => 'Amex',
    'unionpay' => 'UnionPay',
    null => '',
    _ => 'Card',
  };

  /// Whether [method] can pay out of an account of [accountType]. A credit
  /// card cannot spend from a bank account's balance, cash cannot come out
  /// of a card, and so on.
  static bool fitsAccount(String method, String accountType) =>
      switch (method) {
        'cash' => accountType == 'cash',
        'credit_card' || 'bnpl' => accountType == 'credit',
        'debit_card' || 'bank_transfer' => accountType == 'bank',
        'prepaid_card' ||
        'mobile_wallet' ||
        'instapay' => accountType == 'bank' || accountType == 'ewallet',
        _ => true,
      };

  /// The usual method for an account type, used when none is given.
  static String defaultFor(String accountType) => switch (accountType) {
    'cash' => 'cash',
    'credit' => 'credit_card',
    'ewallet' => 'mobile_wallet',
    _ => 'debit_card',
  };
}
