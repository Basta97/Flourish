import 'package:flutter_test/flutter_test.dart';
import 'package:flourish/core/detection/payment_parser.dart';
import 'package:flourish/core/detection/parsed_payment.dart';
import 'package:flourish/domain/finance/models.dart';

void main() {
  ParsedPayment parse(String text) => PaymentMessageParser.parse(
    RawMessage(
      text: text,
      receivedAt: DateTime(2026, 10, 19),
      source: 'notification',
    ),
  );
  for (final token in ['LE', 'le', 'Le', 'L.E', 'L.E.', 'l.e.']) {
    for (final text in [
      'Purchase $token 125.50 at Cafe',
      'Purchase 125.50$token at Cafe',
      'Purchase ${token}125.50 at Cafe',
      'Purchase $token١٢٥٫٥٠ at Cafe',
    ]) {
      test(text, () {
        final payment = parse(text);
        expect(payment.amount, Amount('125.5'));
        expect(payment.currency, 'EGP');
      });
    }
  }
  test('LE does not bypass safety exclusions or match word fragments', () {
    expect(parse('OTP for LE 125.50 purchase: 123456').ignored, true);
    expect(parse('Purchase LE 125.50 was declined').ignored, true);
    expect(parse('Sale 125.50 at Cafe').amount, isNull);
  });
}
