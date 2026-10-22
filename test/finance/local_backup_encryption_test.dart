import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/finance/backup_service.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

/// Secure storage that accepts writes but never keeps them.
class _ForgetfulStorage extends FlutterSecureStorage {
  const _ForgetfulStorage();
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  late Directory backups;
  late AppDatabase db;
  const secret = 'Retirement stash 7781';

  setUp(() async {
    SharedPreferences.setMockInitialValues({'default_currency': 'EGP'});
    await PreferencesService.init();
    FlutterSecureStorage.setMockInitialValues({});
    folder = await Directory.systemTemp.createTemp('flourish-local-backup');
    backups = Directory(p.join(folder.path, 'backups'));
    PathProviderPlatform.instance = _Paths(folder.path);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.insertAccount(
      AccountsCompanion.insert(
        name: secret,
        type: 'bank',
        currency: const Value('EGP'),
        color: 0,
        icon: 'account_balance',
      ),
    );
  });

  tearDown(() async {
    await db.close();
    await folder.delete(recursive: true);
  });

  List<File> files() =>
      backups.listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  Future<bool> hasAccount(String name) async =>
      (await db.getAllAccounts()).any((a) => a.name == name);

  test('daily backups are encrypted and restore on this device', () async {
    final service = BackupService(db);
    final file = await service.automaticBackup();
    final text = file.readAsStringSync();
    expect(jsonDecode(text)['format'], BackupService.localFormat);
    expect(text, isNot(contains(secret)));
    expect(text, isNot(contains('flourish-finance')));

    final account = (await db.getAllAccounts()).firstWhere(
      (a) => a.name == secret,
    );
    await (db.delete(db.accounts)..where((a) => a.id.equals(account.id))).go();
    expect(await hasAccount(secret), isFalse);

    final watched = <int>[];
    final watch = db
        .select(db.accounts)
        .watch()
        .listen((rows) => watched.add(rows.length));
    await pumpEventQueue();
    final before = watched.last;

    await service.restore(await service.openLocal(text));
    expect(await hasAccount(secret), isTrue);
    // Watching screens see the restored rows without a restart.
    await pumpEventQueue();
    expect(watched.last, before + 1);
    await watch.cancel();
  });

  test('plain backups from 1.1 are encrypted in place, not lost', () async {
    final service = BackupService(db);
    backups.createSync(recursive: true);
    final plain = jsonEncode(await service.exportData());
    final legacy = File(p.join(backups.path, 'flourish-2026-10-01.json'))
      ..writeAsStringSync(plain);
    // A plain temp file left by an interrupted 1.1 write.
    final stale = File(p.join(backups.path, 'flourish-2026-10-02.json.tmp'))
      ..writeAsStringSync(plain);

    // Before conversion the old file still opens.
    expect(
      (await service.openLocal(legacy.readAsStringSync()))['tables'],
      isA<Map>(),
    );

    await service.automaticBackup();
    expect(stale.existsSync(), isFalse);
    expect(legacy.existsSync(), isTrue);
    for (final f in files()) {
      final text = f.readAsStringSync();
      expect(text, isNot(contains(secret)), reason: f.path);
      expect(jsonDecode(text)['format'], BackupService.localFormat);
    }
    final reopened = await service.openLocal(legacy.readAsStringSync());
    expect(jsonEncode(reopened), plain);
  });

  test(
    'a backup is never written in plain text if the key cannot be kept',
    () async {
      final service = BackupService(db, keys: const _ForgetfulStorage());
      backups.createSync(recursive: true);
      final plain = jsonEncode(await service.exportData());
      final legacy = File(p.join(backups.path, 'flourish-2026-10-01.json'))
        ..writeAsStringSync(plain);

      await expectLater(service.automaticBackup(), throwsStateError);
      // The old file is left exactly as it was, and nothing new is written.
      expect(legacy.readAsStringSync(), plain);
      expect(files().map((f) => p.basename(f.path)), [
        'flourish-2026-10-01.json',
      ]);
    },
  );

  test('a damaged or foreign backup is refused, not restored', () async {
    final service = BackupService(db);
    final text = (await service.automaticBackup()).readAsStringSync();

    final j = jsonDecode(text) as Map<String, dynamic>;
    final cipher = base64Decode(j['cipher'] as String);
    cipher[0] ^= 0xFF;
    j['cipher'] = base64Encode(cipher);
    await expectLater(
      service.openLocal(jsonEncode(j)),
      throwsA(isA<FormatException>()),
    );

    // Another installation (or a reset) has a different key or none.
    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(service.openLocal(text), throwsA(isA<FormatException>()));
    expect(await hasAccount(secret), isTrue);
  });

  test('only the seven newest daily backups are kept', () async {
    final service = BackupService(db);
    backups.createSync(recursive: true);
    final plain = jsonEncode(await service.exportData());
    for (var day = 1; day <= 9; day++) {
      File(
        p.join(backups.path, 'flourish-2026-09-${'$day'.padLeft(2, '0')}.json'),
      ).writeAsStringSync(plain);
    }
    final today = await service.automaticBackup();
    final kept = files();
    expect(kept, hasLength(7));
    expect(kept.map((f) => f.path), contains(today.path));
    expect(
      kept.map((f) => p.basename(f.path)),
      isNot(contains('flourish-2026-09-01.json')),
    );
  });

  test('a password backup refuses a tampered file', () async {
    final service = BackupService(db);
    final text = await service.encrypt('strong-test-password');
    final j = jsonDecode(text) as Map<String, dynamic>;
    final mac = base64Decode(j['mac'] as String);
    mac[0] ^= 0xFF;
    j['mac'] = base64Encode(mac);
    await expectLater(
      service.decrypt(jsonEncode(j), 'strong-test-password'),
      throwsA(anything),
    );
    final clear = await service.decrypt(text, 'strong-test-password');
    expect(jsonEncode(clear), contains(secret));
  });
}
