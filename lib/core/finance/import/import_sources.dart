import 'import_source.dart';
import 'ofx_source.dart';
import 'presets.dart';
import 'qif_source.dart';

export 'import_source.dart';
export 'presets.dart' show CsvPreset, CsvPresets;

/// Entry point for file imports: picks the source that reads a file and
/// parses it into [RawImportRow]s.
abstract final class ImportSources {
  static const ofx = OfxSource();
  static const qif = QifSource();

  static List<ImportSource> get all => [ofx, qif, ...CsvPresets.all];

  /// How much of the file [ImportSource.canRead] needs to see.
  static const headLength = 4096;

  /// OFX and QIF are recognised by name or content; anything else is tried
  /// against the CSV presets, most specific first. Null when nothing fits —
  /// the caller can then fall back to manual or AI column mapping.
  static ImportSource? detect(String fileName, String content) {
    final head = content.length > headLength
        ? content.substring(0, headLength)
        : content;
    if (ofx.canRead(fileName, head)) return ofx;
    if (qif.canRead(fileName, head)) return qif;
    if (RegExp(r'\.(xlsx?|pdf)$').hasMatch(fileName.toLowerCase())) {
      return null;
    }
    return CsvPresets.detect(content);
  }

  static ImportSource? byId(String id) =>
      all.where((s) => s.id == id).firstOrNull;

  /// [detect] then parse; an unrecognised file is one error, not a throw.
  static ImportParseResult parse(
    String fileName,
    String content, {
    ImportOptions options = const ImportOptions(),
  }) {
    final source = detect(fileName, content);
    if (source == null) {
      return const ImportParseResult(
        'unknown',
        [],
        errors: [ImportIssue(0, 'This file format is not recognised')],
      );
    }
    return source.parse(content, options: options);
  }
}
