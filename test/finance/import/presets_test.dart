import 'package:flourish/core/finance/import/import_source.dart';
import 'package:flourish/core/finance/import/presets.dart';
import 'package:flourish/domain/finance/amount.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  ImportParseResult parse(CsvPreset preset, String file, [ImportOptions? o]) {
    final content = fixture(file);
    expect(CsvPresets.detect(content)?.id, preset.id, reason: file);
    return preset.parse(content, options: o ?? const ImportOptions());
  }

  test('Flourish export round-trips', () {
    final result = parse(CsvPresets.flourish, 'flourish_export.csv');
    expect(result.rows, hasLength(2));
    expect(result.errors.single.message, contains('refund'));
    expect(result.errors.single.line, 4);
    final dinner = result.rows.first;
    expect(dinner.date, DateTime(2024, 7, 1, 13, 45));
    expect(dinner.type, 'expense');
    expect(dinner.amount, Amount('350.5'));
    expect(dinner.account, 'CIB');
    expect(dinner.category, 'Dining');
    expect(dinner.payee, 'Zooba');
    expect(dinner.note, 'Dinner');
    expect(dinner.currency, 'EGP');
    expect(result.rows[1].note, isNull);
  });

  test('Money Manager with BOM, transfers and subcategories', () {
    final result = parse(CsvPresets.moneyManager, 'money_manager.csv');
    expect(result.errors.single.message, contains('Bonus'));
    expect(result.rows, hasLength(4));
    final lunch = result.rows.first;
    expect(lunch.date, DateTime(2024, 1, 31, 18, 20));
    expect((lunch.category, lunch.subcategory), ('Food', 'Lunch'));
    expect(lunch.note, 'Koshary\nwith team');
    expect(lunch.account, 'Cash');
    expect(total(result, 'income'), Amount('25000'));
    expect(total(result, 'expense'), Amount('205'));
    final atm = ofType(result, 'transfer').single;
    expect((atm.account, atm.destinationAccount), ('Bank', 'Cash'));
    expect(atm.amount, Amount('2000'));
    expect(result.warnings.single.message, contains('other side'));
  });

  test('Wallet: semicolons, comma decimals, paired transfer legs', () {
    final result = parse(CsvPresets.wallet, 'wallet.csv');
    expect(result.errors.single.line, 6);
    expect(result.rows, hasLength(3));
    expect(result.rows.first.amount, Amount('23.4'));
    expect(result.rows.first.payee, 'Lidl');
    expect(result.rows.first.date, DateTime(2024, 3, 2, 10, 15));
    expect(total(result, 'income'), Amount('1500'));
    final move = ofType(result, 'transfer').single;
    expect((move.account, move.destinationAccount), ('Bank', 'Cash'));
    expect(move.amount, Amount('200'));
    expect(move.category, isNull);
  });

  test('Monefy: day-first dates and To/From transfers', () {
    final result = parse(CsvPresets.monefy, 'monefy.csv');
    expect(result.errors.single.message, contains('Invalid date'));
    expect(result.rows, hasLength(3));
    expect(result.rows.first.date, DateTime(2024, 4, 2));
    expect(result.rows.first.amount, Amount('1250'));
    expect(result.rows.first.note, 'Groceries');
    final move = ofType(result, 'transfer').single;
    expect((move.account, move.destinationAccount), ('Card', 'Cash'));
  });

  test('Spendee: signed amounts and unmatched transfer legs', () {
    final result = parse(CsvPresets.spendee, 'spendee.csv');
    expect(result.errors, isEmpty);
    expect(result.rows, hasLength(4));
    expect(result.rows.first.category, 'Food & Drink');
    expect(result.rows.first.date, DateTime(2024, 5, 1, 12, 30));
    final move = ofType(result, 'transfer').single;
    expect((move.account, move.destinationAccount), ('Main', 'Savings'));
    expect(total(result, 'expense'), Amount('55.75'));
    expect(result.warnings.single.message, contains('no matching leg'));
  });

  test('YNAB: Outflow/Inflow, category groups, one transfer', () {
    final result = parse(
      CsvPresets.ynab,
      'ynab.csv',
      const ImportOptions(defaultCurrency: 'USD'),
    );
    expect(result.errors, isEmpty);
    expect(result.rows, hasLength(3));
    final grocer = result.rows.first;
    expect(grocer.date, DateTime(2024, 6, 3));
    expect(grocer.amount, Amount('45.10'));
    expect(grocer.type, 'expense');
    expect(
      (grocer.category, grocer.subcategory),
      ('Everyday Expenses', 'Groceries'),
    );
    expect(grocer.currency, 'USD');
    final move = ofType(result, 'transfer').single;
    expect((move.account, move.destinationAccount), ('Checking', 'Savings'));
    expect(move.note, 'rainy day');
    expect(total(result, 'income'), Amount('2400'));
    expect(result.warnings, hasLength(2));
  });

  test('bank CSV with sep= hint and Debit/Credit columns', () {
    final result = parse(
      CsvPresets.bank,
      'bank_debit_credit.csv',
      const ImportOptions(defaultAccount: 'Giro'),
    );
    expect(result.errors, isEmpty);
    expect(result.rows.map((r) => r.amount), [
      Amount('45.67'),
      Amount('3100'),
      Amount('1200'),
    ]);
    expect(result.rows.map((r) => r.type), ['expense', 'income', 'expense']);
    expect(result.rows.first.date, DateTime(2024, 8, 3));
    expect(result.rows.first.payee, 'REWE Markt');
    expect(result.rows.first.currency, 'EUR');
    expect(result.rows.first.account, 'Giro');
    expect(result.rows.first.sourceLine, 3);
  });

  test('bank CSV with one signed amount column', () {
    final result = parse(CsvPresets.bank, 'bank_signed.csv');
    expect(result.rows, hasLength(3));
    expect(result.errors.single.message, contains('Missing amount'));
    expect(result.rows[0].subcategory, 'Coffee');
    expect(result.rows[2].amount, Amount('19.99'));
    expect(result.rows[2].type, 'expense');
    expect(total(result, 'income'), Amount('2500'));
  });

  test('headers are matched loosely and may sit below title lines', () {
    const content =
        'My Budget as of 2024-06-30\n\n'
        'ACCOUNT,flag,date,PAYEE,Memo,Outflow,Inflow,Extra\n'
        'Cash,,06/30/2024,Shop,,5.00,0.00,x\n';
    expect(CsvPresets.detect(content)?.id, 'csv.ynab');
    final result = CsvPresets.ynab.parse(content);
    expect(result.rows.single.amount, Amount('5'));
    expect(result.rows.single.sourceLine, 4);
  });

  test('unrecognised CSV header', () {
    expect(CsvPresets.detect('foo,bar\n1,2\n'), isNull);
    expect(CsvPresets.bank.parse('foo,bar\n1,2\n').errors, hasLength(1));
  });

  test('every unverified preset cites where its layout came from', () {
    for (final p in CsvPresets.all) {
      expect(p.reference, isNotEmpty, reason: p.id);
    }
    expect(CsvPresets.all.where((p) => !p.verified).map((p) => p.id), [
      'csv.money_manager',
      'csv.ynab',
      'csv.wallet',
      'csv.spendee',
      'csv.monefy',
    ]);
  });
}
