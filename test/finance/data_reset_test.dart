import 'dart:io';

import 'package:drift/native.dart';
import 'package:flourish/core/detection/detection_bridge.dart';
import 'package:flourish/core/detection/detection_service.dart';
import 'package:flourish/core/detection/parsed_payment.dart';
import 'package:flourish/core/finance/data_reset_service.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/domain/finance/models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/inbox_ui_test.dart' show FakeBridge;

void main() {
  late AppDatabase db;
  late Directory sandbox, docs, temp, outside;
  late FakeBridge bridge;
  const storage = FlutterSecureStorage();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'default_currency': 'EGP',
      'monthly_income_amount': 9000.0,
      'detection_backup_raw_text': true,
      'ai_enabled': true,
      'ai_auto_consent_host': 'api.deepseek.com',
      'ai_base_url': 'https://api.deepseek.com',
      'app_lock_enabled': true,
      'app_locale': 'ar',
      'detection_enabled': true,
    });
    await PreferencesService.init();
    FlutterSecureStorage.setMockInitialValues({
      'ai_api_key': 'sk-test',
      'alpha_vantage_key': 'av-test',
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sandbox = await Directory.systemTemp.createTemp('flourish-reset');
    docs = await Directory(p.join(sandbox.path, 'app_flutter')).create();
    temp = await Directory(p.join(sandbox.path, 'cache')).create();
    outside = await Directory(p.join(sandbox.path, 'Download')).create();
    bridge = FakeBridge()
      ..queue.add(
        QueuedMessage(
          'q1',
          RawMessage(
            text: 'Card ending 1234 was charged EGP 99.00 at Talabat',
            receivedAt: DateTime(2026, 10, 1),
            source: 'android_notification',
          ),
        ),
      );
  });

  tearDown(() async {
    await db.close();
    await sandbox.delete(recursive: true);
  });

  File file(Directory dir, String name, [String text = 'x']) =>
      File(p.join(dir.path, name))..writeAsStringSync(text);

  test('reset removes app-managed data and keeps unrelated files', () async {
    final ledger = FinancialLedgerService(db);
    final account = (await db.getAllAccounts()).first;
    final category = (await db.getAllCategories()).firstWhere(
      (c) => c.type == 'expense',
    );
    await ledger.recordCash(
      accountId: account.id,
      amount: Amount('120'),
      type: 'expense',
      categoryId: category.id,
      note: 'Rent share',
      date: DateTime(2026, 10, 2),
    );
    final detected = await DetectionService(ledger).ingest(
      RawMessage(
        text: 'Card ending 1234 was charged EGP 250.00 at Talabat',
        receivedAt: DateTime(2026, 10, 3),
        source: 'android_notification',
      ),
    );
    expect(detected, isNotNull);

    final receipt = file(docs, 'receipt-1.jpg');
    final pending = file(docs, 'receipt-pending.jpg');
    final orphan = file(docs, 'receipt-orphan.jpg');
    final backups = await Directory(p.join(docs.path, 'backups')).create();
    final autoBackup = file(
      backups,
      'flourish-2026-10-03.json',
      '{"tables":{}}',
    );
    final unrelated = file(docs, 'notes.txt');
    final userExport = file(outside, 'flourish-backup.encrypted.json');
    final tempExport = file(temp, 'flourish_backup.json');
    final sharedImage = file(temp, 'shared-1.jpg');
    final picked = await Directory(p.join(temp.path, 'file_picker')).create();
    final pickedStatement = file(picked, 'statement.pdf');
    final otherCache = file(temp, 'image_cache.bin');
    await ledger.store.put('attachments', 'a1', {
      'id': 'a1',
      'path': receipt.path,
    });
    // A path outside the app's directory is never deleted.
    await ledger.store.put('attachments', 'a2', {
      'id': 'a2',
      'path': userExport.path,
    });
    await ledger.store.put(DetectionService.receiptCollection, '1', {
      'path': pending.path,
    });
    await ledger.store.put('aiCache', 'k', {'result': {}});

    // Screens watch tables through Drift; they must see the reset.
    final watched = <int>[];
    final watch = db
        .select(db.detectedPayments)
        .watch()
        .listen((rows) => watched.add(rows.length));
    await pumpEventQueue();
    expect(watched.last, 1);

    await DataResetService(
      db,
      secureStorage: storage,
      bridge: bridge,
      documents: () async => docs,
      temporary: () async => temp,
    ).reset();
    await pumpEventQueue();
    expect(watched.last, 0);
    await watch.cancel();

    Future<int> count(String table) async =>
        (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
            .read<int>('n');
    for (final table in [
      'transactions',
      'accounts',
      'categories',
      'budgets',
      'goals',
      'recurring_transactions',
      'payment_instruments',
      'detected_payments',
      'finance_records',
      'exact_balances',
      'transaction_details',
    ]) {
      expect(await count(table), 0, reason: table);
    }
    final searchable = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM search_documents WHERE kind<>'feature'",
        )
        .getSingle();
    expect(searchable.read<int>('n'), 0);

    for (final gone in [
      receipt,
      pending,
      orphan,
      autoBackup,
      tempExport,
      sharedImage,
      pickedStatement,
    ]) {
      expect(gone.existsSync(), isFalse, reason: gone.path);
    }
    expect(backups.existsSync(), isFalse);
    for (final kept in [unrelated, userExport, otherCache]) {
      expect(kept.existsSync(), isTrue, reason: kept.path);
    }

    expect(bridge.queue, isEmpty);
    expect(bridge.acked, ['q1']);
    expect(await storage.readAll(), isEmpty);

    final prefs = PreferencesService.prefs;
    for (final key in [
      'default_currency',
      'monthly_income_amount',
      'detection_backup_raw_text',
      'ai_enabled',
      'ai_auto_consent_host',
      'ai_base_url',
    ]) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    for (final key in ['app_lock_enabled', 'app_locale', 'detection_enabled']) {
      expect(prefs.containsKey(key), isTrue, reason: key);
    }
  });

  test('reset works without a native queue and on an empty install', () async {
    await DataResetService(
      db,
      secureStorage: storage,
      documents: () async => docs,
      temporary: () async => temp,
    ).reset();
    expect(await storage.readAll(), isEmpty);
  });

  test('a queue that cannot be reached does not stop the reset', () async {
    await DataResetService(
      db,
      secureStorage: storage,
      bridge: _BrokenBridge(),
      documents: () async => docs,
      temporary: () async => temp,
    ).reset();
    expect(await storage.readAll(), isEmpty);
  });
}

class _BrokenBridge extends FakeBridge {
  @override
  Future<List<QueuedMessage>> peek() async => throw StateError('no channel');
}
