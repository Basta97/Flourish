import '../../data/search/search_index.dart';
import 'transaction_templates.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/database/database.dart';
import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';
import '../services/preferences_service.dart';

class BackupService {
  final AppDatabase db;

  /// Holds [localKeyName], the key automatic backups are sealed with.
  final FlutterSecureStorage keys;
  BackupService(this.db, {FlutterSecureStorage? keys})
    : keys = keys ?? const FlutterSecureStorage();

  /// Automatic backups written since 1.2: AES-256-GCM with a random key kept
  /// in Android Keystore-backed secure storage. The key is excluded from
  /// Android backup and device transfer, so the files open only on the
  /// installation that wrote them. Files from 1.1 and earlier are plain
  /// `flourish-finance` JSON and are sealed in place (see [_sealLegacy]).
  static const localFormat = 'flourish-local';
  static const localKeyName = 'local_backup_key';
  static const tableNames = [
    'categories',
    'accounts',
    'payment_instruments',
    'transactions',
    'budgets',
    'recurring_transactions',
    'goals',
    ...FinanceStore.tables,
    'detected_payments',
  ];

  /// Schema version that introduced each table added after v6.
  static const requiredSince = {
    'payment_instruments': 7,
    'detected_payments': 8,
  };
  static const settings = [
    'default_currency',
    'app_theme_mode',
    'month_start_day',
    'monthly_auto_income',
    'monthly_income_amount',
    'monthly_income_day',
    'monthly_income_account_id',
    'monthly_income_category_id',
    'last_auto_income_month',
    'detection_auto_confirm',
    'detection_raw_text_days',
    'detection_backup_raw_text',
    'detection_notify',
  ];
  Future<Json> exportData() => db.transaction(() async {
    final tables = <String, dynamic>{};
    // Message text stays on this device unless the person opted in.
    final keepText = PreferencesService.getBool('detection_backup_raw_text');
    for (final table in tableNames) {
      tables[table] = (await db.customSelect('SELECT * FROM $table').get())
          .map(
            (r) => table == 'detected_payments' && !keepText
                ? {...r.data, 'raw_text': null}
                : r.data,
          )
          .toList();
    }
    final attachments = <String, String>{};
    for (final attachment in await FinanceStore(db).list('attachments')) {
      final file = File(attachment['path']);
      if (await file.exists()) {
        attachments[attachment['id']] = base64Encode(await file.readAsBytes());
      }
    }
    return {
      'format': 'flourish-finance',
      'version': 1,
      'databaseVersion': db.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
      'attachments': attachments,
      'settings': {
        for (final key in settings)
          if (PreferencesService.prefs.containsKey(key))
            key: PreferencesService.prefs.get(key),
      },
    };
  });
  Future<void> restore(Json payload) async {
    if (payload['format'] != 'flourish-finance' ||
        payload['version'] != 1 ||
        payload['tables'] is! Map) {
      throw const FormatException('Unsupported or invalid backup');
    }
    if (payload['databaseVersion'] is! int ||
        (payload['databaseVersion'] as int) > db.schemaVersion) {
      throw const FormatException(
        'Backup requires a newer version of Flourish',
      );
    }
    final tables = Map<String, dynamic>.from(payload['tables'] as Json);
    final version = payload['databaseVersion'] as int;
    for (final name in tableNames) {
      if (tables[name] is List) continue;
      // Tables added after the backup was taken restore empty.
      if (version < (requiredSince[name] ?? 0)) {
        tables[name] = const [];
        continue;
      }
      throw FormatException('Missing backup table: $name');
    }
    final copied = <File>[];
    bool committed = false;
    final pathMap = <String, String>{};
    final dir = await getApplicationDocumentsDirectory();
    try {
      final attachments = payload['attachments'] as Json? ?? {};
      for (final row in (tables['finance_records'] as List)) {
        if (row['collection'] != 'attachments') continue;
        final data = jsonDecode(row['payload']) as Json;
        final bytes = attachments[data['id']];
        if (bytes == null) continue;
        final file = File(
          p.join(
            dir.path,
            'receipt-restored-${DateTime.now().microsecondsSinceEpoch}-${copied.length}${p.extension(data['path']).toLowerCase() == '.png' ? '.png' : '.jpg'}',
          ),
        );
        await file.writeAsBytes(base64Decode(bytes as String), flush: true);
        copied.add(file);
        pathMap[data['path']] = file.path;
      }
      await db.customStatement('PRAGMA foreign_keys=OFF');
      try {
        await db.transaction(() async {
          for (final name in tableNames.reversed) {
            await db.customStatement('DELETE FROM $name');
          }
          for (final name in tableNames) {
            final allowed =
                (await db.customSelect('PRAGMA table_info($name)').get())
                    .map((r) => r.read<String>('name'))
                    .toSet();
            for (final value in tables[name] as List) {
              final row = Map<String, dynamic>.from(value as Map);
              if (row.isEmpty || !row.keys.every(allowed.contains)) {
                throw FormatException('Invalid columns in $name');
              }
              if (name == 'finance_records' &&
                  row['collection'] == 'attachments') {
                final data = jsonDecode(row['payload']) as Json;
                if (pathMap.containsKey(data['path'])) {
                  data['path'] = pathMap[data['path']];
                  row['payload'] = jsonEncode(data);
                }
              }
              await db.customStatement(
                'INSERT INTO $name (${row.keys.join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
                row.values.toList(),
              );
            }
          }
          await _validateFinancialRecords();
          final errors = await db
              .customSelect('PRAGMA foreign_key_check')
              .get();
          if (errors.isNotEmpty) {
            throw const FormatException(
              'Backup contains broken account/category references',
            );
          }
          for (final row
              in await db
                  .customSelect('SELECT balance,opening FROM exact_balances')
                  .get()) {
            amountOf(row.read<String>('balance'));
            amountOf(row.read<String>('opening'));
          }
          await SearchIndex.rebuild(db);
        });
      } finally {
        await db.customStatement('PRAGMA foreign_keys=ON');
      }
      committed = true;
      // Raw SQL bypasses Drift's change tracking; without this, watched
      // queries (such as the review count) keep showing the old rows.
      db.markTablesUpdated(db.allTables);
      final preferences = payload['settings'] as Json? ?? {};
      for (final key in settings) {
        final value = preferences[key];
        if (value is String) {
          await PreferencesService.setString(key, value);
        } else if (value is bool) {
          await PreferencesService.setBool(key, value);
        } else if (value is int) {
          await PreferencesService.setInt(key, value);
        } else if (value is double) {
          await PreferencesService.setDouble(key, value);
        }
      }
      db.notifyFinanceChanged();
    } catch (_) {
      for (final file in committed ? <File>[] : copied) {
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
  }

  Future<void> _validateFinancialRecords() async {
    final store = FinanceStore(db);
    final accounts = {for (final a in await db.getAllAccounts()) a.id: a};
    for (final j in await store.list('templates')) {
      TransactionTemplate.fromJson(j);
    }
    final holdings = <String, Holding>{};
    for (final j in await store.list('holdings')) {
      final h = Holding.fromJson(j);
      if (h.quantity < Amount.zero ||
          h.ownership <= Amount.zero ||
          h.ownership > Amount.one ||
          h.karat < 1 ||
          h.karat > 24) {
        throw const FormatException('Invalid holding');
      }
      holdings[h.id] = h;
    }
    final contracts = <String, FinanceContract>{};
    for (final j in await store.list('contracts')) {
      final c = FinanceContract.fromJson(j);
      if (c.principal < Amount.zero ||
          c.annualRate < Amount.zero ||
          !c.maturity.isAfter(c.start) ||
          (c.accountId != null && !accounts.containsKey(c.accountId)) ||
          (c.cardAccountId != null && !accounts.containsKey(c.cardAccountId))) {
        throw const FormatException('Invalid contract references or amounts');
      }
      try {
        c.card?.validate();
      } on ArgumentError {
        throw const FormatException('Invalid credit card terms');
      }
      contracts[c.id] = c;
    }
    for (final j in await store.list('payments')) {
      final p = ScheduledPayment.fromJson(j);
      if (!contracts.containsKey(p.contractId) ||
          p.principal < Amount.zero ||
          p.interest < Amount.zero) {
        throw const FormatException('Invalid scheduled payment');
      }
    }
    for (final collection in ['prices', 'fx']) {
      for (final j in await store.list(collection)) {
        final value = MarketObservation.fromJson(j);
        if (value.value <= Amount.zero) {
          throw const FormatException('Invalid cached price');
        }
      }
    }
    for (final h in holdings.values) {
      if (h.linkedContractId != null &&
          !contracts.containsKey(h.linkedContractId)) {
        throw const FormatException('Missing linked property contract');
      }
    }
    for (final j in await store.list('activity')) {
      if (j['holdingId'] != null && !holdings.containsKey(j['holdingId'])) {
        throw const FormatException('Missing holding activity reference');
      }
      if (j['transactionId'] != null &&
          await db.getTransactionById(j['transactionId'] as int) == null) {
        throw const FormatException('Missing activity transaction');
      }
    }
  }

  static Future<void> _backupQueue = Future<void>.value();
  Future<File> automaticBackup() {
    final next = _backupQueue.then((_) => _writeAutomaticBackup());
    _backupQueue = next.then<void>(
      (_) {},
      onError: (Object e, StackTrace st) {},
    );
    return next;
  }

  Future<File> _writeAutomaticBackup() async {
    final directory = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'backups'),
    );
    await directory.create(recursive: true);
    // Writes are queued, so a leftover temp file is from an interrupted
    // write; before 1.2 it would even be plain text.
    await for (final entry in directory.list()) {
      if (entry is File && entry.path.endsWith('.tmp')) await entry.delete();
    }
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final file = File(p.join(directory.path, 'flourish-$day.json'));
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      await sealLocal(jsonEncode(await exportData())),
      flush: true,
    );
    await temp.rename(file.path);
    await _sealLegacy(directory);
    final files = await directory
        .list()
        .where((f) => f is File && f.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    for (final old in files.skip(7)) {
      await old.delete();
    }
    return file;
  }

