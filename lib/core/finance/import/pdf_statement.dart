import '../../../domain/finance/amount.dart';
import 'import_source.dart';
import 'import_values.dart';

/// A run of characters with no gap, and where it sits on the page (PDF
/// points from the left edge).
final class StatementWord {
  const StatementWord(this.text, this.left, this.right);
  final String text;
  final double left, right;
  double get center => (left + right) / 2;
  @override
  String toString() => text;
}

/// One printed line of a page, words left to right.
final class StatementLine {
  const StatementLine(this.words);
  final List<StatementWord> words;
  String get text => words.map((w) => w.text).join(' ');
  @override
  String toString() => text;
}

/// The text layer of one PDF page.
final class StatementPage {
  const StatementPage(this.number, this.lines);

  /// 1-based page number.
  final int number;
  final List<StatementLine> lines;

  String get text => lines.map((l) => l.text).join('\n');

  /// Builds lines and words from a page's raw text and one horizontal box
  /// per character, as PDF text extractors report them. Line breaks in
  /// [fullText] end a line; whitespace or a gap wider than about a space
  /// ends a word.
  factory StatementPage.fromChars(
    int number,
    String fullText,
    List<({double left, double right})> boxes,
  ) {
    final lines = <StatementLine>[];
    var words = <StatementWord>[];
    final word = StringBuffer();
    double? left, right;

    void endWord() {
      if (word.isNotEmpty && left != null) {
        words.add(StatementWord(word.toString(), left!, right!));
      }
      word.clear();
      left = right = null;
    }

    void endLine() {
      endWord();
      if (words.isNotEmpty) lines.add(StatementLine(words));
      words = [];
    }

    // Glyph boxes of narrow characters (`1`, `,`, `i`) leave gaps of their
    // own, so a column gap is measured against the page's average glyph.
    var total = 0.0, count = 0;
    for (var i = 0; i < fullText.length && i < boxes.length; i++) {
      final w = boxes[i].right - boxes[i].left;
      if (w > 0 && fullText[i].trim().isNotEmpty) {
        total += w;
        count++;
      }
    }
    final gap = (count == 0 ? 5.0 : total / count) * 1.5;

    for (var i = 0; i < fullText.length; i++) {
      final c = fullText[i];
      if (c == '\n') {
        endLine();
        continue;
      }
      if (c.trim().isEmpty || i >= boxes.length) {
        endWord();
        continue;
      }
      final box = boxes[i];
      // A jump of more than ~1.5 characters with no space in the text is a
      // column gap the extractor did not mark.
      if (right != null && box.left - right! > gap) endWord();
      word.write(c);
      left ??= box.left;
      right = right == null || box.right > right! ? box.right : right;
    }
    endLine();
    return StatementPage(number, lines);
  }
}

/// Reads bank statements from the text layer of a PDF: a table with a date,
/// a description and either debit/credit columns or one signed amount
/// column. Columns are told apart by where the header words sit on the
/// page; without a header the running balance decides the direction.
abstract final class PdfStatementParser {
  static const sourceId = 'pdf';

  /// Fewer visible characters than this on every page means the PDF is a
  /// scan (images only).
  static const _minTextPerPage = 20;

  static bool hasTextLayer(List<StatementPage> pages) => pages.any(
    (p) => p.text.replaceAll(RegExp(r'\s'), '').length >= _minTextPerPage,
  );

  static final _amount = RegExp(
    r"^[(\-−+]?(?:\d{1,3}(?:[,.\u00A0\u202F’']\d{3})+|\d+)[.,]\d{2,3}[)\-]?$",
  );
  static final _marker = RegExp(r'^(?:CR|DR)\.?$', caseSensitive: false);
  static final _dateStart = RegExp(
    r'^(?:\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}|\d{4}[/.\-]\d{1,2}[/.\-]\d{1,2}'
    r'|\d{1,2}[\-/ ]?[A-Za-z]{3,9}\.?[\-/ ]?\d{2,4})$',
  );

