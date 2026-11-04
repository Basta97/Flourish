import 'package:flourish/core/utils/amount_calculator.dart';
import 'package:flourish/domain/finance/amount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('combines costs with standard arithmetic precedence', () {
    expect(AmountCalculator.evaluate('125 + 75 + 40'), Amount('240'));
    expect(AmountCalculator.evaluate('125 + 75 × 2 − 10 ÷ 2'), Amount('270'));
    expect(AmountCalculator.evaluate('(125 + 75) × 2'), Amount('400'));
    expect(AmountCalculator.evaluate('100 - -5'), Amount('105'));
    expect(AmountCalculator.evaluate('25 - 25'), Amount.zero);
  });

  test('keeps money exact and rounds only the final currency total', () {
    expect(AmountCalculator.evaluate('0.1 + 0.2'), Amount('0.3'));
    expect(
      AmountCalculator.evaluate('10 ÷ 3', decimalPlaces: 2),
      Amount('3.33'),
    );
    expect(
      AmountCalculator.evaluate('0.005 + 0.005', decimalPlaces: 2),
      Amount('0.01'),
    );
    expect(
      AmountCalculator.evaluate('12.345 + 0.001', decimalPlaces: 3),
      Amount('12.346'),
    );
    expect(AmountCalculator.evaluate('10 ÷ 4', decimalPlaces: 0), Amount('3'));
    expect(AmountCalculator.evaluate('0.123456 × 2'), Amount('0.246912'));
  });

  test('uses the same localized separators as amount inputs', () {
    expect(AmountCalculator.evaluate('١٬٢٣٤٫٥٠ + ٢٥٫٥٠'), Amount('1260'));
    expect(AmountCalculator.evaluate('۱۲٫۵ × ۲'), Amount('25'));
    expect(AmountCalculator.evaluate('1,234.50 + 12,50'), Amount('1247'));
    expect(AmountCalculator.evaluate('1 234,50 + 12.50'), Amount('1247'));
  });

  test('rejects incomplete expressions, zero divisors, and negative money', () {
    for (final expression in [
      '',
      '12 +',
      '2 ×',
      '(2 + 3',
      '2 + 3)',
      '1.2.3 + 4',
      '2a3',
      '2 3',
      '()',
      '2(3)',
      '1' * 513,
    ]) {
      expect(
        () => AmountCalculator.evaluate(expression),
        throwsA(CalculationError.incomplete),
        reason: expression,
      );
    }
    expect(
      () => AmountCalculator.evaluate('5 ÷ (2 − 2)'),
      throwsA(CalculationError.divideByZero),
    );
    expect(
      () => AmountCalculator.evaluate('5 − 10'),
      throwsA(CalculationError.negative),
    );
    expect(
      AmountCalculator.evaluate('5 − 10', allowNegative: true),
      Amount('-5'),
    );
  });
}
