import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flourish/core/detection/parsed_payment.dart';
import 'package:flourish/core/detection/payment_parser.dart';
import 'package:flourish/core/detection/redact.dart';
import 'package:flourish/domain/finance/models.dart';

/// Synthetic messages modelled on common Egyptian bank and wallet alerts.
/// Real formats vary by bank and change over time: replace and extend these
/// with redacted real samples as they are collected.
class Fixture {
  final String text;
  final String? sender;
  final String? kind, currency, amount, last4, merchant, counterparty;
  final String? balance, available, booked, fee, ignore, issuer;
  final String direction;
  final DateTime? date;
  const Fixture(
    this.text, {
    this.sender,
    this.kind,
    this.currency,
    this.amount,
    this.last4,
    this.merchant,
    this.counterparty,
    this.balance,
    this.available,
    this.booked,
    this.fee,
    this.ignore,
    this.issuer,
    this.direction = 'expense',
    this.date,
  });
}

final received = DateTime(2026, 10, 15, 14, 30);

final fixtures = <Fixture>[
  // ── English ──────────────────────────────────────────────────────────
  Fixture(
    'Your CIB credit card ending with 1234 was charged EGP 1,250.50 at CARREFOUR MAADI on 14/10/2026 18:22. Available limit EGP 23,749.50',
    sender: 'CIB',
    kind: 'purchase',
    currency: 'EGP',
    amount: '1250.5',
    last4: '1234',
    merchant: 'CARREFOUR MAADI',
    issuer: 'cib',
    date: null,
  ),
  Fixture(
    'Card xxxx4321 Purchase USD 12.99 NETFLIX.COM. Equivalent EGP 650.20',
    kind: 'purchase',
    currency: 'USD',
    amount: '12.99',
    last4: '4321',
    merchant: 'NETFLIX.COM',
    booked: '650.2',
  ),
  Fixture(
    'card ending 4321 was charged EGP 1,234 at Amazon',
    kind: 'purchase',
    amount: '1234',
    last4: '4321',
    merchant: 'Amazon',
  ),
  Fixture(
    'Available balance EGP 12,345.67. Purchase EGP 99.00 at Uber',
    kind: 'purchase',
    amount: '99',
    balance: '12345.67',
    merchant: 'Uber',
  ),
  Fixture(
    'On 15/10 you paid EGP 250 to Talabat',
    kind: 'purchase',
    amount: '250',
    merchant: 'Talabat',
  ),
  Fixture(
    'Sat 12 Oct: spent 75.00 EGP at Costa Coffee',
    kind: 'purchase',
    amount: '75',
    merchant: 'Costa Coffee',
  ),
  Fixture(
    'Your OTP for transaction of EGP 1,500.00 at AMAZON is 123456. Do not share it.',
    ignore: 'otp',
  ),
  Fixture(
    'Your card transaction of EGP 500.00 at NOON was declined due to insufficient funds.',
    ignore: 'declined',
  ),
  Fixture(
    'Enjoy 20% cashback up to EGP 500 on all online purchases this weekend!',
    ignore: 'promo',
  ),
  Fixture(
    'Refund of EGP 300.00 from ZARA has been credited to your card ending 1234',
    kind: 'refund',
    amount: '300',
    direction: 'income',
    last4: '1234',
    merchant: 'ZARA',
  ),
  Fixture(
    'ATM cash withdrawal of EGP 2,000.00 from your account **5678. Balance EGP 8,500.00',
    kind: 'withdrawal',
    amount: '2000',
    last4: '5678',
    balance: '8500',
  ),
  Fixture(
    'Your account has been credited with EGP 15,000.00 salary. Avl Bal EGP 21,200.00',
    kind: 'deposit',
    amount: '15000',
    direction: 'income',
    balance: '21200',
  ),
  Fixture(
    'You received EGP 1,000.00 from Mona Ahmed via InstaPay',
    sender: 'InstaPay',
    kind: 'transfer_in',
    amount: '1000',
    direction: 'income',
    counterparty: 'Mona Ahmed',
    issuer: 'instapay',
  ),
  Fixture(
    'You sent EGP 300.00 to 01012345678 via InstaPay. Fees EGP 1.50',
    kind: 'transfer_out',
    amount: '300',
    fee: '1.5',
    counterparty: '010*****678',
  ),
  Fixture(
    'Your payment of EGP 3,000.00 towards your credit card was received. Thank you.',
    kind: 'card_payment',
    amount: '3000',
    direction: 'income',
  ),
  Fixture(
    'Card XXXX-XXXX-XXXX-9876 POS purchase KWD 12.345 at Avenues Mall',
    kind: 'purchase',
    currency: 'KWD',
    amount: '12.345',
    last4: '9876',
    merchant: 'Avenues Mall',
  ),
  Fixture(
    'Fawry: bill payment of EGP 420.00 for WE Internet. Ref 77881234',
    kind: 'bill_payment',
    amount: '420',
  ),
  Fixture(
    'Debit card ending 1111 used at SPINNEYS for LE 845.75',
    kind: 'purchase',
    amount: '845.75',
    last4: '1111',
    merchant: 'SPINNEYS',
  ),
  Fixture(
    'Your HSBC card ending 2468 was debited with GBP 20.00 at PRET A MANGER LONDON',
    sender: 'HSBC',
    kind: 'purchase',
    currency: 'GBP',
    amount: '20',
    last4: '2468',
    issuer: 'hsbc_eg',
  ),
  Fixture(
    'Transaction of EGP 1.234,50 at ZARA CITY STARS',
    kind: 'purchase',
    amount: '1234.5',
    merchant: 'ZARA CITY STARS',
  ),
  Fixture(
    'Your statement is ready. Minimum payment EGP 500 due on 25/10.',
    ignore: 'notice',
  ),
  // ── Arabic ───────────────────────────────────────────────────────────
  Fixture(
    'تم خصم ١٢٣٫٤٥ جنيه من بطاقتك رقم 1234 لدى كارفور بتاريخ 14/10',
    kind: 'purchase',
    currency: 'EGP',
    amount: '123.45',
    last4: '1234',
    merchant: 'كارفور',
  ),
  Fixture(
    'عملية شراء بقيمة 250.00 ج.م ببطاقتك المنتهية ب 5678 لدى أوبر',
    kind: 'purchase',
    currency: 'EGP',
    amount: '250',
    last4: '5678',
    merchant: 'أوبر',
  ),
  Fixture(
    'تم إيداع مبلغ ٥٠٠٠ جنيه في حسابك رقم 4455. رصيدك الحالي ١٢٬٣٠٠ جنيه',
    kind: 'deposit',
    amount: '5000',
    direction: 'income',
    last4: '4455',
    balance: '12300',
  ),
  Fixture(
    'فودافون كاش: تم تحويل 300 جنيه إلى 01012345678 بنجاح. رصيدك 1200 جنيه',
    sender: 'VF-Cash',
    kind: 'transfer_out',
    amount: '300',
    counterparty: '010*****678',
    balance: '1200',
    issuer: 'vodafone_cash',
  ),
  Fixture(
    'تم استلام مبلغ 750 جنيه من 01298765432. رصيدك الحالي 1950 جنيه',
    kind: 'transfer_in',
    amount: '750',
    direction: 'income',
    counterparty: '012*****432',
    balance: '1950',
  ),
  Fixture(
    'رمز التحقق الخاص بك هو 482913 لعملية شراء بقيمة 900 جنيه. لا تشارك هذا الرمز',
    ignore: 'otp',
  ),
  Fixture('تم رفض عملية بقيمة 1500 جنيه لعدم كفاية الرصيد', ignore: 'declined'),
  Fixture(
    'تم رد مبلغ 200 جنيه إلى بطاقتك المنتهية ب 1234 من نون',
    kind: 'refund',
    amount: '200',
    direction: 'income',
    last4: '1234',
  ),
  Fixture(
    'سحب نقدي بمبلغ 3000 جنيه من ماكينة الصراف. الرصيد المتاح 4500 جنيه',
    kind: 'withdrawal',
    amount: '3000',
    balance: '4500',
  ),
  Fixture(
    'فوري: تم دفع فاتورة الكهرباء بقيمة 360 جنيه. رقم العملية 99887766',
    kind: 'bill_payment',
    amount: '360',
  ),
  Fixture(
    'تـم خـصـم 45 جنيها من بطاقتك ‏1234‏ لدى طلبات',
    kind: 'purchase',
    amount: '45',
    merchant: 'طلبات',
  ),
  Fixture(
    'خصم ۱۵۰ ج.م من حسابك لدى سبينيس',
    kind: 'purchase',
    amount: '150',
    merchant: 'سبينيس',
  ),
  Fixture(
    'إنستاباي: تم تحويل مبلغ 2,500 جنيه إلى أحمد محمد. رسوم 5 جنيه',
    kind: 'transfer_out',
    amount: '2500',
    fee: '5',
    counterparty: 'أحمد محمد',
  ),
  Fixture(
    'تم خصم 50 دولار أمريكي من بطاقتك 9988 لدى AMAZON.COM بما يعادل 2,520 جنيه',
    kind: 'purchase',
    currency: 'USD',
    amount: '50',
    last4: '9988',
    booked: '2520',
    merchant: 'AMAZON.COM',
  ),
  Fixture('استمتع بخصم يصل إلى 30% عند الدفع ببطاقتك!', ignore: 'promo'),
  Fixture(
    'تم سداد مبلغ 4000 جنيه لبطاقتك الائتمانية. شكرا لك',
    kind: 'card_payment',
    amount: '4000',
    direction: 'income',
  ),
  Fixture(
    'valU: تم شراء بمبلغ 6000 جنيه من B.TECH على 12 شهر',
    kind: 'purchase',
    amount: '6000',
    merchant: 'B.TECH',
    issuer: 'valu',
  ),
  Fixture(
    'تم خصم 1200 جم من حسابك. الحد المتاح 18800 جم',
    kind: 'purchase',
    amount: '1200',
  ),
  Fixture(
    'البنك الأهلي: تم إضافة 2000 جنيه إلى حسابك من شركة النور',
    sender: 'NBE',
    kind: 'transfer_in',
    amount: '2000',
    direction: 'income',
    issuer: 'nbe',
  ),
  Fixture(
    'عملية بقيمة 99.99 يورو لدى BOOKING.COM',
    kind: 'purchase',
    currency: 'EUR',
    amount: '99.99',
    merchant: 'BOOKING.COM',
  ),
  Fixture(
    'Purchase EGP 100.00 at GOOGLE *YouTube',
    kind: 'purchase',
    amount: '100',
    merchant: 'GOOGLE *YouTube',
  ),

  // ── Real messages (numbers, card digits and codes changed) ───────────
  // Banque Misr credit card: words glued together without spaces.
  Fixture(
    'عميلناالعزيز،شكرًا لاستخدامكم بطاقة بنك مصر الائتمانية*****4827 تم خصم '
    'مبلغ EGP 2000 فيFACEBK *K7RTZP2بتاريخ 14/10/2026،الرصيدالمتاحEGP '
    '512.40،وحدالاستخدام الدولي المتاحEGP41250.75للمزيداتصل 19888',
    kind: 'purchase',
    amount: '2000',
    last4: '4827',
    merchant: 'FACEBK',
    available: '512.4',
    issuer: 'banque_misr',
    date: DateTime(2026, 10, 14),
  ),
];

