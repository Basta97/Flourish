import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flourish/data/database/database.dart';
import 'package:flourish/data/search/search_repository.dart';
import 'package:flourish/data/search/search_index.dart';
import 'package:flourish/core/search/search_models.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/domain/finance/amount.dart';

void main() {
  late AppDatabase db;
  late SearchRepository repo;
  late int account, category;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SearchRepository(db);
    await repo.prepare();
    account = await db.insertAccount(
      AccountsCompanion.insert(
        name: 'Cairo wallet',
        type: 'cash',
        currency: const Value('EGP'),
        color: 0,
        icon: 'wallet',
      ),
    );
    category = (await db.getAllCategories())
        .firstWhere((c) => c.name == 'Food & Drinks')
        .id;
  });
  tearDown(() => db.close());
  Future<int> record({
    String note = 'Coffee breakfast',
    String type = 'expense',
    String amount = '12.5',
  }) async => FinancialLedgerService(db).recordCash(
    accountId: account,
    categoryId: type == 'income'
        ? (await db.getAllCategories()).firstWhere((c) => c.type == 'income').id
        : category,
    amount: Amount(amount),
    type: type,
    note: note,
  );
  test('filters before LIMIT and keyset pages without duplicates', () async {
    for (var i = 0; i < 111; i++) {
      await record(type: i < 60 ? 'expense' : 'income', note: 'Coffee $i');
    }
    final query = SearchQuery(
      'coffee',
      filters: SearchFilters(
        kind: 'transaction',
        transactionType: 'income',
        accountId: account,
        currency: 'EGP',
        minimum: Amount('12.5'),
        maximum: Amount('12.5'),
      ),
    );
    final first = await repo.search(query);
    expect(first.hits.length, 50);
    expect(first.next, isNotNull);
    final second = await repo.search(query, after: first.next);
    expect(second.hits.length, 1);
    expect(second.next, isNull);
    expect(
      {...first.hits.map((h) => h.id), ...second.hits.map((h) => h.id)}.length,
      51,
    );
    expect(
      (await repo.search(
        const SearchQuery(
          'coffee',
          filters: SearchFilters(kind: 'transaction', newest: true),
        ),
      )).hits.length,
      50,
    );
  });
  test(
    'exact decimal boundaries use transaction_details, not REAL projection',
    () async {
      await record(amount: '99999999999999.01');
      await record(amount: '99999999999999.02');
      final result = await repo.search(
        SearchQuery(
          'coffee',
          filters: SearchFilters(
            kind: 'transaction',
            currency: 'EGP',
            minimum: Amount('99999999999999.02'),
            maximum: Amount('99999999999999.02'),
          ),
        ),
      );
      expect(result.hits.length, 1);
      expect(result.hits.single.amount, '99999999999999.02');
    },
  );
  test(
    'foreign keys, category aliases, finance JSON and deletes stay current',
    () async {
      final id = await record();
      expect(
        (await repo.search(
          const SearchQuery('"coffee breakfast"'),
        )).hits.length,
        1,
      );
      expect(
        (await repo.search(const SearchQuery('"breakfast coffee"'))).hits,
        isEmpty,
      );
      expect(
        (await repo.search(
          const SearchQuery('coffee cairo'),
        )).hits.any((h) => h.id == '$id' && h.kind == 'transaction'),
        true,
      );
      expect(
        (await repo.search(
          const SearchQuery('طَعَام'),
        )).hits.any((h) => h.kind == 'transaction'),
        true,
      );
      await db.customStatement(
        "UPDATE accounts SET name='New wallet' WHERE id=?",
        [account],
      );
      expect((await repo.search(const SearchQuery('cairo'))).hits, isEmpty);
      final store = FinancialLedgerService(db).store;
      await store.put('templates', 'template1', {
        'id': 'template1',
        'name': 'Breakfast preset',
        'account': '$account',
        'category': '$category',
        'note': 'morning',
      });
      expect(
        (await repo.search(const SearchQuery('preset'))).hits.single.kind,
        'template',
      );
      await store.put('fx', 'private', {'name': 'NEVERINDEXPRIVATE'});
      expect(
        (await repo.search(const SearchQuery('NEVERINDEXPRIVATE'))).hits,
        isEmpty,
      );
      await db.customStatement('DELETE FROM transactions WHERE id=?', [id]);
      expect((await repo.search(const SearchQuery('coffee'))).hits, isEmpty);
      await SearchIndex.rebuild(db);
      expect(
        (await repo.search(const SearchQuery('preset'))).hits.single.kind,
        'template',
      );
    },
  );
  test('Arabic digits, short prefixes and FTS punctuation are safe', () async {
    await record(note: 'أَحْمَد قهوة ١٢٣٤');
    expect((await repo.search(const SearchQuery('احمد'))).hits.length, 1);
    expect((await repo.search(const SearchQuery('حمد'))).hits.length, 1);
    expect(
      (await repo.search(
        const SearchQuery('اح', filters: SearchFilters(kind: 'transaction')),
      )).hits.length,
      1,
    );
    expect(
      (await repo.search(
        const SearchQuery('حم', filters: SearchFilters(kind: 'transaction')),
      )).hits,
      isEmpty,
    );
    expect((await repo.search(const SearchQuery('1234'))).hits.length, 1);
    for (final q in ['"', '%', '*', '_', 'NEAR(', 'OR " DROP TABLE']) {
      await repo.search(SearchQuery(q));
    }
  });
  test('background file database survives reopen and rebuild resumes', () async {
    final folder = await Directory.systemTemp.createTemp('flourish-search');
    final file = File('${folder.path}/search.db');
    var disk = AppDatabase.forTesting(NativeDatabase.createInBackground(file));
    await disk.customStatement(
      "INSERT INTO accounts(name,type,currency,color,icon,created_at) VALUES ('Persistent search','cash','USD',0,'wallet',1)",
    );
    await disk.close();
    disk = AppDatabase.forTesting(NativeDatabase.createInBackground(file));
    final repository = SearchRepository(disk);
    await repository.prepare();
    expect(
      (await repository.search(const SearchQuery('persistent'))).hits.length,
      1,
    );
    await disk.close();
    await folder.delete(recursive: true);
  });
  test('v8 migration adds derived indexes without changing ledger data', () async {
    final folder = await Directory.systemTemp.createTemp('flourish-search-v8');
    final file = File('${folder.path}/v8.db');
    var disk = AppDatabase.forTesting(NativeDatabase(file));
    await disk.customStatement(
      "INSERT INTO accounts(name,type,currency,color,icon,created_at) VALUES ('Legacy orchard','cash','EGP',0,'wallet',1)",
    );
    final before = await disk.getAllAccounts();
    for (final trigger
        in await disk
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'search_%'",
            )
            .get()) {
      await disk.customStatement(
        'DROP TRIGGER "${trigger.read<String>('name')}"',
      );
    }
    for (final table in [
      'search_words',
      'search_fragments',
      'search_documents',
      'search_progress',
    ]) {
      await disk.customStatement('DROP TABLE $table');
    }
    await disk.customStatement('PRAGMA user_version=8');
    await disk.close();
    disk = AppDatabase.forTesting(NativeDatabase(file));
    expect(await SearchRepository(disk).ready, false);
    final repository = SearchRepository(disk);
    await repository.prepare();
    expect(
      (await repository.search(const SearchQuery('orchard'))).hits.length,
      1,
    );
    expect(
      (await disk.getAllAccounts()).map((a) => a.id),
      before.map((a) => a.id),
    );
    // Model an interrupted batch: source remains intact and metadata requests retry.
    await disk.customStatement(
      "DELETE FROM search_documents WHERE kind='account'",
    );
    await disk.customStatement(
      "UPDATE search_progress SET checkpoint=0,complete=0 WHERE source='accounts'",
    );
    await SearchRepository(disk).prepare();
    expect(
      (await repository.search(const SearchQuery('orchard'))).hits.length,
      1,
    );
    await disk.close();
    await folder.delete(recursive: true);
  });
}
