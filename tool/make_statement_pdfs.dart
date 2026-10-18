// Writes the PDF statement fixtures in test/fixtures/imports/.
//
//   dart run tool/make_statement_pdfs.dart
//
// The PDFs are hand-built (Helvetica, uncompressed streams) so the fixtures
// stay small and reproducible without a PDF library.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

void main() {
  const dir = 'test/fixtures/imports';
  File(
    '$dir/statement_debit_credit.pdf',
  ).writeAsBytesSync(_pdf([_debitCreditPage1(), _debitCreditPage2()]));
  File('$dir/statement_scanned.pdf').writeAsBytesSync(
    _pdf([
      // Grey boxes where a scan would have its image: no text layer at all.
      '0.8 g 50 600 500 120 re f 50 400 500 120 re f',
    ]),
  );
  stdout.writeln(
    'Wrote $dir/statement_debit_credit.pdf, statement_scanned.pdf',
  );
}

const _size = 9.0;

/// Helvetica advance widths (1/1000 em) for the characters amounts use.
double _width(String text) {
  var units = 0;
  for (final c in text.split('')) {
    units += switch (c) {
      ',' || '.' => 278,
      '-' => 333,
      ' ' => 278,
      _ => 556,
    };
  }
  return units * _size / 1000;
}

String _escape(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

String _text(double x, double y, String s, {bool bold = false}) =>
    'BT /${bold ? 'F2' : 'F1'} $_size Tf $x $y Td (${_escape(s)}) Tj ET\n';

/// Right-aligned at [right], like the numeric columns of a real statement.
String _right(double right, double y, String s) =>
    _text(right - _width(s), y, s);

// Column right edges / left edges.
const _date = 50.0, _desc = 120.0, _debit = 400.0, _credit = 470.0;
const _balance = 545.0;

String _header(double y) =>
    _text(_date, y, 'Date', bold: true) +
    _text(_desc, y, 'Description', bold: true) +
    _text(_debit - 26, y, 'Debit', bold: true) +
    _text(_credit - 30, y, 'Credit', bold: true) +
    _text(_balance - 38, y, 'Balance', bold: true);

String _row(
  double y,
  String date,
  String desc, {
  String? debit,
  String? credit,
  required String balance,
}) =>
    _text(_date, y, date) +
    _text(_desc, y, desc) +
    (debit == null ? '' : _right(_debit, y, debit)) +
    (credit == null ? '' : _right(_credit, y, credit)) +
    _right(_balance, y, balance);

String _debitCreditPage1() {
  final b = StringBuffer()
    ..write(_text(_date, 780, 'Nile Commercial Bank', bold: true))
    ..write(_text(_date, 765, 'Account statement  Account no. 1002003004005'))
    ..write(_text(_date, 752, 'Customer: Sample Customer  sample@example.com'))
    ..write(_text(_date, 739, 'Period 01/10/2026 - 31/10/2026  Currency EGP'))
    ..write(_header(710))
    ..write(_row(694, '01/10/2026', 'Opening balance', balance: '10,000.00'))
    ..write(
      _row(
        678,
        '02/10/2026',
        'POS CARREFOUR MAADI',
        debit: '1,250.50',
        balance: '8,749.50',
      ),
    )
    ..write(
      _row(
        662,
        '05/10/2026',
        'SALARY OCTOBER',
        credit: '25,000.00',
        balance: '33,749.50',
      ),
    )
    ..write(
      _row(
        646,
        '07/10/2026',
        'ATM WITHDRAWAL',
        debit: '2,000.00',
        balance: '31,749.50',
      ),
    )
    // A description that wraps onto a second line.
    ..write(
      _row(
        630,
        '10/10/2026',
        'INSTAPAY TRANSFER',
        debit: '500.00',
        balance: '31,249.50',
      ),
    )
    ..write(_text(_desc, 619, 'TO MOSTAFA HASSAN'))
    ..write(_text(_date, 80, 'Page 1 of 2'));
  return b.toString();
}

String _debitCreditPage2() {
  final b = StringBuffer()
    ..write(_header(780))
    ..write(
      _row(
        764,
        '12/10/2026',
        'REFUND AMAZON.EG',
        credit: '349.99',
        balance: '31,599.49',
      ),
    )
    ..write(
      _row(
        748,
        '15/10/2026',
        'VODAFONE CASH BILL',
        debit: '120.00',
        balance: '31,479.49',
      ),
    )
    ..write(_text(_desc, 720, 'Closing balance'))
    ..write(_right(_balance, 720, '31,479.49'))
    ..write(_text(_date, 80, 'Page 2 of 2'));
  return b.toString();
}

/// A minimal PDF 1.4 file with one page per content stream.
List<int> _pdf(List<String> pages) {
  final objects = <String>[];
  final pageIds = <int>[];
  // 1 catalog, 2 pages, 3 Helvetica, 4 Helvetica-Bold, then page/content pairs.
  objects.add('<< /Type /Catalog /Pages 2 0 R >>');
  objects.add(''); // pages, filled in below
  objects.add(
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
    '/Encoding /WinAnsiEncoding >>',
  );
  objects.add(
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold '
    '/Encoding /WinAnsiEncoding >>',
  );
  for (final content in pages) {
    final pageId = objects.length + 1;
    pageIds.add(pageId);
    objects.add(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
      '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> '
      '/Contents ${pageId + 1} 0 R >>',
    );
    final bytes = latin1.encode(content);
    objects.add('<< /Length ${bytes.length} >>\nstream\n$content\nendstream');
  }
  objects[1] =
      '<< /Type /Pages /Kids [${pageIds.map((id) => '$id 0 R').join(' ')}] '
      '/Count ${pageIds.length} >>';

  final out = BytesBuilder()..add(latin1.encode('%PDF-1.4\n'));
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out.add(latin1.encode('${i + 1} 0 obj\n${objects[i]}\nendobj\n'));
  }
  final xref = out.length;
  final table = StringBuffer('xref\n0 ${objects.length + 1}\n')
    ..write('0000000000 65535 f \n');
  for (final o in offsets) {
    table.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  table.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  out.add(latin1.encode(table.toString()));
  return out.takeBytes();
}
