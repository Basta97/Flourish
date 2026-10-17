import 'package:flourish/core/detection/parsed_payment.dart';
import 'package:flourish/core/detection/payment_parser.dart';
import 'package:flourish/core/services/category_suggester.dart';
import 'package:flourish/data/database/database.dart' show Category;
import 'package:flourish/domain/finance/models.dart';
import 'package:flutter_test/flutter_test.dart';

final received = DateTime(2026, 10, 17, 12);

ParsedPayment parse(String text, {String? sender}) => PaymentMessageParser.parse(
  RawMessage(text: text, receivedAt: received, source: 'paste', sender: sender),
);

/// Messages that broke earlier parsers. Each one is a named regression.
void main() {
  group('amounts', () {
    test('currency between card number and amount binds to the amount', () {
      final p = parse('Card 4521 EGP 250.00 purchase at Spinneys');
      expect(p.amount, Amount('250'));
      expect(p.currency, 'EGP');
      expect(p.last4, '4521');
    });

    test('space-grouped thousands', () {
      expect(parse('Deposit of 12 000 EGP received').amount, Amount('12000'));
    });

    test('k suffix, exact', () {
      expect(parse('Spent 1.5k EGP at Cafe Nero').amount, Amount('1500'));
      expect(parse('Spent 1.15k EGP at Zara').amount, Amount('1150'));
    });

    test('European grouping and three-decimal currencies', () {
      expect(parse('Paid EUR 1.250,50 at IKEA').amount, Amount('1250.50'));
      expect(parse('KWD 1.255 debited at Sultan Center').amount, Amount('1.255'));
    });

    test('a balance word far before a spend does not hide it', () {
      final p = parse('Your balance is low. Spent 20 EGP at Kiosk');
      expect(p.amount, Amount('20'));
      expect(p.merchant, 'Kiosk');
    });

    test('a spend verb counts as an amount word without a currency', () {
      final p = parse('CIB: you paid 89.00 to Uber');
      expect(p.amount, Amount('89'));
    });

    test('balances and references are not amounts', () {
      expect(
        parse('Balance: EGP 15,430.20. Purchase 99.99 USD at Netflix').amount,
        Amount('99.99'),
      );
      expect(parse('Paid EGP 45.00 at Uber Ref 88213345').amount, Amount('45'));
    });
  });

  group('kinds', () {
    test('salary credits are deposits, not transfers from a person', () {
      expect(
        parse('Your salary account was credited with 3500 USD from Payroll').kind,
        'deposit',
      );
    });

    test('"deducted" is a purchase; Arabic أضيف is a deposit', () {
      expect(parse('EGP 99.00 deducted from your card at Carrefour').kind, 'purchase');
      expect(parse('أضيف مبلغ 1,000 جنيه لحسابك').kind, 'deposit');
    });

    final ignored = <(String, String)>[
      ('Your credit card payment of EGP 3,200.00 is due on 25/10/2026', 'notice'),
      ('Get 20% off when you spend EGP 500 at Noon! Use code SAVE20', 'promo'),
      ('Your available balance is EGP 15,430.20', 'no_amount'),
      ('Verification code 1234 for your payment of EGP 500.00 at Noon', 'otp'),
      ('عملية شراء بمبلغ 200 جنيه مرفوضة', 'declined'),
    ];
    for (final (text, reason) in ignored) {
      test('ignored as $reason: ${text.substring(0, 24)}…', () {
        expect(parse(text).ignoreReason, reason);
      });
    }

    test('a settled due reminder is still a payment', () {
      expect(
        parse('Thank you for your payment of EGP 3,200.00 to your credit card').ignored,
        isFalse,
      );
    });
  });

  group('merchants', () {
    test('Arabic dates are not merchants', () {
      expect(parse('تم خصم 100 جنيه بتاريخ 9 أكتوبر 2026').merchant, isNull);
    });

    test('abbreviations keep their dot', () {
      expect(parse('Spent 300 AED at St. Regis Hotel').merchant, 'St. Regis Hotel');
      expect(parse('Purchase 75.00 USD at Shell. Available balance 1,200.00 USD').merchant, 'Shell');
    });
  });

  group('category suggester', () {
    Category cat(int id, String name, String icon) => Category(
      id: id,
      name: name,
      icon: icon,
      color: 0,
      type: 'expense',
      isDefault: true,
      sortOrder: id,
    );
    final categories = [
      cat(1, 'Education', 'school'),
      cat(2, 'Housing', 'home'),
      cat(3, 'Shopping', 'shopping_bag'),
    ];

    test('keywords match whole words only', () {
      expect(
        CategorySuggester.suggest('Facebook Ads', const [], categories: categories),
        isNull,
        reason: '"book" inside "Facebook" is not Education',
      );
      expect(
        CategorySuggester.suggest('Current Mall', const [], categories: categories),
        isNull,
        reason: '"rent" inside "Current" is not Housing',
      );
      expect(
        CategorySuggester.suggest('Monthly rent', const [], categories: categories),
        2,
      );
    });
  });
}
