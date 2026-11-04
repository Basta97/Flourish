import '../../domain/finance/amount.dart';
import 'amount_parser.dart';
import 'text_normalizer.dart';

enum CalculationError { incomplete, divideByZero, negative }

/// Evaluates arithmetic using the same exact decimals and number separators
/// as the finance forms. Multiplication and division take precedence.
class AmountCalculator {
  AmountCalculator._(this._text);

  final String _text;
  int _at = 0;

  static Amount evaluate(
    String expression, {
    int? decimalPlaces,
    bool allowNegative = false,
  }) {
    final text = TextNormalizer.digits(
      expression,
    ).replaceAll('×', '*').replaceAll('÷', '/').replaceAll('−', '-');
    if (text.isEmpty || text.length > 512) {
      throw CalculationError.incomplete;
    }
    final parser = AmountCalculator._(text);
    final amount = parser._sum();
    parser._spaces();
    if (parser._at != text.length) throw CalculationError.incomplete;
    if (!allowNegative && amount < Amount.zero) {
      throw CalculationError.negative;
    }
    return decimalPlaces == null ? amount : amount.rounded(decimalPlaces);
  }

  void _spaces() {
    while (_at < _text.length && _text[_at].trim().isEmpty) {
      _at++;
    }
  }

  bool _take(String character) {
    _spaces();
    if (_at < _text.length && _text[_at] == character) {
      _at++;
      return true;
    }
    return false;
  }

  Amount _sum() {
    var value = _product();
    while (true) {
      if (_take('+')) {
        value += _product();
      } else if (_take('-')) {
        value -= _product();
      } else {
        return value;
      }
    }
  }

  Amount _product() {
    var value = _number();
    while (true) {
      if (_take('*')) {
        value *= _number();
      } else if (_take('/')) {
        final divisor = _number();
        if (divisor == Amount.zero) throw CalculationError.divideByZero;
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  Amount _number() {
    if (_take('+')) return _number();
    if (_take('-')) return -_number();
    if (_take('(')) {
      final value = _sum();
      if (!_take(')')) throw CalculationError.incomplete;
      return value;
    }
    _spaces();
    final start = _at;
    while (_at < _text.length && RegExp(r'[\d.,\s]').hasMatch(_text[_at])) {
      _at++;
    }
    if (start == _at) throw CalculationError.incomplete;
    try {
      return AmountParser.decimal(_text.substring(start, _at));
    } on ArgumentError {
      throw CalculationError.incomplete;
    } on FormatException {
      throw CalculationError.incomplete;
    }
  }
}
