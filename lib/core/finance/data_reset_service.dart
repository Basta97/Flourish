import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/database/database.dart';
import '../../data/finance/finance_store.dart';
import '../../data/search/search_index.dart';
import '../detection/detection_bridge.dart';
import '../detection/detection_service.dart';
import '../services/preferences_service.dart';
import 'backup_service.dart';

/// "Reset all data": removes everything Flourish keeps about the person's
/// money on this device. Only files Flourish created inside its own
/// directories are deleted; exports already shared elsewhere stay.
///
/// Kept on purpose: app lock, language and whether alert reading is on,
/// which are device preferences rather than financial data.
class DataResetService {
  DataResetService(
    this.db, {
    required this.secureStorage,
    this.bridge,
    Future<Directory> Function()? documents,
    Future<Directory> Function()? temporary,
  }) : documents = documents ?? getApplicationDocumentsDirectory,
       temporary = temporary ?? getTemporaryDirectory;

  final AppDatabase db;
  final FlutterSecureStorage secureStorage;

  /// The native queue of captured alerts not yet read into the inbox.
  final DetectionBridge? bridge;
  final Future<Directory> Function() documents, temporary;

  /// Preference keys removed besides [BackupService.settings].
  static bool isFinancePreference(String key) =>
      key.startsWith('ai_') || BackupService.settings.contains(key);

  Future<void> reset() async {
    final docs = await documents();
    final receipts = await _receiptPaths();

    await db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction(() async {
        for (final table in BackupService.tableNames.reversed) {
          await db.customStatement('DELETE FROM $table');
        }
        await SearchIndex.rebuild(db);
      });
    } finally {
      await db.customStatement('PRAGMA foreign_keys = ON');
    }
    // Raw SQL bypasses Drift's change tracking; refresh watched queries.
    db.markTablesUpdated(db.allTables);
    // Deleted rows otherwise linger in free pages and the WAL file.
    for (final index in ['search_words', 'search_fragments']) {
      await db.customStatement("INSERT INTO $index($index) VALUES('optimize')");
    }
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await db.customStatement('VACUUM');

    for (final path in receipts) {
      await _deleteInside(docs, File(path));
    }
    if (await docs.exists()) {
      await for (final entry in docs.list()) {
        final name = p.basename(entry.path);
        if (entry is Directory && name == 'backups') {
          await entry.delete(recursive: true);
        } else if (entry is File && name.startsWith('receipt-')) {
          await entry.delete();
        }
      }
    }
    await _clearTemporary();
    await _clearQueue();

    await secureStorage.deleteAll();
    final prefs = PreferencesService.prefs;
    for (final key in prefs.getKeys().where(isFinancePreference).toList()) {
      await PreferencesService.remove(key);
    }
    db.notifyFinanceChanged();
  }

  Future<List<String>> _receiptPaths() async {
    final store = FinanceStore(db);
    return [
      for (final collection in [
        'attachments',
        DetectionService.receiptCollection,
      ])
        for (final row in await store.list(collection))
          if (row['path'] is String) row['path'] as String,
    ];
  }

  /// Copies Flourish made for sharing or reading: exports, shared images
  /// and files picked for import.
  Future<void> _clearTemporary() async {
    final dir = await temporary();
    if (!await dir.exists()) return;
    await for (final entry in dir.list()) {
      final name = p.basename(entry.path);
      if (entry is File &&
          (name.startsWith('flourish') || name.startsWith('shared-'))) {
        await entry.delete();
      } else if (entry is Directory && name == 'file_picker') {
        await entry.delete(recursive: true);
      }
    }
  }

  Future<void> _clearQueue() async {
    final queue = bridge;
    if (queue == null) return;
    try {
      for (var round = 0; round < 50; round++) {
        final batch = await queue.peek();
        if (batch.isEmpty) break;
        await queue.ack([for (final item in batch) item.id]);
      }
    } catch (e) {
      debugPrint('Detection queue not cleared: ${e.runtimeType}');
    }
  }

  static Future<void> _deleteInside(Directory root, File file) async {
    if (!p.isWithin(root.path, file.path)) return;
    if (await file.exists()) await file.delete();
  }
}
