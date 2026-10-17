import 'package:flourish/core/detection/local_parser.dart';
import 'package:flourish/core/detection/message_splitter.dart';
import 'package:flourish/core/detection/text_normalizer.dart';
import 'package:flourish/core/detection/transaction_candidate.dart';
import 'package:flourish/domain/finance/amount.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionCandidate parse(String text) =>
    LocalTransactionParser.parse(text, now: DateTime(2026, 10, 17, 12));

void main() {
  group('real alerts', () {
    // (text, amount, type, merchant — null means "don't check")
    final cases = <(String, String?, String, String?)>[
      (
        'Apple Pay: Card 1234 spent 24.90 USD at Starbucks',
        '24.9',
        'expense',
        'Starbucks',
      ),
      (
        'Your salary account was credited with 3500 USD from Payroll',
        '3500',
        'income',
        'Payroll',
      ),
      (
        'Purchase of EGP 1,250.50 at Carrefour Maadi on card ending 4521',
        '1250.5',
        'expense',
        'Carrefour Maadi',
      ),
      (
        'CIB: You paid 89.00 EGP to Uber on card **** 7788',
        '89',
        'expense',
        'Uber',
      ),
      (
        'NBE: Debited EGP 5,000.00 from account 1234567890 ATM withdrawal',
        '5000',
        'expense',
        '',
      ),
      (
        'Deposit of EGP 12,000 received from Ahmed Ali',
        '12000',
        'income',
        'Ahmed Ali',
      ),
      (
        'Refund of 45.99 USD from Amazon has been credited',
        '45.99',
        'income',
        'Amazon',
      ),
      ('Transaction alert: 320 EGP at Talabat', '320', 'expense', 'Talabat'),
      (
        'Card 4521 charged AED 1,200.00 at Mall of the Emirates',
        '1200',
        'expense',
        'Mall of the Emirates',
      ),
      (
        'تم خصم مبلغ 250.00 جنيه من بطاقتك لدى كارفور',
        '250',
        'expense',
        'كارفور',
      ),
      ('تم إيداع مبلغ 8,000.00 جنيه في حسابك', '8000', 'income', ''),
      ('Your OTP is 482913. Do not share it.', null, 'expense', null),
      ('Spent 1.5k EGP at Cafe Nero', '1500', 'expense', 'Cafe Nero'),
      (
        'You received 2,500.75 EGP via InstaPay from Mona',
        '2500.75',
        'income',
        'Mona',
      ),
      (
        'Balance: EGP 15,430.20. Purchase 99.99 USD at Netflix',
        '99.99',
        'expense',
        'Netflix',
      ),
      ('تم خصم ٢٥٠٫٥٠ جنيه من بطاقتك', '250.5', 'expense', null),
      (
        'Purchase 75.00 USD at Shell. Available balance 1,200.00 USD',
        '75',
        'expense',
        'Shell',
      ),
      (
        'Verification code 1234 for your payment of EGP 500.00 at Noon',
        '500',
        'expense',
        'Noon',
      ),
      (
        'Salary EGP 25,000 credited to account ending 9988',
        '25000',
        'income',
        '',
      ),
    ];

    for (final (text, amount, type, merchant) in cases) {
      final label = text.length > 56 ? '${text.substring(0, 56)}…' : text;
      test(label, () {
        final c = parse(text);
        expect(c.amount, amount == null ? isNull : Amount(amount), reason: 'amount');
        expect(c.type, type, reason: 'type');
        if (merchant != null) expect(c.merchant, merchant, reason: 'merchant');
      });
    }
  });

  group('regressions', () {
    test('currency between card number and amount binds to the amount', () {
      final c = parse('Card 4521 EGP 250.00 purchase at Spinneys');
      expect(c.amount, Amount('250'));
      expect(c.currency, 'EGP');
      expect(c.cardLast4, '4521');
    });

    test('4-digit amount next to the word card is kept', () {
      expect(parse('Spent 1500 on card at Zara').amount, Amount('1500'));
    });

    test('space-grouped thousands', () {
      expect(parse('Deposit of 12 000 EGP received').amount, Amount('12000'));
    });

    test('European grouping', () {
      expect(parse('Paid EUR 1.250,50 at IKEA').amount, Amount('1250.50'));
    });

    test('three-decimal currencies', () {
      final c = parse('KWD 1.255 debited at Sultan Center');
      expect(c.amount, Amount('1.255'));
      expect(c.currency, 'KWD');
    });

    test('k suffix uses exact decimals', () {
      expect(parse('Spent 1.15k EGP at Zara').amount, Amount('1150'));
    });

    test('dates are not amounts and are extracted', () {
      final c = parse('Purchase at Spinneys on 12/05 amount 50 EGP');
      expect(c.amount, Amount('50'));
      expect(c.date, DateTime(2026, 5, 12));
    });

    test('full dates and times', () {
      final c = parse('Debited EGP 300.00 at Seoudi on 03/10/2026 14:22');
      expect(c.amount, Amount('300'));
      expect(c.date, DateTime(2026, 10, 3, 14, 22));
    });

    test('month-name and Arabic dates', () {
      expect(parse('Spent 20 USD at Costa on 5 Oct').date, DateTime(2026, 10, 5));
      expect(
        parse('تم خصم 100 جنيه بتاريخ 9 أكتوبر 2026').date,
        DateTime(2026, 10, 9),
      );
    });

    test('a future date without a year belongs to last year', () {
      expect(parse('Spent 20 USD on 25 Dec').date, DateTime(2025, 12, 25));
    });

    test('reference numbers are not amounts', () {
      final c = parse('Paid EGP 45.00 at Uber Ref 88213345');
      expect(c.amount, Amount('45'));
      expect(c.reference, '88213345');
    });

    test('balance far before the amount does not hide it', () {
      expect(
        parse('Your balance is low. Spent 20 EGP at Kiosk').amount,
        Amount('20'),
      );
    });

    test('"global" and "present" are not balance or sent words', () {
      final c = parse('Global Market charged 60.00 USD');
      expect(c.amount, Amount('60'));
      expect(c.type, 'expense');
    });

    test('refund in a transaction alert is income', () {
      final c = parse('Transaction alert: refund of 30.00 USD from Noon');
      expect(c.type, 'income');
      expect(c.kind, TransactionKind.refund);
    });

    test('merchant skips "your card" and prefers the shop', () {
      expect(
        parse('EGP 99.00 deducted from your card at Carrefour').merchant,
        'Carrefour',
      );
    });

    test('merchant keeps dotted names', () {
      expect(parse('Paid 15.00 USD at Amazon.com').merchant, 'Amazon.com');
      expect(parse('Spent 300 AED at St. Regis Hotel').merchant, 'St. Regis Hotel');
    });

    test('email addresses are not merchants', () {
      final c = parse('Receipt sent to me@mail.com: paid 10 USD at Spotify');
      expect(c.merchant, 'Spotify');
    });

    test('Apple Pay alone does not imply shopping', () {
      final c = parse('Apple Pay: spent 24.90 USD at Starbucks');
      expect(c.categoryHint, 'food');
    });

    test('Metro Market is groceries, not transport', () {
      expect(parse('Spent EGP 640 at Metro Market').categoryHint, 'groceries');
    });

    test('currency carried through, bank default when missing', () {
      expect(parse('Spent 24.90 USD at Starbucks').currency, 'USD');
      expect(parse('CIB: you paid 89.00 to Uber').currency, 'EGP');
    });

    test('Arabic income words', () {
      expect(parse('تم إضافة 500 جنيه إلى حسابك').type, 'income');
      expect(parse('أضيف مبلغ 1,000 جنيه لحسابك').type, 'income');
    });
  });

  group('non-transactions', () {
    final cases = <(String, TransactionKind)>[
      ('Your OTP is 482913. Do not share it.', TransactionKind.otp),
      (
        'Transaction of EGP 450.00 at Zara was declined: insufficient funds',
        TransactionKind.declined,
      ),
      (
        'Your credit card payment of EGP 3,200.00 is due on 25/10/2026',
        TransactionKind.paymentDue,
      ),
      (
        'Get 20% off when you spend EGP 500 at Noon! Use code SAVE20',
        TransactionKind.promo,
      ),
      ('Your available balance is EGP 15,430.20', TransactionKind.balanceOnly),
      ('عملية شراء بمبلغ 200 جنيه مرفوضة', TransactionKind.declined),
    ];
    for (final (text, kind) in cases) {
      test(kind.name, () {
        final c = parse(text);
        expect(c.kind, kind);
        expect(c.isTransaction, isFalse);
      });
    }
  });

  group('confidence', () {
    test('no usable amount means low confidence', () {
      expect(parse('Your OTP is 482913. Do not share it.').confidence, lessThan(0.5));
    });

    test('a complete alert is confident', () {
      expect(
        parse('Purchase of EGP 1,250.50 at Carrefour on 12/10/2026').confidence,
        greaterThan(0.8),
      );
    });

    test('a bare number is not confident', () {
      expect(parse('Starbucks 5').confidence, lessThan(0.6));
    });
  });

  group('merchant keys', () {
    test('strip processor prefixes, store numbers and suffixes', () {
      expect(
        LocalTransactionParser.normalizeMerchant('SQ *Blue Bottle #12 LLC'),
        'blue bottle',
      );
      expect(LocalTransactionParser.normalizeMerchant('UBER *TRIP 4421'), 'uber trip');
    });
  });

  group('amount text', () {
    test('review form amounts', () {
      expect(TextNormalizer.parseAmount('1,250.50'), Amount('1250.50'));
      expect(TextNormalizer.parseAmount('١٬٢٥٠٫٥٠'), Amount('1250.50'));
      expect(TextNormalizer.parseAmount('12 000'), Amount('12000'));
      expect(TextNormalizer.parseAmount('0'), isNull);
      expect(TextNormalizer.parseAmount('abc'), isNull);
    });
  });

  group('splitter', () {
    test('blank-line separated messages', () {
      expect(
        MessageSplitter.split(
          'Spent 20 USD at Costa\n\nCIB: you paid 89.00 EGP to Uber',
        ),
        hasLength(2),
      );
    });

    test('one message per line', () {
      expect(
        MessageSplitter.split(
          'Purchase of EGP 100.00 at Seoudi\nPurchase of EGP 55.50 at Uber',
        ),
        hasLength(2),
      );
    });

    test('a wrapped message stays whole', () {
      expect(
        MessageSplitter.split('Dear customer,\nEGP 100.00 was debited at Seoudi'),
        hasLength(1),
      );
    });
  });
}
