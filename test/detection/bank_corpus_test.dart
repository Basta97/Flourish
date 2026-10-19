import 'package:flourish/core/detection/parsed_payment.dart';
import 'package:flourish/core/detection/payment_parser.dart';
import 'package:flourish/domain/finance/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Formats seen from Egyptian and Gulf banks, wallets and Apple Pay
/// automations. (text, kind or ignore reason, amount, currency, merchant).
const corpus = <(String, String, String?, String?, String?)>[
  ('Dear Customer, your CIB Credit Card ending with 4521 was charged for EGP 1,250.00 at CARREFOUR CITY STARS on 18/10/26 14:32. Available limit EGP 23,750.00', 'purchase', '1250', 'EGP', 'CARREFOUR CITY STARS'),
  ('CIB: Your account **7788 has been debited by EGP 500.00 for InstaPay transfer to Ahmed M. Ref:123456789', 'transfer_out', '500', 'EGP', null),
  ('تم خصم 350.00 جنيه من حسابك رقم ***1234 لشراء من FAWRY بتاريخ 18/10 الرصيد المتاح 4,210.50 جنيه', 'bill_payment', '350', 'EGP', 'FAWRY'),
  ('تم إضافة مبلغ 15,000.00 جنيه إلى حسابك ***1234 تحويل من شركة الأمل للمرتبات', 'deposit', '15000', 'EGP', null),
  ('NBE: Purchase of EGP 85.50 using card ending 9012 at UBER *TRIP on 18-10-2026', 'purchase', '85.5', 'EGP', null),
  ('بنك مصر: عملية شراء بمبلغ 220 جنيه ببطاقتك المنتهية بـ 3344 لدى كارفور المعادي', 'purchase', '220', 'EGP', 'كارفور المعادي'),
  ('Vodafone Cash: You have received 1,000 EGP from 01012345678. Your balance is 2,350 EGP', 'transfer_in', '1000', 'EGP', null),
  ('فودافون كاش: تم تحويل 500 جنيه إلى 01112223334 بنجاح. رصيدك الحالي 1,850 جنيه', 'transfer_out', '500', 'EGP', null),
  ('InstaPay: You sent EGP 750.00 to mona@instapay. Ref 9988776655', 'transfer_out', '750', 'EGP', null),
  ('Your QNB card ending 5566 was used for USD 12.99 at NETFLIX.COM. Equivalent EGP 640.00', 'purchase', '12.99', 'USD', 'NETFLIX.COM'),
  ('HSBC: Payment of AED 245.75 at CARREFOUR MOE on your card ending 7781 approved', 'purchase', '245.75', 'AED', 'CARREFOUR MOE'),
  ('Al Rajhi: POS purchase SAR 89.00 at Panda Store card 1122 18/10/2026 20:15', 'purchase', '89', 'SAR', 'Panda Store'),
  ('تم سحب نقدي بمبلغ 2,000 جنيه من ماكينة الصراف الآلي ببطاقتك رقم ***6677', 'withdrawal', '2000', 'EGP', null),
  ('Your salary of EGP 32,500.00 has been credited to account ***1234', 'deposit', '32500', 'EGP', null),
  ('ValU: Your installment of EGP 1,200.00 for Noon order is due on 25/10/2026', 'notice', null, null, null),
  ('Fawry: Payment of EGP 312.40 for WE Internet bill successful. Ref 445566', 'bill_payment', '312.4', 'EGP', 'WE Internet'),
  ('CIB: Refund of EGP 199.00 from AMAZON EG credited to card ending 4521', 'refund', '199', 'EGP', 'AMAZON EG'),
  ('Your card ending 4521 transaction of EGP 450.00 at ZARA was declined due to insufficient funds', 'declined', null, null, null),
  ('Banque Misr: Transfer of EGP 3,000 to account 1002003004005 completed', 'transfer_out', '3000', 'EGP', null),
  ('You paid E£45 at Costa Coffee with Apple Pay', 'purchase', '45', 'EGP', 'Costa Coffee'),
  ('تم خصم مبلغ ٢٬٥٠٠٫٠٠ ج.م من بطاقتك الائتمانية ****8899 لدى أمازون', 'purchase', '2500', 'EGP', 'أمازون'),
  ('Spent 640 LE at Spinneys', 'purchase', '640', 'EGP', 'Spinneys'),
  ('Apple Pay purchase of ج.م.‏ ١٢٥٫٥٠ at Starbucks', 'purchase', '125.5', 'EGP', 'Starbucks'),
  ('Apple Pay purchase of \$12.99 at Apple', 'purchase', '12.99', 'USD', 'Apple'),
];

void main() {
  final at = DateTime(2026, 10, 19, 12);
  for (final (text, kind, amount, currency, merchant) in corpus) {
    test(text.length > 60 ? '${text.substring(0, 60)}…' : text, () {
      final p = PaymentMessageParser.parse(
        RawMessage(text: text, receivedAt: at, source: 'test'),
      );
      expect(p.ignoreReason ?? p.kind, kind);
      expect(p.amount, amount == null ? isNull : Amount(amount));
      expect(p.currency, currency);
      if (merchant != null) expect(p.merchant ?? p.counterparty, merchant);
    });
  }
}
