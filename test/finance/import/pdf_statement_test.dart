import 'dart:io';

import 'package:flourish/core/finance/import/import_source.dart';
import 'package:flourish/core/finance/import/pdf_statement.dart';
import 'package:flourish/core/finance/import/pdf_text_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show Pdfrx, pdfrxInitialize;

/// Lines of `(text, left)` words; each word is 5pt per character wide.
StatementPage page(int number, List<List<(String, double)>> lines) =>
    StatementPage(number, [
      for (final l in lines)
        StatementLine([
          for (final (t, x) in l) StatementWord(t, x, x + t.length * 5),
        ]),
    ]);

Future<List<StatementPage>> readFixture(String name) => PdfTextReader.read(
  'test/fixtures/imports/$name',
  initialize: () {
    // `flutter test` builds pdfium for the host under build/native_assets
    // but does not hand it to the test runner, and pdfrx then waits forever
    // instead of failing. Point pdfrx at the built library when present.
    Pdfrx.pdfiumModulePath ??= _hostPdfium();
    return pdfrxInitialize();
  },
);

String? _hostPdfium() {
  for (final path in const [
    'build/native_assets/macos/libpdfium.dylib',
    'build/native_assets/linux/libpdfium.so',
    'build/native_assets/windows/pdfium.dll',
  ]) {
    if (File(path).existsSync()) return File(path).absolute.path;
  }
  return null;
}

void main() {
  group('text PDF fixture (pdfium)', () {
    test('debit/credit columns across two pages', () async {
      final pages = await readFixture('statement_debit_credit.pdf');
      expect(pages, hasLength(2));
      expect(PdfStatementParser.hasTextLayer(pages), isTrue);

      final result = PdfStatementParser.parse(pages);
      expect(result.errors, isEmpty);
      expect(
        [
          for (final r in result.rows)
            '${r.date.toIso8601String().substring(0, 10)} ${r.type} '
                '${r.amount} ${r.currency} ${r.account} ${r.payee}',
        ],
        [
          '2026-10-02 expense 1250.5 EGP Account …4005 POS CARREFOUR MAADI',
          '2026-10-05 income 25000 EGP Account …4005 SALARY OCTOBER',
          '2026-10-07 expense 2000 EGP Account …4005 ATM WITHDRAWAL',
          '2026-10-10 expense 500 EGP Account …4005 '
              'INSTAPAY TRANSFER TO MOSTAFA HASSAN',
          '2026-10-12 income 349.99 EGP Account …4005 REFUND AMAZON.EG',
          '2026-10-15 expense 120 EGP Account …4005 VODAFONE CASH BILL',
        ],
      );
      expect(result.warnings.single.message, contains('Skipped 1'));
    });

    test('a scanned PDF has no text layer', () async {
      final pages = await readFixture('statement_scanned.pdf');
      expect(pages, hasLength(1));
      expect(PdfStatementParser.hasTextLayer(pages), isFalse);
      expect(PdfStatementParser.parse(pages).rows, isEmpty);
    });
  });

  group('layouts', () {
    test('one signed amount column, month-name dates, CR/DR markers', () {
      final result = PdfStatementParser.parse([
        page(1, [
          [('Card', 40), ('no.', 70), ('4111-1111-1111-1234', 90)],
          [('Date', 40), ('Details', 110), ('Amount', 300), ('Balance', 400)],
          [
            ('03', 40),
            ('Oct', 52),
            ('2026', 70),
            ('UBER', 110),
            ('TRIP', 135),
            ('-85.00', 300),
            ('915.00', 400),
          ],
          [
            ('04', 40),
            ('Oct', 52),
            ('2026', 70),
            ('CASHBACK', 110),
            ('15.00', 300),
            ('CR', 330),
            ('930.00', 400),
          ],
          [
            ('05', 40),
            ('Oct', 52),
            ('2026', 70),
            ('NETFLIX', 110),
            ('(199.99)', 300),
            ('730.01', 400),
          ],
        ]),
      ], options: const ImportOptions(defaultCurrency: 'USD'));
      expect(result.errors, isEmpty);
      expect(
        [
          for (final r in result.rows)
            '${r.date.day} ${r.type} ${r.amount} ${r.payee}',
        ],
        [
          '3 expense 85 UBER TRIP',
          '4 income 15 CASHBACK',
          '5 expense 199.99 NETFLIX',
        ],
      );
      expect(result.rows.first.account, 'Account …1234');
      expect(result.rows.first.currency, 'USD');
    });

    test('no header: the running balance gives the direction', () {
      final result = PdfStatementParser.parse([
        page(1, [
          [
            ('2026-10-01', 40),
            ('Balance', 110),
            ('brought', 150),
            ('forward', 190),
            ('1.000,00', 400),
          ],
          [('2026-10-02', 40), ('Lidl', 110), ('45,20', 300), ('954,80', 400)],
          [
            ('2026-10-03', 40),
            ('Gehalt', 110),
            ('2.500,00', 300),
            ('3.454,80', 400),
          ],
        ]),
      ]);
      expect(
        [for (final r in result.rows) '${r.type} ${r.amount} ${r.payee}'],
        ['expense 45.2 Lidl', 'income 2500 Gehalt'],
      );
      expect(result.rows.first.account, 'PDF statement');
    });

    test('a balance that disagrees with the column wins', () {
      // The credit amount drifted under the Debit heading.
      final result = PdfStatementParser.parse([
        page(1, [
          [
            ('Date', 40),
            ('Description', 110),
            ('Debit', 300),
            ('Credit', 360),
            ('Balance', 430),
          ],
          [
            ('01/10/2026', 40),
            ('Opening', 110),
            ('balance', 150),
            ('100.00', 430),
          ],
          [
            ('02/10/2026', 40),
            ('Transfer', 110),
            ('in', 160),
            ('50.00', 305),
            ('150.00', 430),
          ],
        ]),
      ]);
      expect(result.rows.single.type, 'income');
      expect(
        result.warnings.map((w) => w.message),
        contains(contains('running balance')),
      );
    });

    test('Arabic-Indic digits', () {
      final result = PdfStatementParser.parse([
        page(1, [
          [('Date', 40), ('Description', 110), ('Debit', 300), ('Credit', 360)],
          [('١٥/١٠/٢٠٢٦', 40), ('فودافون', 110), ('٢٥٠٫٠٠', 300)],
        ]),
      ]);
      expect(result.rows.single.amount.toString(), '250');
      expect(result.rows.single.date, DateTime(2026, 10, 15));
    });
  });
}
