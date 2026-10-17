import 'package:flourish/core/finance/import/import_sources.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  test('every fixture is routed to its source', () {
    const expected = {
      'bank_sgml.ofx': 'ofx',
      'multi_xml.qfx': 'ofx',
      'quicken_us.qif': 'qif',
      'european.qif': 'qif',
      'flourish_export.csv': 'csv.flourish',
      'money_manager.csv': 'csv.money_manager',
      'wallet.csv': 'csv.wallet',
      'monefy.csv': 'csv.monefy',
      'spendee.csv': 'csv.spendee',
      'ynab.csv': 'csv.ynab',
      'bank_debit_credit.csv': 'csv.bank',
      'bank_signed.csv': 'csv.bank',
    };
    for (final MapEntry(key: file, value: id) in expected.entries) {
      expect(ImportSources.detect(file, fixture(file))?.id, id, reason: file);
      expect(ImportSources.parse(file, fixture(file)).rows, isNotEmpty);
    }
  });

  test('OFX content is found even without the extension', () {
    expect(
      ImportSources.detect('download', fixture('bank_sgml.ofx'))?.id,
      'ofx',
    );
  });

  test('unknown files are one error', () {
    final result = ImportSources.parse('notes.txt', 'just some text');
    expect(result.rows, isEmpty);
    expect(result.errors, hasLength(1));
    expect(ImportSources.detect('book.xlsx', 'Date,Amount'), isNull);
    expect(ImportSources.byId('csv.ynab'), CsvPresets.ynab);
  });
}
