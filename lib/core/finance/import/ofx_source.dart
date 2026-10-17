import '../../../domain/finance/amount.dart';
import 'import_source.dart';
import 'import_values.dart';

/// OFX/QFX bank and credit-card statements, both OFX 1.x SGML (leaf tags
/// left unclosed) and OFX 2.x XML. Every STMTRS/CCSTMTRS in the file is
/// read, so multi-account downloads import in one go.
final class OfxSource implements ImportSource {
  const OfxSource();

  @override
  String get id => 'ofx';
  @override
  String get name => 'OFX / QFX statement';

  @override
  bool canRead(String fileName, String headOfFile) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.ofx') || lower.endsWith('.qfx')) return true;
    final head = headOfFile.toUpperCase();
    return head.contains('OFXHEADER') || head.contains('<OFX>');
  }

  @override
  ImportParseResult parse(
    String content, {
    ImportOptions options = const ImportOptions(),
  }) {
    final rows = <RawImportRow>[];
    final errors = <ImportIssue>[], warnings = <ImportIssue>[];
    final root = _OfxNode.parse(content);
    if (root == null) {
      return ImportParseResult(
        id,
        rows,
        errors: [
          const ImportIssue(0, 'No <OFX> block found; is this an OFX file?'),
        ],
      );
    }
    final newlines = [for (final m in '\n'.allMatches(content)) m.start];
    int lineOf(int offset) {
      var low = 0, high = newlines.length;
      while (low < high) {
        final mid = (low + high) >> 1;
        newlines[mid] < offset ? low = mid + 1 : high = mid;
      }
      return low + 1;
    }

    final statements = [...root.findAll('STMTRS'), ...root.findAll('CCSTMTRS')];
    if (statements.isEmpty) {
      warnings.add(const ImportIssue(0, 'The file holds no bank statements'));
    }
    for (final statement in statements) {
      final from =
          statement.child('BANKACCTFROM') ?? statement.child('CCACCTFROM');
      final account =
          ImportValues.text(from?.value('ACCTID')) ?? options.defaultAccount;
      final statementCurrency =
          ImportValues.currency(statement.value('CURDEF')) ??
          options.defaultCurrency;
      final list = statement.child('BANKTRANLIST');
      for (final trn in list?.children('STMTTRN') ?? const <_OfxNode>[]) {
        final line = lineOf(trn.offset);
        try {
          final posted = trn.value('DTPOSTED') ?? trn.value('DTUSER');
          if (posted == null) throw const FormatException('Missing DTPOSTED');
          final rawAmount = trn.value('TRNAMT');
          if (rawAmount == null) throw const FormatException('Missing TRNAMT');
          final signed = ImportValues.amount(
            rawAmount,
            decimalSeparator: options.decimalSeparator,
          );
          if (signed == Amount.zero) {
            warnings.add(ImportIssue(line, 'Skipped a zero-amount entry'));
            continue;
          }
          final fitId = ImportValues.text(trn.value('FITID'));
          if (fitId == null) {
            warnings.add(ImportIssue(line, 'Entry has no FITID'));
          }
          // CURRENCY means TRNAMT itself is in another currency; ORIGCURRENCY
          // only records what it was converted from.
          final currency =
              ImportValues.currency(trn.child('CURRENCY')?.value('CURSYM')) ??
              statementCurrency;
          final payee =
              ImportValues.text(trn.value('NAME')) ??
              ImportValues.text(trn.child('PAYEE')?.value('NAME'));
          rows.add(
            RawImportRow(
              date: parseDate(posted),
              amount: signed.abs,
              type: signed < Amount.zero ? 'expense' : 'income',
              account: account,
              payee: payee,
              note: ImportValues.text(trn.value('MEMO')),
              currency: currency,
              externalId: fitId,
              sourceLine: line,
            ),
          );
        } on FormatException catch (e) {
          errors.add(ImportIssue(line, e.message));
        }
      }
    }
    return ImportParseResult(id, rows, errors: errors, warnings: warnings);
  }

  /// `YYYYMMDD[HHMMSS[.XXX]][[±H[.MM]][:TZ]]`. The time zone is dropped so
  /// the statement's calendar day is kept as written.
  static DateTime parseDate(String raw) {
    final m = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(?:(\d{2})(\d{2})(\d{2})?)?',
    ).firstMatch(raw.trim());
    if (m == null) throw FormatException('Invalid OFX date "$raw"');
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    final date = DateTime(
      y,
      mo,
      d,
      int.parse(m[4] ?? '0'),
      int.parse(m[5] ?? '0'),
      int.parse(m[6] ?? '0'),
    );
    if (date.month != mo || date.day != d) {
      throw FormatException('Invalid OFX date "$raw"');
    }
    return date;
  }
}

/// Minimal OFX element tree. SGML leaves (`<NAME>text` with no close tag)
/// and XML leaves (`<NAME>text</NAME>`) both become nodes with [text];
/// aggregates close on their end tag, which also closes any SGML aggregate
/// left open inside them.
final class _OfxNode {
  final String tag;
  final int offset;
  String? text;
  final List<_OfxNode> _children = [];
  _OfxNode(this.tag, this.offset);

  static final _token = RegExp(r'<(/?)([A-Za-z0-9_.]+)\s*(/?)>([^<]*)');

  static _OfxNode? parse(String content) {
    final start = content.toUpperCase().indexOf('<OFX>');
    if (start < 0) return null;
    final root = _OfxNode('#root', start);
    final stack = [root];
    for (final m in _token.allMatches(content, start)) {
      final closing = m[1] == '/', selfClosing = m[3] == '/';
      final tag = m[2]!.toUpperCase();
      final body = _decode(m[4]!.trim());
      if (closing) {
        final index = stack.lastIndexWhere((n) => n.tag == tag);
        // A close tag for an SGML leaf that was never pushed is ignored.
        if (index > 0) stack.removeRange(index, stack.length);
        continue;
      }
      final node = _OfxNode(tag, m.start);
      stack.last._children.add(node);
      if (selfClosing) {
        node.text = '';
      } else if (body.isNotEmpty) {
        node.text = body;
      } else {
        stack.add(node);
      }
    }
    return root;
  }

  static String _decode(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAllMapped(
        RegExp(r'&#(x[0-9a-fA-F]+|\d+);'),
        (m) => String.fromCharCode(
          m[1]!.startsWith('x')
              ? int.parse(m[1]!.substring(1), radix: 16)
              : int.parse(m[1]!),
        ),
      )
      .replaceAll('&amp;', '&');

  _OfxNode? child(String tag) =>
      _children.where((n) => n.tag == tag).firstOrNull;
  Iterable<_OfxNode> children(String tag) =>
      _children.where((n) => n.tag == tag);
  String? value(String tag) => child(tag)?.text;

  Iterable<_OfxNode> findAll(String tag) sync* {
    for (final c in _children) {
      if (c.tag == tag) yield c;
      yield* c.findAll(tag);
    }
  }
}
