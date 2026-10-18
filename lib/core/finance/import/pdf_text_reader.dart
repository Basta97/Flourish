import 'package:pdfrx/pdfrx.dart';

import 'pdf_statement.dart';

/// Reads the text layer of a PDF with pdfium (pdfrx), page by page, keeping
/// where each word sits so table columns can be told apart.
abstract final class PdfTextReader {
  /// [initialize] sets pdfium up; tests pass `pdfrxInitialize` (plain Dart)
  /// instead of the Flutter one. [password] is asked for when the file is
  /// encrypted, and may be asked again after a wrong one; returning null
  /// gives up.
  static Future<List<StatementPage>> read(
    String path, {
    Future<String?> Function()? password,
    Future<void> Function() initialize = pdfrxFlutterInitialize,
  }) async {
    await initialize();
    // Throws PdfPasswordException when the file is encrypted and no
    // working password was given.
    final doc = await PdfDocument.openFile(path, passwordProvider: password);
    try {
      return [
        for (final page in doc.pages)
          if (await page.loadText() case final raw?)
            StatementPage.fromChars(page.pageNumber, raw.fullText, [
              for (final r in raw.charRects) (left: r.left, right: r.right),
            ])
          else
            StatementPage(page.pageNumber, const []),
      ];
    } finally {
      await doc.dispose();
    }
  }
}