void main() {
  for (final f in fixtures) {
    test(f.text, () {
      final p = PaymentMessageParser.parse(
        RawMessage(
          text: f.text,
          sender: f.sender,
          receivedAt: received,
          source: 'test',
        ),
      );
      if (f.ignore != null) {
        expect(p.ignoreReason, f.ignore);
        return;
      }
      if (f.amount == null) {
        // Not a payment and not ignored either: must not invent an amount
        // from dates or minimums with a payment kind.
        expect(p.kind == 'purchase' && p.amount != null, isFalse);
        return;
      }
      expect(p.ignoreReason, isNull);
      expect(p.amount, Amount(f.amount!), reason: 'amount');
      expect(p.kind, f.kind, reason: 'kind');
      expect(p.direction, f.direction, reason: 'direction');
      expect(p.currency, f.currency ?? 'EGP', reason: 'currency');
      if (f.last4 != null) expect(p.last4, f.last4, reason: 'last4');
      if (f.merchant != null) {
        expect(p.merchant, f.merchant, reason: 'merchant');
      }
      if (f.counterparty != null) {
        expect(p.counterparty, f.counterparty, reason: 'counterparty');
      }
      if (f.balance != null) {
        expect(p.balanceAfter, Amount(f.balance!), reason: 'balance');
      }
      if (f.available != null) {
        expect(p.availableCredit, Amount(f.available!), reason: 'available');
        expect(p.balanceAfter, isNull, reason: 'credit balance is no balance');
      }
      if (f.booked != null) {
        expect(p.bookedAmount, Amount(f.booked!), reason: 'booked');
      }
      if (f.fee != null) expect(p.fee, Amount(f.fee!), reason: 'fee');
      if (f.issuer != null) expect(p.issuerId, f.issuer, reason: 'issuer');
      if (f.date != null) {
        final d = p.occurredAt!;
        expect(DateTime(d.year, d.month, d.day), f.date, reason: 'date');
      }
    });
  }

  test('reads day-first dates and times', () {
    final p = PaymentMessageParser.parse(
      RawMessage(
        text: 'Purchase EGP 10.00 at X on 14/10/2026 18:22',
        receivedAt: received,
        source: 'test',
      ),
    );
    expect(p.occurredAt, DateTime(2026, 10, 14, 18, 22));
    final december = PaymentMessageParser.parse(
      RawMessage(
        text: 'spent EGP 5 on 30/12',
        receivedAt: DateTime(2027, 1, 2),
        source: 'test',
      ),
    );
    expect(december.occurredAt?.year, 2026);
  });

  test('redacts card numbers, national IDs and codes', () {
    expect(redact('card 4111 1111 1111 1111 used'), 'card ••••1111 used');
    expect(redact('ID 29801011234567'), 'ID [ID]');
    expect(redact('your code is 482913'), 'your code is [CODE]');
    expect(redact('sent to 01012345678'), 'sent to 010*****678');
  });

  test('never throws on arbitrary input', () {
    final random = Random(7);
    const alphabet = 'abcEGP\$€£جنيهتمخصملدى0123456789٠١٢٣٤٥٦٧٨٩.,:/- *x#\n';
    for (var i = 0; i < 2000; i++) {
      final text = String.fromCharCodes(
        List.generate(
          random.nextInt(120),
          (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
        ),
      );
      PaymentMessageParser.parse(
        RawMessage(text: text, receivedAt: received, source: 'fuzz'),
      );
    }
  });
}
