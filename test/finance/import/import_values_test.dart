import 'package:flourish/core/finance/import/import_source.dart';
import 'package:flourish/core/finance/import/import_values.dart';
import 'package:flourish/domain/finance/amount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Amount amount(String raw, [String? decimal]) =>
      ImportValues.amount(raw, decimalSeparator: decimal);

  test('amounts in the formats statements use', () {
    expect(amount('1,234.56'), Amount('1234.56'));
    expect(amount('1.234,56'), Amount('1234.56'));
    expect(amount('-12,50'), Amount('-12.5'));
    expect(amount('1,234'), Amount('1234'));
    expect(amount('1.234', ','), Amount('1234'));
    expect(amount('(19.99)'), Amount('-19.99'));
    expect(amount('19.99-'), Amount('-19.99'));
    expect(amount('45.00 DR'), Amount('-45'));
    expect(amount('45.00CR'), Amount('45'));
    expect(amount(r'$1,000.00'), Amount('1000'));
    expect(amount('-\$5.45'), Amount('-5.45'));
    expect(amount('EGP 1 250,75'), Amount('1250.75'));
    expect(amount("1'234.50"), Amount('1234.5'));
    expect(amount('−7'), Amount('-7'));
    expect(amount('١٬٢٣٤٫٥'), Amount('1234.5'));
    expect(() => amount('abc'), throwsFormatException);
    expect(() => amount(''), throwsFormatException);
    expect(() => amount('1.2.3,4.5'), throwsFormatException);
  });

  test('decimal separator detection looks at the whole column', () {
    expect(ImportValues.detectDecimalSeparator(['1,234', '12,50']), ',');
    expect(ImportValues.detectDecimalSeparator(['1,234', '12.50']), '.');
    expect(ImportValues.detectDecimalSeparator(['1.234.567']), ',');
    expect(ImportValues.detectDecimalSeparator(['12', '1,234']), isNull);
  });

  test('dates in numeric, ISO, Quicken and month-name forms', () {
    DateTime d(String raw, [DateOrder? order]) =>
        ImportValues.date(raw, order: order);
    expect(d('2024-03-04'), DateTime(2024, 3, 4));
    expect(d('2024-03-04T10:20:30.000Z'), DateTime(2024, 3, 4, 10, 20, 30));
    expect(d('2024-05-01T23:30:00+02:00'), DateTime(2024, 5, 1, 23, 30));
    expect(d('20240304'), DateTime(2024, 3, 4));
    expect(d('03/04/2024'), DateTime(2024, 4, 3));
    expect(d('03/04/2024', DateOrder.mdy), DateTime(2024, 3, 4));
    expect(d('13/04/2024', DateOrder.mdy), DateTime(2024, 4, 13));
    expect(d('04/13/2024'), DateTime(2024, 4, 13));
    expect(d("1/ 2'24", DateOrder.mdy), DateTime(2024, 1, 2));
    expect(d("1/2'24", DateOrder.dmy), DateTime(2024, 2, 1));
    expect(d('12/31/98', DateOrder.mdy), DateTime(1998, 12, 31));
    expect(d('3.4.24'), DateTime(2024, 4, 3));
    expect(
      d('01/31/2024 06:20 PM', DateOrder.mdy),
      DateTime(2024, 1, 31, 18, 20),
    );
    expect(d('15 Jan 2024'), DateTime(2024, 1, 15));
    expect(d('15-Jan-24'), DateTime(2024, 1, 15));
    expect(d('January 5, 2024'), DateTime(2024, 1, 5));
    expect(() => d('31/04/2024'), throwsFormatException);
    expect(() => d('yesterday'), throwsFormatException);
    expect(
      ImportValues.date('04.03.2024', pattern: 'MM.dd.yyyy'),
      DateTime(2024, 4, 3),
    );
  });

  test('date order detection', () {
    expect(
      ImportValues.detectDateOrder(['01/02/2024', '25/02/2024']),
      DateOrder.dmy,
    );
    expect(
      ImportValues.detectDateOrder(['01/02/2024', '02/25/2024']),
      DateOrder.mdy,
    );
    expect(ImportValues.detectDateOrder(['01/02/2024']), isNull);
  });

  test('currencies and category paths', () {
    expect(ImportValues.currency('egp'), 'EGP');
    expect(ImportValues.currency(r'$'), 'USD');
    expect(ImportValues.currency('€'), 'EUR');
    expect(ImportValues.currency('Dollars'), isNull);
    expect(ImportValues.categoryPath('Food:Groceries'), ('Food', 'Groceries'));
    expect(ImportValues.categoryPath('A:B:C'), ('A', 'B:C'));
    expect(ImportValues.categoryPath('Food'), ('Food', null));
    expect(ImportValues.categoryPath(' '), (null, null));
  });
}
