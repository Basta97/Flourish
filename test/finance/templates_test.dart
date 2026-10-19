import 'package:flourish/data/search/search_repository.dart';
import 'package:flourish/core/search/search_models.dart';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flourish/core/finance/transaction_templates.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/core/finance/backup_service.dart';
import 'package:flourish/core/finance/monthly_summary_service.dart';
import 'package:flourish/core/finance/valuation_service.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/domain/finance/models.dart';

class _Paths extends PathProviderPlatform {
  final String path;
  _Paths(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FinancialLedgerService ledger;
  late Directory folder;
  late int account, category;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'default_currency': 'EGP'});
    await PreferencesService.init();
    folder = await Directory.systemTemp.createTemp('flourish-template-test');
    PathProviderPlatform.instance = _Paths(folder.path);
    db = AppDatabase.forTesting(
      NativeDatabase(File('${folder.path}/finance.sqlite')),
    );
    ledger = FinancialLedgerService(db);
    account = await db.insertAccount(
      AccountsCompanion.insert(
        name: 'Salary account',
        type: 'bank',
        color: 0,
        icon: 'account_balance',
        currency: const Value('EGP'),
        balance: const Value(1000),
      ),
    );
    category = (await db.getAllCategories())
        .firstWhere((c) => c.type == 'expense')
        .id;
  });
  tearDown(() async {
    await db.close();
    await folder.delete(recursive: true);
  });
  TransactionTemplate template([
    List<String> amounts = const ['25', '50', '75'],
  ]) => TransactionTemplate(
    id: 'coffee',
    name: 'Coffee',
    type: 'expense',
    accountId: account,
    categoryId: category,
    amounts: amounts.map(Amount.new).toList(),
    note: 'Morning coffee',
  );

  test('legacy and three-preset templates survive backup restore', () async {
    final repo = TransactionTemplateRepository(ledger.store);
    await ledger.store.put('templates', 'old', {
      'id': 'old',
      'name': 'Legacy',
      'type': 'expense',
      'account': '$account',
      'category': '$category',
      'amount': '12.50',
      'note': '',
    });
    await repo.save(template());
    expect((await repo.list()).first.amounts.length, 3);
    await ledger.store.put('fxFavorites', 'USD/BRL', {'pair': 'USD/BRL'});
    final backup = await BackupService(db).exportData();
    expect(
      (backup['tables'] as Map).keys.any((k) => '$k'.startsWith('search_')),
      false,
    );
    await repo.delete('coffee');
    await BackupService(db).restore(backup);
    expect((await ledger.store.list('fxFavorites')).single['pair'], 'USD/BRL');
    expect(
      (await SearchRepository(db).search(
        const SearchQuery('Legacy'),
      )).hits.any((h) => h.kind == 'template'),
      true,
    );
    final restored = await repo.list();
    expect(restored.first.amounts.map((a) => '$a'), ['25', '50', '75']);
    expect(restored.last.amounts.single, Amount('12.5'));
    await repo.save(restored.last);
    expect(
      (await ledger.store.get('templates', 'old'))!.containsKey('amount'),
      false,
    );
  });
  test(
    'applying records once and remains editable after restart or template deletion',
    () async {
      final t = template();
      await TransactionTemplateRepository(ledger.store).save(t);
      expect(await db.getAllTransactions(), isEmpty); // Saving is not applying.
      final id = await ledger.recordCash(
        accountId: account,
        categoryId: category,
        amount: t.amounts[1],
        type: t.type,
        note: t.note,
        source: 'template',
        sourceRef: t.id,
      );
      expect(await ledger.store.balance(account), Amount('950'));
      await db.close();
      db = AppDatabase.forTesting(
        NativeDatabase(File('${folder.path}/finance.sqlite')),
      );
      ledger = FinancialLedgerService(db);
      final row = (await db.getAllTransactions()).single;
      expect(row.source, 'template');
      expect(row.sourceRef, 'coffee');
      await TransactionTemplateRepository(ledger.store).delete('coffee');
      await ledger.updateCash(
        id,
        accountId: account,
        amount: Amount('60'),
        type: 'expense',
        categoryId: category,
        date: DateTime.now(),
      );
      expect(await ledger.store.balance(account), Amount('940'));
      final totals = await MonthlySummaryService(
        ledger.store,
        ValuationService(ledger.store),
      ).calculate(await db.getAllTransactions(), 'EGP');
      expect(totals.$2, Amount('60'));
      await ledger.deleteTransactionAndUpdateBalance(id);
      expect(await ledger.store.balance(account), Amount('1000'));
    },
  );
  test('invalid presets are rejected', () {
    for (final values in <List<String>>[
      [],
      ['0'],
      ['-1'],
      ['1', '2', '3', '4'],
    ]) {
      expect(() => template(values), throwsFormatException);
    }
  });
  test(
    'ledger rejects archived or missing references instead of writing a transaction',
    () async {
      await ledger.store.put('accountDetails', '$account', {
        'id': '$account',
        'archived': true,
      });
      await expectLater(
        ledger.recordCash(
          accountId: account,
          amount: Amount('50'),
          type: 'expense',
          categoryId: category,
        ),
        throwsStateError,
      );
      await expectLater(
        ledger.recordCash(
          accountId: 99999,
          amount: Amount('50'),
          type: 'expense',
          categoryId: category,
        ),
        throwsStateError,
      );
      expect(await db.getAllTransactions(), isEmpty);
      expect(await ledger.store.balance(account), Amount('1000'));
    },
  );
  test('reporting month respects configured start day and year rollover', () {
    final period = MonthlySummaryService.period(DateTime(2027, 1, 2), 5);
    expect(period.$1, DateTime(2026, 12, 5));
    expect(period.$2, DateTime(2027, 1, 5));
  });
}