  /// The key automatic backups are sealed with, created on first use.
  Future<SecretKey?> _localKey({required bool create}) async {
    final stored = await keys.read(key: localKeyName);
    if (stored != null) return SecretKey(base64Decode(stored));
    if (!create) return null;
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final encoded = base64Encode(bytes);
    await keys.write(key: localKeyName, value: encoded);
    // Never seal with a key that did not persist: the file would be lost.
    if (await keys.read(key: localKeyName) != encoded) {
      throw StateError('Could not store the backup key');
    }
    return SecretKey(bytes);
  }

  /// Encrypts [clear] with this device's backup key.
  Future<String> sealLocal(String clear) async {
    final key = (await _localKey(create: true))!;
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(clear),
      secretKey: key,
    );
    return jsonEncode({
      'format': localFormat,
      'version': 1,
      'nonce': base64Encode(box.nonce),
      'cipher': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  Future<String> _unsealLocal(Json j) async {
    if (j['version'] != 1) {
      throw const FormatException('Unsupported or invalid backup');
    }
    final key = await _localKey(create: false);
    if (key == null) {
      throw const FormatException(
        'This backup was encrypted on another installation of Flourish',
      );
    }
    try {
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(
          base64Decode(j['cipher']),
          nonce: base64Decode(j['nonce']),
          mac: Mac(base64Decode(j['mac'])),
        ),
        secretKey: key,
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'This backup is damaged or was encrypted on another installation',
      );
    }
  }

  /// Reads an automatic backup: sealed on this device, or plain JSON from
  /// Flourish 1.1 and earlier. The result is ready for [restore].
  Future<Json> openLocal(String text) async {
    final j = jsonDecode(text) as Json;
    if (j['format'] == 'flourish-finance') return j;
    if (j['format'] != localFormat) {
      throw const FormatException('Unsupported or invalid backup');
    }
    return jsonDecode(await _unsealLocal(j)) as Json;
  }

  /// Seals plain automatic backups left by Flourish 1.1 and earlier. Each
  /// file is replaced only once its sealed copy reads back identical, so a
  /// failure leaves the original as it was.
  Future<void> _sealLegacy(Directory directory) async {
    final files = await directory
        .list()
        .where((f) => f is File && f.path.endsWith('.json'))
        .cast<File>()
        .toList();
    for (final file in files) {
      if (!await _isPlain(file)) continue;
      final clear = await file.readAsString();
      final sealed = File('${file.path}.tmp');
      await sealed.writeAsString(await sealLocal(clear), flush: true);
      final check = jsonDecode(await sealed.readAsString()) as Json;
      if (await _unsealLocal(check) != clear) {
        await sealed.delete();
        continue;
      }
      await sealed.rename(file.path);
    }
  }

  /// Plain backups start with their format; reading the head is enough.
  static Future<bool> _isPlain(File file) async {
    final handle = await file.open();
    try {
      final head = utf8.decode(await handle.read(64), allowMalformed: true);
      return head.contains('"format":"flourish-finance"');
    } finally {
      await handle.close();
    }
  }

  Future<String> encrypt(String password) async {
    if (password.length < 10) throw ArgumentError('Use at least 10 characters');
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 210000,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    final cipher = AesGcm.with256bits();
    final box = await cipher.encrypt(
      utf8.encode(jsonEncode(await exportData())),
      secretKey: key,
    );
    return jsonEncode({
      'format': 'flourish-encrypted',
      'version': 1,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'cipher': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  Future<Json> decrypt(String text, String password) async {
    final j = jsonDecode(text) as Json;
    if (j['format'] != 'flourish-encrypted' || j['version'] != 1) {
      throw const FormatException('Invalid encrypted backup');
    }
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 210000,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: base64Decode(j['salt']));
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(
        base64Decode(j['cipher']),
        nonce: base64Decode(j['nonce']),
        mac: Mac(base64Decode(j['mac'])),
      ),
      secretKey: key,
    );
    return jsonDecode(utf8.decode(clear)) as Json;
  }
}