  static const _columns = {
    'date': [
      'date',
      'posting date',
      'transaction date',
      'trans date',
      'value date',
      'التاريخ',
      'تاريخ',
      'تاريخ العملية',
      'تاريخ القيد',
    ],
    'debit': [
      'debit',
      'debits',
      'withdrawal',
      'withdrawals',
      'dr',
      'paid out',
      'money out',
      'مدين',
      'سحب',
      'مسحوبات',
      'خصم',
    ],
    'credit': [
      'credit',
      'credits',
      'deposit',
      'deposits',
      'cr',
      'paid in',
      'money in',
      'دائن',
      'إيداع',
      'ايداع',
      'إيداعات',
      'ايداعات',
    ],
    'amount': ['amount', 'transaction amount', 'المبلغ', 'القيمة'],
    'balance': ['balance', 'running balance', 'الرصيد'],
  };

  static final _skip = RegExp(
    r'opening balance|closing balance|balance brought|brought forward|'
    r'carried forward|balance b/?f|balance c/?f|^total|رصيد افتتاحي|'
    r'رصيد اول|رصيد أول|الرصيد السابق|رصيد ختامي|الرصيد الختامي|إجمالي|اجمالي',
    caseSensitive: false,
  );
  static final _footer = RegExp(
    r'page \d|^\d+ of \d+$|statement|balance|total|صفحة|كشف',
    caseSensitive: false,
  );

