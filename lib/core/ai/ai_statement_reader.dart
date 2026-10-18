import 'dart:convert';

import '../../domain/finance/amount.dart';
import '../finance/import/import_source.dart';
import '../finance/import/import_values.dart';
import '../finance/import/pdf_statement.dart';
import 'ai_client.dart';
import 'ai_payment_assist.dart' show AiUsageTracker;
import 'prompts.dart';
import 'redactor.dart';

/// Reads a PDF statement's transactions with the AI when the local table
/// heuristic found none (unusual layouts, Arabic statements whose columns
/// come out of order). Each page is sent on its own, masked first, and a
/// row is kept only when its amount is printed on that page.
class AiStatementReader {
  AiStatementReader(this.client, {this.usage, this.maxChunkChars = 6000});
  final AiClient client;
  final AiUsageTracker? usage;

  /// Pages longer than this are sent in several parts, split between lines.
  final int maxChunkChars;

  static const sourceId = 'pdf.ai';

  /// Lines that name the customer rather than a transaction; they are not
  /// needed to read the table, so they never leave the device.
  static final _personal = RegExp(
    r'^\s*(?:customer|client|name|account holder|address|mr\.?|mrs\.?|ms\.?|'
    r'العميل|اسم العميل|الاسم|العنوان|السيد|السيدة)(?=[\s:\-]|$)',
    caseSensitive: false,
  );

  /// The text of [page] as it is sent: personal lines dropped, then masked.
  static List<String> chunks(StatementPage page, {int maxChars = 6000}) {
    final out = <String>[];
    final current = StringBuffer();
    for (final line in page.lines) {
      final text = line.text;
      if (_personal.hasMatch(text)) continue;
      if (current.isNotEmpty && current.length + text.length + 1 > maxChars) {
        out.add(current.toString());
        current.clear();
      }
      if (current.isNotEmpty) current.write('\n');
      current.write(Redactor.redact(text));
    }
    if (current.isNotEmpty) out.add(current.toString());
    return out;
  }

  /// Number of requests [read] will make.
  int requestCount(List<StatementPage> pages) => pages
      .map((p) => chunks(p, maxChars: maxChunkChars).length)
      .fold(0, (a, b) => a + b);

  Future<ImportParseResult> read(
    List<StatementPage> pages, {
    ImportOptions options = const ImportOptions(),
    void Function(int done, int total)? onProgress,
  }) async {
    final rows = <RawImportRow>[];
    final warnings = <ImportIssue>[];
    final account =
        options.defaultAccount ?? PdfStatementParser.accountLabel(pages);
    final currency = PdfStatementParser.currency(
      pages.map((p) => p.text).join('\n'),
      options.defaultCurrency,
    );
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final total = requestCount(pages);
    var done = 0, dropped = 0, failed = 0;
    Object? lastError;
    var line = 0;

    for (final page in pages) {
      final firstLine = line + 1;
      line += page.lines.length;
      final printed = PdfStatementParser.amountsOn(page);
      for (final chunk in chunks(page, maxChars: maxChunkChars)) {
        onProgress?.call(done, total);
        try {
          final reply = await client.completeJson(
            system: AiPrompts.statementSystem,
            user: jsonEncode({
              'today': today,
              'page': page.number,
              'currency': currency,
              'text': chunk,
            }),
            // A full page of rows is a long reply.
            timeout: const Duration(seconds: 60),
          );
          await usage?.record(reply.usage);
          final list = reply.json['transactions'] ?? reply.json['results'];
          for (final t in list is List ? list : const []) {
            final row = _row(t, printed, account, currency, firstLine);
            if (row == null) {
              dropped++;
            } else {
              rows.add(row);
            }
          }
        } on AiException catch (e) {
          failed++;
          lastError = e;
          warnings.add(ImportIssue(0, 'Page ${page.number}: ${e.message}'));
        }
        done++;
      }
    }
    onProgress?.call(done, total);
    if (rows.isEmpty && failed > 0 && failed == total) throw lastError!;
    if (dropped > 0) {
      warnings.add(
        ImportIssue(
          0,
          'Left out $dropped AI row${dropped == 1 ? '' : 's'} whose amount or '
          'date could not be found on the page',
        ),
      );
    }
    return ImportParseResult(sourceId, rows, warnings: warnings);
  }

  static RawImportRow? _row(
    Object? t,
    Set<Amount> printed,
    String account,
    String? currency,
    int line,
  ) {
    if (t is! Map) return null;
    try {
      final rawAmount = t['amount'];
      if (rawAmount is! String && rawAmount is! num) return null;
      final amount = ImportValues.amount(
        '$rawAmount',
        decimalSeparator: '.',
      ).abs;
      if (amount <= Amount.zero || !printed.contains(amount)) return null;
      final direction = t['direction'];
      if (direction != 'expense' && direction != 'income') return null;
      final date = ImportValues.date('${t['date']}', order: DateOrder.ymd);
      final description = ImportValues.text(t['description']?.toString());
      return RawImportRow(
        date: date,
        amount: amount,
        type: direction as String,
        account: account,
        payee: description,
        // The statement's own currency wins: rows abroad still post in the
        // account's currency, with the foreign price only in the text.
        currency: currency ?? ImportValues.currency(t['currency']?.toString()),
        sourceLine: line,
      );
    } on FormatException {
      return null;
    }
  }
}
