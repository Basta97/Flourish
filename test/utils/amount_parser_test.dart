import 'package:flutter_test/flutter_test.dart';
import 'package:flourish/core/utils/amount_parser.dart';
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/domain/finance/amount.dart';

void main() {
  Amount? egp(String text, {bool lenient = false}) =>
      AmountParser.parse(text, currency: 'EGP', lenient: lenient).value;

  test('accepts the separators people actually type', () {
    expect(egp('1,234.56'), Amount('1234.56'));
    expect(egp('1.234,56'), Amount('1234.56'));
    expect(egp('12,50'), Amount('12.5'));
    expect(egp('1,234'), Amount('1234'));
    expect(egp('1,234,567'), Amount('1234567'));
    expect(egp('1.234.567'), Amount('1234567'));
    expect(egp('1 234,56'), Amount('1234.56'));
    expect(egp('0.5'), Amount('0.5'));
    expect(egp('.5'), Amount('0.5'));
  });

  test('reads Arabic-Indic and Persian digits', () {
    expect(egp('١٬٢٣٤٫٥٦'), Amount('1234.56'));
    expect(egp('۱۲۳'), Amount('123'));
    expect(egp('١٢٣٫'), Amount('123'));
    expect(egp('‏١٢٣'), Amount('123'));
  });

  test('respects the currency minor unit', () {
    expect(
      AmountParser.parse('12.345', currency: 'KWD').value,
      Amount('12.345'),
    );
    expect(AmountParser.parse('12.345', currency: 'EGP').isValid, isFalse);
    expect(egp('12.345', lenient: true), Amount('12.35'));
    expect(AmountParser.parse('1.5', currency: 'JPY').isValid, isFalse);
    expect(CurrencyFormatter.decimalsFor('BHD'), 3);
    expect(CurrencyFormatter.decimalsFor('KRW'), 0);
    expect(CurrencyFormatter.decimalsFor('EGP'), 2);
  });

  test('lenient mode ignores surrounding text', () {
    expect(egp('EGP 1,000.00', lenient: true), Amount('1000'));
    expect(egp('1,250.75 ج.م', lenient: true), Amount('1250.75'));
  });

  test('rejects malformed or non-positive input', () {
    for (final bad in ['', 'abc', '-5', '1.2.3', '1,23,4', '0', '12a']) {
      expect(
        AmountParser.parse(bad, currency: 'EGP').isValid,
        isFalse,
        reason: bad,
      );
    }
    expect(
      AmountParser.parse('0', currency: 'EGP', allowZero: true).value,
      Amount('0'),
    );
  });

  test('compact format keeps the sign and never shows 1000.0K', () {
    expect(CurrencyFormatter.formatCompact(-2500, currency: 'USD'), r'-$2.5K');
    expect(
      CurrencyFormatter.formatCompact(999960, currency: 'EGP'),
      'EGP 1.0M',
    );
    expect(CurrencyFormatter.format(1.5, currency: 'KWD'), 'KWD 1.500');
    expect(
      CurrencyFormatter.symbolFor('CNY'),
      isNot(CurrencyFormatter.symbolFor('JPY')),
    );
  });
}