  static String _key(String word) => word
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}/ ]', unicode: true), '')
      .trim();

  /// Column name → horizontal centre of its header word, for a line that
  /// names a date column and at least one money column.
  static Map<String, StatementWord>? _header(StatementLine line) {
    final found = <String, StatementWord>{};
    final words = line.words;
    for (var i = 0; i < words.length; i++) {
      for (final span in [3, 2, 1]) {
        if (i + span > words.length) continue;
        final key = _key(words.sublist(i, i + span).join(' '));
        final column = _columns.entries
            .where((c) => c.value.contains(key))
            .firstOrNull
            ?.key;
        if (column == null) continue;
        found.putIfAbsent(
          column,
          () => StatementWord(key, words[i].left, words[i + span - 1].right),
        );
        i += span - 1;
        break;
      }
    }
    final money = found.keys.where((k) => k != 'date' && k != 'balance');
    return found.containsKey('date') && money.isNotEmpty ? found : null;
  }

  /// The header column an amount printed at [word] belongs to. Numbers are
  /// usually right-aligned under their heading, so both centres and right
  /// edges are compared.
  static String? _columnOf(
    StatementWord word,
    Map<String, StatementWord> header,
  ) {
    String? best;
    var bestDistance = double.infinity;
    for (final MapEntry(:key, :value) in header.entries) {
      if (key == 'date') continue;
      final d = [
        (word.center - value.center).abs(),
        (word.right - value.right).abs(),
      ].reduce((a, b) => a < b ? a : b);
      if (d < bestDistance) {
        bestDistance = d;
        best = key;
      }
    }
    return best;
  }

  /// Words at the start of [line] that form a date, or 0.
  static int _dateWords(StatementLine line) {
    final w = line.words;
    if (w.isEmpty) return 0;
    if (_dateStart.hasMatch(w[0].text)) return 1;
    if (w.length >= 3 &&
        RegExp(r'^\d{1,2}$').hasMatch(w[0].text) &&
        RegExp(r'^[A-Za-z]{3,9}\.?,?$').hasMatch(w[1].text) &&
        RegExp(r'^\d{2,4}$').hasMatch(w[2].text)) {
      return 3;
    }
    return 0;
  }

  /// The statement's currency: a labelled `Currency: EGP`, else the code
  /// printed most often, else [fallback].
  static String? currency(String text, String? fallback) {
    final labelled = RegExp(
      r'(?:currency|ccy|العملة)\s*[:\-]?\s*([A-Z]{3})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (labelled != null) return labelled[1]!.toUpperCase();
    const common = ['EGP', 'USD', 'EUR', 'GBP', 'SAR', 'AED', 'KWD', 'QAR'];
    final counts = {
      for (final c in common) c: RegExp('\\b$c\\b').allMatches(text).length,
    }..removeWhere((_, n) => n == 0);
    if (counts.isNotEmpty) {
      return (counts.entries.toList()..sort((a, b) => b.value - a.value))
          .first
          .key;
    }
    if (RegExp(r'ج\.م|جنيه').hasMatch(text)) return 'EGP';
    return fallback;
  }

  /// A stable name for the statement's account: the last four digits of
  /// the account or card number in the page header, so a statement each
  /// month lands in the same account mapping.
  static String accountLabel(List<StatementPage> pages) {
    final head = pages.isEmpty
        ? ''
        : pages.first.lines.take(15).map((l) => l.text).join('\n');
    final m = RegExp(
      r'(?:account|acct|a/c|card|iban|رقم الحساب|الحساب|البطاقة)[^\d\n]{0,24}'
      r'([A-Z]{0,4}\d[\d\- ]{4,}\d)',
      caseSensitive: false,
    ).firstMatch(head);
    if (m == null) return 'PDF statement';
    final digits = m[1]!.replaceAll(RegExp(r'\D'), '');
    return 'Account …${digits.substring(digits.length - 4)}';
  }

  /// Every number printed on [page] that could be an amount, unsigned.
  /// Used to check that an AI reading only reports amounts that are
  /// really there.
  static Set<Amount> amountsOn(StatementPage page) {
    final text = ImportValues.westernDigits(page.text);
    final tokens = RegExp(
      r"\d(?:[\d,.\u00A0\u202F’']*\d)?",
    ).allMatches(text).map((m) => m[0]!).toList();
    final decimal = ImportValues.detectDecimalSeparator(
      tokens.where((t) => _amount.hasMatch(t)),
    );
    final out = <Amount>{};
    for (final t in tokens) {
      try {
        final value = ImportValues.amount(t, decimalSeparator: decimal).abs;
        if (value > Amount.zero) out.add(value);
      } on FormatException {
        // Not a number after all.
      }
    }
    return out;
  }

  static ImportParseResult parse(
    List<StatementPage> pages, {
    ImportOptions options = const ImportOptions(),
  }) {
    pages = [
      for (final p in pages)
        StatementPage(p.number, [
          for (final l in p.lines)
            StatementLine([
              for (final w in l.words)
                StatementWord(
                  ImportValues.westernDigits(w.text),
                  w.left,
                  w.right,
                ),
            ]),
        ]),
    ];
    final rows = <RawImportRow>[];
    final errors = <ImportIssue>[];
    final warnings = <ImportIssue>[];
    final allText = pages.map((p) => p.text).join('\n');
    final currency = PdfStatementParser.currency(
      allText,
      options.defaultCurrency,
    );
    final account = options.defaultAccount ?? accountLabel(pages);

    // Settle number and date conventions from the whole file first.
    final amounts = <String>[], dates = <String>[];
    for (final p in pages) {
      for (final l in p.lines) {
        final n = _dateWords(l);
        if (n > 0) dates.add(l.words.take(n).join(' '));
        amounts.addAll(
          l.words.map((w) => w.text).where((t) => _amount.hasMatch(t)),
        );
      }
    }
    final decimal =
        options.decimalSeparator ??
        ImportValues.detectDecimalSeparator(amounts);
    final order = options.dateOrder ?? ImportValues.detectDateOrder(dates);

    Map<String, StatementWord>? header;
    Amount? balance;
    var lineNo = 0;
    var skipped = 0;
    var corrected = 0;

    for (final page in pages) {
      // The last row on this page, and where its description starts, so a
      // wrapped description can be joined back on.
      int? lastRow;
      double? lastDescLeft;
      var wrapped = 0;

      for (final line in page.lines) {
        lineNo++;
        final found = _header(line);
        if (found != null && !line.words.any((w) => _amount.hasMatch(w.text))) {
          header = found;
          lastRow = null;
          continue;
        }
        final dateWords = _dateWords(line);
        final money = <(StatementWord, String?)>[];
        for (var i = dateWords; i < line.words.length; i++) {
          final w = line.words[i];
          if (!_amount.hasMatch(w.text)) continue;
          final next = i + 1 < line.words.length ? line.words[i + 1] : null;
          money.add((
            w,
            next != null && _marker.hasMatch(next.text) ? next.text : null,
          ));
        }

        if (dateWords == 0 || money.isEmpty) {
          // A wrapped description: no date, no amount, starting under the
          // previous row's description.
          final row = lastRow;
          if (row != null &&
              dateWords == 0 &&
              money.isEmpty &&
              wrapped < 2 &&
              lastDescLeft != null &&
              (line.words.first.left - lastDescLeft).abs() < 12 &&
              !_footer.hasMatch(line.text)) {
            final r = rows[row];
            rows[row] = r.copyWith(
              payee: '${r.payee ?? ''} ${line.text}'.trim(),
            );
            wrapped++;
          } else {
            lastRow = null;
          }
          continue;
        }
        lastRow = null;

        // Description: what sits between the date and the first amount,
        // minus a second (value) date, markers and currency codes.
        final firstMoney = line.words.indexOf(money.first.$1);
        final descWords = [
          for (final w in line.words.sublist(dateWords, firstMoney))
            if (!_dateStart.hasMatch(w.text) &&
                !_marker.hasMatch(w.text) &&
                w.text != currency)
              w,
        ];
        final description = descWords.join(' ').trim();

        Amount read(StatementWord w, String? marker) => ImportValues.amount(
          marker == null ? w.text : '${w.text} $marker',
          decimalSeparator: decimal,
        );

        try {
          final date = ImportValues.date(
            line.words.take(dateWords).join(' '),
            pattern: options.dateFormat,
            order: order,
          );

          Amount? signed;
          Amount? rowBalance;
          if (header != null) {
            Amount? debit, credit;
            for (final (w, marker) in money) {
              switch (_columnOf(w, header)) {
                case 'debit':
                  debit = read(w, null).abs;
                case 'credit':
                  credit = read(w, null).abs;
                case 'amount':
                  signed = read(w, marker);
                case 'balance':
                  rowBalance = read(w, marker);
              }
            }
            if (debit != null || credit != null) {
              signed = (credit ?? Amount.zero) - (debit ?? Amount.zero);
            }
          } else {
            // No header: the first amount is the transaction and a second
            // one is the running balance.
            if (money.length > 1 || _skip.hasMatch(description)) {
              rowBalance = read(money.last.$1, money.last.$2);
            }
            if (money.length > 1 || !_skip.hasMatch(description)) {
              signed = read(money.first.$1, money.first.$2);
            }
          }

          // The running balance is the most reliable direction there is:
          // when it moved by exactly this amount, follow it.
          final previous = balance;
          if (rowBalance != null) balance = rowBalance;
          if (_skip.hasMatch(description) ||
              (signed == null && rowBalance != null)) {
            skipped++;
            continue;
          }
          if (signed == null || signed == Amount.zero) continue;
          if (previous != null && rowBalance != null) {
            final delta = rowBalance - previous;
            if (delta.abs == signed.abs && delta != signed) {
              signed = delta;
              corrected++;
            }
          }

          rows.add(
            RawImportRow(
              date: date,
              amount: signed.abs,
              type: signed < Amount.zero ? 'expense' : 'income',
              account: account,
              payee: description.isEmpty ? null : description,
              currency: currency,
              sourceLine: lineNo,
            ),
          );
          lastRow = rows.length - 1;
          lastDescLeft = descWords.isEmpty ? null : descWords.first.left;
          wrapped = 0;
        } on FormatException catch (e) {
          errors.add(ImportIssue(lineNo, 'Page ${page.number}: ${e.message}'));
        }
      }
    }

    if (skipped > 0) {
      warnings.add(
        ImportIssue(
          0,
          'Skipped $skipped opening, closing or total balance lines',
        ),
      );
    }
    if (corrected > 0) {
      warnings.add(
        ImportIssue(
          0,
          '$corrected rows took their direction from the running balance',
        ),
      );
    }
    return ImportParseResult(
      sourceId,
      rows,
      errors: errors,
      warnings: warnings,
    );
  }
}
