import 'package:flourish/core/services/transaction_notification_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Realistic bank / wallet alerts (English and Arabic) with the amount, type
/// and, where it matters, merchant that Smart Import should extract.
void main() {
  // (text, amount, type, merchant — null means "don't check")
  final cases = <(String, double?, String, String?)>[
    (
      'Apple Pay: Card 1234 spent 24.90 USD at Starbucks',
      24.90,
      'expense',
      'Starbucks',
    ),
    (
      'Your salary account was credited with 3500 USD from Payroll',
      3500,
      'income',
      'Payroll',
    ),
    (
      'Purchase of EGP 1,250.50 at Carrefour Maadi on card ending 4521',
      1250.50,
      'expense',
      'Carrefour Maadi',
    ),
    (
      'CIB: You paid 89.00 EGP to Uber on card **** 7788',
      89,
      'expense',
      'Uber',
    ),
    (
      'NBE: Debited EGP 5,000.00 from account 1234567890 ATM withdrawal',
      5000,
      'expense',
      null,
    ),
    (
      'Deposit of EGP 12,000 received from Ahmed Ali',
      12000,
      'income',
      'Ahmed Ali',
    ),
    (
      'Refund of 45.99 USD from Amazon has been credited',
      45.99,
      'income',
      'Amazon',
    ),
    ('Transaction alert: 320 EGP at Talabat', 320, 'expense', 'Talabat'),
    (
      'Card 4521 charged AED 1,200.00 at Mall of the Emirates',
      1200,
      'expense',
      'Mall of the Emirates',
    ),
    ('تم خصم مبلغ 250.00 جنيه من بطاقتك لدى كارفور', 250, 'expense', 'كارفور'),
    ('تم إيداع مبلغ 8,000.00 جنيه في حسابك', 8000, 'income', null),
    ('Your OTP is 482913. Do not share it.', null, 'expense', null),
    ('Spent 1.5k EGP at Cafe Nero', 1500, 'expense', 'Cafe Nero'),
    (
      'You received 2,500.75 EGP via InstaPay from Mona',
      2500.75,
      'income',
      null,
    ),
    (
      'Balance: EGP 15,430.20. Purchase 99.99 USD at Netflix',
      99.99,
      'expense',
      'Netflix',
    ),
    // Extra edge cases.
    ('تم خصم ٢٥٠٫٥٠ جنيه من بطاقتك', 250.50, 'expense', null),
    (
      'Purchase 75.00 USD at Shell. Available balance 1,200.00 USD',
      75,
      'expense',
      'Shell',
    ),
    (
      'Verification code 1234 for your payment of EGP 500.00 at Noon',
      500,
      'expense',
      'Noon',
    ),
    (
      'Salary EGP 25,000 credited to account ending 9988',
      25000,
      'income',
      null,
    ),
  ];

  for (final (text, amount, type, merchant) in cases) {
    final label = text.length > 56 ? '${text.substring(0, 56)}…' : text;
    test('detects: $label', () {
      final parsed = TransactionNotificationParser.parse(text);
      expect(parsed.amount, amount, reason: 'amount');
      expect(parsed.type, type, reason: 'type');
      if (merchant != null) {
        expect(parsed.merchant, merchant, reason: 'merchant');
      }
    });
  }

  test('an alert with no usable amount has low confidence', () {
    final parsed = TransactionNotificationParser.parse(
      'Your OTP is 482913. Do not share it.',
    );
    expect(parsed.amount, isNull);
    expect(parsed.confidence, lessThan(0.5));
  });
}
