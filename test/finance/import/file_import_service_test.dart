import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/core/finance/import/file_import_service.dart';
import 'package:flourish/core/finance/import/import_sources.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/domain/finance/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  late AppDatabase db;
  late FinancialLedgerService ledger;
  late FileImportService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = FinancialLedgerService(db);
    service = FileImportService(ledger);
    for (final a in await db.getAllAccounts()) {
      await (db.delete(db.accounts)..where((t) => t.id.equals(a.id))).go();
    }
  });
  tearDown(() => db.close());

  Future<ImportPlan> plan(
    String file, {
    String? content,
    Map<String, int> accountMap = const {},
    String currency = 'EGP',
  }) {
    final text = content ?? fixture(file);
    final parsed = ImportSources.parse(
      file,
      text,
      options: ImportOptions(defaultCurrency: currency, defaultAccount: 'Main'),
    );
    return service.plan(
      parsed,
      sourceName: ImportSources.detect(file, text)?.name ?? file,
      defaultCurrency: currency,
      accountMap: accountMap,
    );
  }

  Future<Amount> balanceOf(String name) async {
    final a = (await db.getAllAccounts()).firstWhere((a) => a.name == name);
    return ledger.store.balance(a.id);
  }

  const files = [
    'money_manager.csv',
    'wallet.csv',
    'monefy.csv',
    'spendee.csv',
    'ynab.csv',
    'flourish_export.csv',
    'bank_signed.csv',
    'bank_debit_credit.csv',
    'bank_sgml.ofx',
    'multi_xml.qfx',
    'quicken_us.qif',
    'european.qif',
  ];

  for (final file in files) {
    test('$file: imports every ready row, balances match, re-import adds none', () async {
      final first = await plan(file);
      final ready = first.count(ImportRowStatus.ready);
      expect(ready, greaterThan(0), reason: 'fixture has importable rows');
      final expected = first.totalsByAccount();

      final outcome = await service.apply(first);
      expect(outcome.imported, ready);

      for (final entry in expected.entries) {
        final name = entry.key.substring(0, entry.key.lastIndexOf(' ('));
        expect(await balanceOf(name), entry.value, reason: entry.key);
      }

      final again = await plan(file);
      expect(again.count(ImportRowStatus.ready), 0);
      expect((await service.apply(again)).imported, 0);
    });
  }

  test('Money Manager: transfer legs become one transfer; subcategory under parent', () async {
    final p = await plan('money_manager.csv');
    final transfers = p.rows.where((r) => r.row.type == 'transfer').toList();
    expect(transfers, hasLength(1));
    expect(transfers.single.row.destinationAccount, 'Cash');

    final lunch = p.categories.firstWhere((c) => c.name == 'Lunch');
    expect(lunch.parentName, 'Food');
    expect(lunch.decision, isA<CreateCategory>());
    final salary = p.categories.firstWhere((c) => c.name == 'Salary');
    expect(salary.matchedExactly, isTrue);

    await service.apply(p);
    final all = await db.getAllCategories();
    final lunchCat = all.firstWhere((c) => c.name == 'Lunch');
    final link = await ledger.store.get('categoryParents', '${lunchCat.id}');
    final parent = all.firstWhere((c) => c.id == link!['parent']);
    expect(parent.name, anyOf('Food', 'Food & Drinks'));
    expect(all.where((c) => c.name == 'Salary'), hasLength(1));
  });

  test('similar category names map to the existing one', () async {
    final p = await plan('spendee.csv', currency: 'EUR');
    final food = p.categories.where((c) => c.name == 'Food & Drink').firstOrNull;
    expect(food, isNotNull);
    expect(food!.decision, isA<UseCategory>());
    final existing = await db.getCategoryById((food.decision as UseCategory).categoryId);
    expect(existing!.name, 'Food & Drinks');
  });

  test('user decisions: map to existing or fall back to Other', () async {
    final p = await plan('money_manager.csv');
    final transport = (await db.getAllCategories()).firstWhere(
      (c) => c.name == 'Transport',
    );
    for (final c in p.unresolved) {
      c.decision = c.name == 'Taxi'
          ? UseCategory(transport.id)
          : const UseFallback();
    }
    await service.apply(p);
    final names = (await db.getAllCategories()).map((c) => c.name).toSet();
    expect(names, isNot(contains('Taxi')));
    expect(names, isNot(contains('Lunch')));
  });

  test('OFX: FITID is the duplicate key even when the memo changes', () async {
    final map = <String, int>{};
    final p = await plan('bank_sgml.ofx', currency: 'USD');
    await service.apply(p);
    final edited = fixture('bank_sgml.ofx').replaceAll('Card 1234', 'Card ending 1234');
    final again = await plan('bank_sgml.ofx', content: edited, accountMap: map, currency: 'USD');
    expect(again.count(ImportRowStatus.ready), 0);
  });

  test('file accounts can be mapped to existing ones; currency must match', () async {
    final checking = await db.insertAccount(
      AccountsCompanion.insert(
        name: 'My checking',
        type: 'bank',
        color: 0,
        icon: 'account_balance',
        currency: const Value('USD'),
      ),
    );
    final egp = await db.insertAccount(
      AccountsCompanion.insert(
        name: 'EGP wallet',
        type: 'bank',
        color: 0,
        icon: 'account_balance',
        currency: const Value('EGP'),
      ),
    );
    final file = await plan('bank_sgml.ofx', currency: 'USD');
    final name = file.accounts.single.name.toLowerCase();

    final mapped = await plan(
      'bank_sgml.ofx',
      currency: 'USD',
      accountMap: {name: checking},
    );
    expect(mapped.newAccounts, isEmpty);
    expect(mapped.rows.where((r) => r.include).every((r) => r.accountId == checking), isTrue);

    final wrong = await plan(
      'bank_sgml.ofx',
      currency: 'USD',
      accountMap: {name: egp},
    );
    expect(wrong.count(ImportRowStatus.invalid), wrong.rows.length);
  });

  test('a matching manual entry marks a possible duplicate, excluded by default', () async {
    final cash = await db.insertAccount(
      AccountsCompanion.insert(
        name: 'Cash',
        type: 'cash',
        color: 0,
        icon: 'wallet',
        currency: const Value('EGP'),
      ),
    );
    await ledger.recordCash(
      accountId: cash,
      amount: Amount('120'),
      type: 'expense',
      date: DateTime(2024, 2, 2, 9),
    );
    final p = await plan('money_manager.csv');
    final taxi = p.rows.firstWhere((r) => r.row.amount == Amount('120'));
    expect(taxi.status, ImportRowStatus.possibleDuplicate);
    expect(taxi.include, isFalse);
  });

  test('undo removes the batch and allows importing again', () async {
    final p = await plan('money_manager.csv');
    final outcome = await service.apply(p);
    expect(await service.undo(outcome.batchId), greaterThan(0));
    expect(await balanceOf('Cash'), Amount.zero);
    final again = await plan('money_manager.csv');
    expect(again.count(ImportRowStatus.ready), outcome.imported);
  });

  test('a row in another currency than its account is flagged, not booked', () async {
    final p = await plan('multi_xml.qfx', currency: 'EUR');
    final usd = p.rows.firstWhere((r) => r.currency == 'USD');
    expect(usd.status, ImportRowStatus.invalid);
    expect(usd.problem, contains('USD'));
    expect(usd.include, isFalse);
  });
}
