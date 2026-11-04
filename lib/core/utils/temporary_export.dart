import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Writes exported data to a private temporary folder for the share sheet
/// and removes it afterwards, so plaintext copies of finances never linger.
class TemporaryExport {
  TemporaryExport._();

  static const _folder = 'flourish-exports';

  static Future<Directory> _directory() async {
    final dir = Directory(
      path.join((await getTemporaryDirectory()).path, _folder),
    );
    return dir.create(recursive: true);
  }

  /// Writes [contents] as [name], hands it to [share], then deletes it.
  static Future<T> share<T>(
    String name,
    String contents,
    Future<T> Function(File file) share,
  ) async {
    final file = File(path.join((await _directory()).path, name));
    try {
      await file.writeAsString(contents, flush: true);
      return await share(file);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  /// Removes exports left behind by a crash or by older versions, which
  /// wrote straight into the temporary folder.
  static Future<void> sweep() async {
    try {
      final temp = await getTemporaryDirectory();
      final exports = Directory(path.join(temp.path, _folder));
      if (await exports.exists()) await exports.delete(recursive: true);
      await for (final entity in temp.list()) {
        final name = path.basename(entity.path);
        if (entity is! File) continue;
        // A shared image may be waiting to be read right after launch.
        final stale =
            name.startsWith('shared-') &&
            DateTime.now().difference(await entity.lastModified()) >
                const Duration(hours: 1);
        if (name.startsWith('flourish') || stale) await entity.delete();
      }
    } on FileSystemException {
      // Best effort: a locked file is retried on the next launch.
    }
  }
}

/// One CSV cell: quoted, and with a leading apostrophe on values a
/// spreadsheet would run as a formula (text from bank alerts can start
/// with =, +, - or @).
String csvCell(Object? value) {
  var text = (value ?? '').toString();
  if (value is String && text.isNotEmpty && '=+-@\t\r'.contains(text[0])) {
    text = "'$text";
  }
  return '"${text.replaceAll('"', '""')}"';
}
