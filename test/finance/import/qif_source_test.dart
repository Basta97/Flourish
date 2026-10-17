import 'package:flourish/core/finance/import/import_source.dart';
import 'package:flourish/core/finance/import/qif_source.dart';
import 'package:flourish/domain/finance/amount.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  const qif = QifSource();

  test('reads a multi-account Quicken export', () {
    final result = qif.parse(fixture('quicken_us.qif'));
    expect(result.errors, hasLength(1));
    expect(result.errors.single.message, contains('Unrecognised date'));
    expect(result.rows, hasLength(5));

    final rent = result.rows[0];
    expect(rent.date, DateTime(2024, 1, 2));
    expect(rent.amount, Amount('1234.56'));
    expect(rent.type, 'expense');
    expect(rent.account, 'Checking');
    expect(rent.category, 'Housing');
    expect(rent.subcategory, 'Rent');
    expect(rent.payee, 'Landlord');
    expect(rent.note, 'January rent');

    final [food, household] = result.rows.sublist(1, 3);
    expect(food.amount, Amount('100'));
    expect((food.category, food.subcategory), ('Food', 'Groceries'));
    expect(food.note, 'Weekly shop');
    expect(food.payee, 'Supermarket');
    expect(household.amount, Amount('50'));
    expect(household.category, 'Household');
    expect(household.date, DateTime(2024, 1, 15));

    final transfer = result.rows[3];
    expect(transfer.type, 'transfer');
    expect(transfer.account, 'Checking');
    expect(transfer.destinationAccount, 'Savings');
    expect(transfer.amount, Amount('300'));
    expect(transfer.category, isNull);

    final salary = result.rows[4];
    expect(salary.type, 'income');
    expect(salary.category, 'Salary');
    expect(salary.amount, Amount('2000'));

    expect(total(result, 'expense'), Amount('1384.56'));
    expect(
      result.warnings.map((w) => w.message),
      containsAll([
        contains('opening balance'),
        contains('other side of the transfer'),
      ]),
    );
  });

  test('splits can stay as one row', () {
    final result = qif.parse(
      fixture('quicken_us.qif'),
      options: const ImportOptions(expandSplits: false),
    );
    final shop = result.rows.where((r) => r.payee == 'Supermarket').single;
    expect(shop.amount, Amount('150'));
    expect(shop.category, 'Food');
  });

  test('day-first dates, apostrophe years and European decimals', () {
    final result = qif.parse(
      fixture('european.qif'),
      options: const ImportOptions(
        defaultAccount: 'Visa',
        defaultCurrency: 'EUR',
      ),
    );
    expect(result.errors, isEmpty);
    expect(result.rows.map((r) => r.date), [
      DateTime(2024, 2, 15),
      DateTime(2024, 2, 28),
      DateTime(2024, 2, 29),
    ]);
    expect(result.rows.map((r) => r.amount), [
      Amount('1234.56'),
      Amount('12.5'),
      Amount('99.9'),
    ]);
    expect(result.rows.map((r) => r.type), ['expense', 'expense', 'income']);
    expect(result.rows.first.subcategory, 'Electronics');
    expect(result.rows.every((r) => r.account == 'Visa'), isTrue);
    expect(result.rows.every((r) => r.currency == 'EUR'), isTrue);
  });

  test('split totals that disagree are flagged', () {
    final result = qif.parse(
      '!Type:Cash\nD1/2/24\nT-10\nSA\n\$-4\nSB\n\$-5\n^\n',
    );
    expect(result.rows, hasLength(2));
    expect(result.warnings.single.message, contains('Splits add up'));
  });

  test('malformed records are errors, not crashes', () {
    final result = qif.parse(
      '!Type:Bank\nT-5\n^\nD1/1/24\nTfive\n^\nD1/2/24\n',
    );
    expect(result.rows, isEmpty);
    expect(result.errors, hasLength(3));
    expect(result.errors.map((e) => e.line), [2, 4, 7]);
    expect(qif.canRead('a.qif', ''), isTrue);
    expect(qif.canRead('a.txt', '﻿!Type:Bank\n'), isTrue);
    expect(qif.canRead('a.csv', 'Date,Amount'), isFalse);
  });

  test('investment registers are skipped with a warning', () {
    final result = qif.parse('!Type:Invst\nD1/1/24\nNBuy\nT100\n^\n');
    expect(result.rows, isEmpty);
    expect(result.warnings.single.message, contains('Investment'));
  });
}
