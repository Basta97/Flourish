import 'package:decimal/decimal.dart';

/// Exact decimal arithmetic. Doubles are only used at legacy/UI boundaries.
final class Amount implements Comparable<Amount> {
  final Decimal value;
  Amount(String text) : value = Decimal.parse(text.trim());
  Amount._(this.value);
  factory Amount.fromNum(num value) {
    if (!value.isFinite) throw const FormatException('Amount must be finite');
    return Amount(value.toString());
  }
  static final zero = Amount('0');
  static final one = Amount('1');
  Amount operator +(Amount other) => Amount._(value + other.value);
  Amount operator -(Amount other) => Amount._(value - other.value);
  Amount operator *(Amount other) => Amount._(value * other.value);
  Amount operator /(Amount other) {
    if (other == zero) throw ArgumentError('Cannot divide by zero');
    return Amount._(
      (value / other.value).toDecimal(scaleOnInfinitePrecision: 24),
    );
  }

  Amount operator -() => zero - this;
  bool operator <(Amount other) => compareTo(other) < 0;
  bool operator <=(Amount other) => compareTo(other) <= 0;
  bool operator >(Amount other) => compareTo(other) > 0;
  bool operator >=(Amount other) => compareTo(other) >= 0;
  Amount get abs => this < zero ? -this : this;
  Amount rounded([int digits = 2]) => Amount._(value.round(scale: digits));
  double toDouble() => value.toDouble();
  String fixed([int digits = 2]) => value.toStringAsFixed(digits);
  @override
  int compareTo(Amount other) => value.compareTo(other.value);
  @override
  String toString() => value.toString();
  @override
  bool operator ==(Object other) => other is Amount && value == other.value;
  @override
  int get hashCode => value.hashCode;
}

final class Money {
  final Amount amount;
  final String currency;
  Money(String amount, this.currency) : amount = Amount(amount) {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw ArgumentError('Invalid currency');
    }
  }
}

final class Quantity {
  final Amount amount;
  Quantity(String value) : amount = Amount(value);
}

final class ExchangeRate {
  final String base, quote;
  final Amount rate;
  ExchangeRate(this.base, this.quote, String rate) : rate = Amount(rate) {
    if (this.rate <= Amount.zero) throw ArgumentError('Rate must be positive');
  }
  Amount convert(Amount amount) => amount * rate;
}
