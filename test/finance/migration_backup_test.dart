import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/data/finance/finance_store.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/core/finance/backup_service.dart';
import 'package:flourish/core/finance/spreadsheet_import_service.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/domain/finance/models.dart';

class TestPaths extends PathProviderPlatform {
  final String path;
  TestPaths(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  late AppDatabase db;
  late FinancialLedgerService ledger;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'default_currency': 'EGP'});
    await PreferencesService.init();
    folder = await Directory.systemTemp.createTemp('flourish-finance-test');
    PathProviderPlatform.instance = TestPaths(folder.path);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = FinancialLedgerService(db);
  });
  tearDown(() async {
    await db.close();
    await folder.delete(recursive: true);
  });
  Future<int> cash() => db.insertAccount(
    AccountsCompanion.insert(
      name: 'Acceptance cash',
      type: 'bank',
      currency: const Value('EGP'),
      balance: const Value(1000),
      color: 0xFF000000,
      icon: 'account_balance',
    ),
  );

  test(
    'v5 migration preserves identifiers, balances, transfer links, and derives opening adjustment',
    () async {
      await db.close();
      final file = File('${folder.path}/legacy.db');
      final legacy = AppDatabase.forTesting(NativeDatabase(file));
      final id = await legacy.insertAccount(
        AccountsCompanion.insert(
          name: 'Legacy',
          type: 'bank',
          balance: const Value(1000),
          color: 0xFF000000,
          icon: 'account_balance',
        ),
      );
      final other = await legacy.insertAccount(
        AccountsCompanion.insert(
          name: 'Other legacy',
          type: 'cash',
          balance: const Value(50),
          color: 0xFF000000,
          icon: 'wallet',
        ),
      );
      await FinancialLedgerService(legacy).transferBetweenAccounts(
        fromAccountId: id,
        toAccountId: other,
        amount: 100,
      );
      final original = await legacy.getAllTransactions();
      for (final table in FinanceStore.tables) {
        await legacy.customStatement('DROP TABLE $table');
      }
      await legacy.customStatement('PRAGMA user_version=5');
      await legacy.close();
      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      expect((await migrated.getAccountById(id))!.balance, 900);
      expect(await FinanceStore(migrated).balance(id), Amount('900'));
      final rows = await migrated.getAllTransactions();
      expect(rows.map((t) => t.id), original.map((t) => t.id));
      expect(
        rows.map((t) => t.linkedTransactionId),
        original.map((t) => t.linkedTransactionId),
      );
      final opening =
          (await migrated
                  .customSelect(
                    'SELECT opening FROM exact_balances WHERE account_id=$id',
                  )
                  .get())
              .single
              .read<String>('opening');
      expect(amountOf(opening), Amount('1000'));
      await migrated.close();
      db = AppDatabase.forTesting(NativeDatabase.memory());
    },
  );
  test(
    'full backup restores holdings, exact cash, metadata, and settings',
    () async {
      final id = await cash();
      await ledger.recordCash(
        accountId: id,
        amount: Amount('12.34'),
        type: 'expense',
      );
      await ledger.openHolding(
        Holding(
          id: 'gold',
          name: 'Gold',
          kind: AssetKind.gold,
          quantity: Amount('10.123456789'),
          currency: 'EGP',
          openedAt: DateTime(2026, 1, 1),
          ownership: Amount.one,
        ),
      );
      final backup = BackupService(db);
      final data = await backup.exportData();
      await ledger.reconcile(id, Amount('1'), 'Fixture changed after export');
      await ledger.store.remove('holdings', 'gold');
      await backup.restore(data);
      expect(await ledger.store.balance(id), Amount('987.66'));
      expect(
        (await ledger.portfolio.get('gold'))!.quantity,
        Amount('10.123456789'),
      );
      expect(PreferencesService.getString('default_currency'), 'EGP');
    },
  );
  test('invalid references roll back the entire restore', () async {
    final id = await cash();
    await ledger.recordCash(
      accountId: id,
      amount: Amount('10'),
      type: 'expense',
    );
    final backup = BackupService(db),
        data = await BackupService(db).exportData();
    final table = data['tables'] as Json;
    (table['transactions'] as List).first['account_id'] = 999999;
    await expectLater(backup.restore(data), throwsFormatException);
    expect(await ledger.store.balance(id), Amount('990'));
    expect((await db.getAllTransactions()).single.accountId, id);
  });
  test(
    'encrypted backup authenticates the password and rejects tampering',
    () async {
      await cash();
      final backup = BackupService(db),
          text = await BackupService(db).encrypt('strong-test-password');
      final clear = await backup.decrypt(text, 'strong-test-password');
      expect(clear['format'], 'flourish-finance');
      await expectLater(
        backup.decrypt(text, 'incorrect-password'),
        throwsA(anything),
      );
    },
  );
  test(
    'spreadsheet preview detects duplicates and applies atomically',
    () async {
      final service = SpreadsheetImportService(ledger);
      final rows = [
        [
          '14/10/2026',
          'Expense',
          'Cash import',
          'Groceries',
          '100',
          'EGP',
          'Weekly groceries',
        ],
        [
          '14/10/2026',
          'Expense',
          'Cash import',
          'Groceries',
          '100',
          'EGP',
          'Weekly groceries',
        ],
      ];
      final map = {
        'date': 0,
        'type': 1,
        'account': 2,
        'category': 3,
        'amount': 4,
        'currency': 5,
        'note': 6,
      };
      final preview = await service.preview(rows, map, fallbackCurrency: 'EGP');
      expect(preview.errors, isEmpty);
      expect(preview.rows.length, 1);
      expect(preview.duplicates, 1);
      expect(await service.apply(preview), 1);
      expect(await service.apply(preview), 0);
      final account = (await db.getAllAccounts()).firstWhere(
        (a) => a.name == 'Cash import',
      );
      expect(await ledger.store.balance(account.id), Amount('-100'));
      final invalid = await service.preview(
        [
          [
            'wrong-date',
            'Expense',
            'Cash import',
            'Food',
            '20',
            'EGP',
            'Invalid',
          ],
        ],
        map,
        fallbackCurrency: 'EGP',
      );
      await expectLater(service.apply(invalid), throwsStateError);
      expect(await ledger.store.balance(account.id), Amount('-100'));
    },
  );
  test(
    'malformed holding payloads reject a restore without erasing current finances',
    () async {
      final id = await cash();
      final backup = BackupService(db),
          data = await BackupService(db).exportData();
      ((data['tables'] as Json)['finance_records'] as List).add({
        'collection': 'holdings',
        'id': 'broken',
        'payload': '{"id":"broken","kind":"not-an-asset"}',
      });
      await expectLater(backup.restore(data), throwsA(anything));
      expect(await ledger.store.balance(id), Amount('1000'));
    },
  );
  test(
    'attached receipt bytes and their transaction relationship survive restore',
    () async {
      final id = await cash(),
          tx = await ledger.recordCash(
            accountId: await cash(),
            amount: Amount('10'),
            type: 'expense',
          );
      final file = File('${folder.path}/receipt.png');
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jN1sAAAAASUVORK5CYII=',
      );
      await file.writeAsBytes(bytes);
      await ledger.store.put('attachments', 'receipt', {
        'id': 'receipt',
        'path': file.path,
        'transactionId': tx,
        'date': DateTime.now().toIso8601String(),
      });
      final backup = BackupService(db),
          payload = await BackupService(db).exportData();
      await file.delete();
      await backup.restore(payload);
      final record = (await ledger.store.list('attachments')).single;
      expect(record['transactionId'], tx);
      expect(await File(record['path']).readAsBytes(), bytes);
      expect(await ledger.store.balance(id), Amount('1000'));
    },
  );
  test(
    'spreadsheet conventions prevent silent sign and decimal changes',
    () async {
      final service = SpreadsheetImportService(ledger),
          mapping = {
            'date': 0,
            'type': 1,
            'account': 2,
            'category': 3,
            'amount': 4,
          };
      final rows = [
        ['14/10/2026', 'Expense', 'Bank', 'Food', '-1.234,56'],
      ];
      final rejected = await service.preview(
        rows,
        mapping,
        fallbackCurrency: 'EGP',
        decimalSeparator: ',',
      );
      expect(rejected.errors, isNotEmpty);
      final accepted = await service.preview(
        rows,
        mapping,
        fallbackCurrency: 'EGP',
        decimalSeparator: ',',
        signedAmounts: true,
      );
      expect(accepted.errors, isEmpty);
      expect(accepted.rows.single['amount'], '1234.56');
      expect(accepted.rows.single['type'], 'expense');
    },
  );
}
