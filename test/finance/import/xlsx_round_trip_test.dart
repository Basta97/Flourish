import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';

// Spreadsheet import reads .xlsx through excel_community (the excel fork on
// archive 4, which pdfrx also needs); this guards the cell values it returns.
void main() {
  test('xlsx written and read back', () {
    final book = Excel.createExcel();
    final sheet = book['Sheet1'];
    sheet.appendRow([TextCellValue('Date'), TextCellValue('Amount')]);
    sheet.appendRow([TextCellValue('2026-10-01'), DoubleCellValue(-12.5)]);
    final bytes = book.encode()!;

    final read = Excel.decodeBytes(bytes);
    final rows = read.tables['Sheet1']!.rows
        .map((r) => r.map((c) => c?.value?.toString() ?? '').toList())
        .toList();
    expect(rows, [
      ['Date', 'Amount'],
      ['2026-10-01', '-12.5'],
    ]);
  });
}
