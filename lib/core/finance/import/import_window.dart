import 'import_source.dart';

extension ImportWindow on ImportParseResult {
  /// Only the rows dated on or after [since]; the rest are counted in a
  /// warning so the review says what was left out.
  ImportParseResult since(
    DateTime since, {
    required String Function(int dropped) olderWarning,
  }) {
    final kept = rows.where((r) => !r.date.isBefore(since)).toList();
    final dropped = rows.length - kept.length;
    return ImportParseResult(
      sourceId,
      kept,
      errors: errors,
      warnings: [
        if (dropped > 0) ImportIssue(0, olderWarning(dropped)),
        ...warnings,
      ],
    );
  }
}
