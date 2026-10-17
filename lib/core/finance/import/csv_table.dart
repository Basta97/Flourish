import 'package:csv/csv.dart';

/// A decoded CSV/TSV file: every record as trimmed strings, with the
/// delimiter that was detected. BOMs and Excel's `sep=` hint line are
/// handled before decoding.
final class CsvTable {
  final List<List<String>> records;
  final String delimiter;

  /// Lines removed before decoding (the `sep=` hint), so record numbers can
  /// be reported as file lines.
  final int lineOffset;
  const CsvTable(this.records, this.delimiter, {this.lineOffset = 0});

  static const _candidates = [',', ';', '\t', '|'];

  factory CsvTable.decode(String content, {String? delimiter}) {
    var text = content.startsWith('﻿') ? content.substring(1) : content;
    final hint = RegExp(r'^sep=(.)\s*(\r\n|\r|\n)').firstMatch(text);
    if (hint != null) {
      delimiter ??= hint[1];
      text = text.substring(hint.end);
    }
    final chosen = delimiter ?? detectDelimiter(text);
    final decoded = Csv(
      fieldDelimiter: chosen,
      autoDetect: false,
      skipEmptyLines: false,
    ).decode(text);
    return CsvTable(
      [
        for (final r in decoded) [for (final v in r) '${v ?? ''}'.trim()],
      ],
      chosen,
      lineOffset: hint == null ? 0 : 1,
    );
  }

  /// The candidate seen most often outside quotes in the first lines.
  static String detectDelimiter(String text) {
    final lines = text
        .split(RegExp(r'\r\n|\r|\n'))
        .where((l) => l.trim().isNotEmpty)
        .take(10);
    final counts = {for (final c in _candidates) c: 0};
    for (final line in lines) {
      var quoted = false;
      for (var i = 0; i < line.length; i++) {
        final ch = line[i];
        if (ch == '"') quoted = !quoted;
        if (!quoted && counts.containsKey(ch)) counts[ch] = counts[ch]! + 1;
      }
    }
    final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    return best.value == 0 ? ',' : best.key;
  }
}

/// Header cell → comparable key: lower case, letters and digits only, so
/// `Income/Expense`, `income_expense` and ` INCOME EXPENSE ` all match.
String headerKey(String header) => header
    .replaceAll('﻿', '')
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

/// One data record read through its header.
final class CsvRecord {
  final List<String> cells;
  final Map<String, int> columns;

  /// 1-based record number in the file, header included.
  final int line;
  const CsvRecord(this.cells, this.columns, this.line);

  /// First non-empty value among the columns named [keys] (header keys).
  String? get(List<String> keys) {
    for (final key in keys) {
      final index = columns[key];
      if (index == null || index >= cells.length) continue;
      final value = cells[index].trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  bool has(List<String> keys) => keys.any(columns.containsKey);

  bool get isBlank => cells.every((c) => c.trim().isEmpty);
}

/// Header key → index, keeping the first of duplicated names.
Map<String, int> headerColumns(List<String> header) {
  final map = <String, int>{};
  for (var i = 0; i < header.length; i++) {
    final key = headerKey(header[i]);
    if (key.isNotEmpty) map.putIfAbsent(key, () => i);
  }
  return map;
}
