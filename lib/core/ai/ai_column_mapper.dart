import 'dart:convert';

import 'package:intl/intl.dart';

import 'ai_client.dart';
import 'ai_payment_assist.dart' show AiUsageTracker;
import 'prompts.dart';
import 'redactor.dart';

/// Column choices for a spreadsheet, as the manual mapping form uses them.
class AiColumnMapping {
  const AiColumnMapping({
    required this.columns,
    required this.signedAmounts,
    required this.decimalSeparator,
    this.dateFormat,
  });

  /// Flourish field → 0-based column index (absent fields are left out).
  final Map<String, int> columns;
  final bool signedAmounts;
  final String decimalSeparator;
  final String? dateFormat;
}

/// Asks the AI which column is which for a file no preset recognises. The
/// answer only pre-fills the mapping form; the person still confirms it.
class AiColumnMapper {
  AiColumnMapper(this.client, {this.usage});
  final AiClient client;
  final AiUsageTracker? usage;

  static const fields = [
    'date',
    'type',
    'account',
    'category',
    'amount',
    'currency',
    'note',
    'destination',
  ];

  Future<AiColumnMapping> map(
    List<String> header,
    List<List<String>> rows,
  ) async {
    final sample = [
      for (final row in rows.where((r) => r.any((v) => v.trim().isNotEmpty)).take(5))
        [for (final v in row) Redactor.redact(v)],
    ];
    final reply = await client.completeJson(
      system: AiPrompts.columnsSystem,
      user: jsonEncode({'header': header, 'sample': sample}),
    );
    await usage?.record(reply.usage);
    return parse(reply.json, header.length, sample);
  }

  /// Keeps only valid indexes and a date format that reads the sample.
  static AiColumnMapping parse(
    Map<String, dynamic> json,
    int width,
    List<List<String>> sample,
  ) {
    final raw = json['columns'];
    final columns = <String, int>{};
    if (raw is Map) {
      for (final field in fields) {
        final v = raw[field];
        if (v is int && v >= 0 && v < width && !columns.containsValue(v)) {
          columns[field] = v;
        }
      }
    }
    String? format = json['date_format'] is String
        ? (json['date_format'] as String).trim()
        : null;
    final dateColumn = columns['date'];
    if (format != null && dateColumn != null) {
      final values = [
        for (final row in sample)
          if (dateColumn < row.length && row[dateColumn].trim().isNotEmpty)
            row[dateColumn].trim(),
      ];
      try {
        final pattern = DateFormat(format);
        final readable = values.every((v) {
          if (RegExp(r'^\d{4}-').hasMatch(v)) return true;
          pattern.parseStrict(v);
          return true;
        });
        if (!readable) format = null;
      } on FormatException {
        format = null;
      } on ArgumentError {
        format = null;
      }
    }
    final decimal = json['decimal_separator'] == ',' ? ',' : '.';
    return AiColumnMapping(
      columns: columns,
      signedAmounts: json['signed_amounts'] == true,
      decimalSeparator: decimal,
      dateFormat: format,
    );
  }
}
