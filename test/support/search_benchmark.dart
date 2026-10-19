import 'package:drift/drift.dart' show Variable;
import 'package:flourish/data/database/database.dart';
import 'package:flourish/data/search/search_repository.dart';
import 'package:flourish/data/search/search_index.dart';
import 'package:flourish/core/search/search_models.dart';

Future<Map<String, Object>> benchmarkSearch(AppDatabase db) async {
  await db.customStatement('SELECT 1');
  final category = (await db.getAllCategories())
      .firstWhere((c) => c.type == 'expense')
      .id;
  final seed = Stopwatch()..start();
  await db.transaction(() async {
    await db.customStatement(
      "INSERT INTO accounts(id,name,type,currency,color,icon,created_at) VALUES (987654,'Benchmark wallet','cash','EGP',0,'wallet',1)",
    );
    await db.customStatement(
      '''WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<100000)
    INSERT INTO transactions(account_id,category_id,amount,type,note,transaction_date,merchant,created_at)
    SELECT 987654,$category,(x%100000)/100.0+1,'expense',
    CASE x%5 WHEN 0 THEN 'Coffee breakfast أحمد' WHEN 1 THEN 'Weekly grocery shop' WHEN 2 THEN 'Monthly electricity bill' WHEN 3 THEN 'School transport' ELSE 'Online shopping' END || ' ' || x,
    1700000000+x,CASE x%5 WHEN 0 THEN 'Coffee corner' ELSE 'Merchant ' || (x%100) END,1700000000+x FROM n''',
    );
    await db.customStatement(
      '''WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<10000)
    INSERT INTO finance_records(collection,id,payload)
    SELECT 'templates','bench-' || x,json_object('id','bench-' || x,'name','Saved preset ' || x,'account','987654','category','$category','note','Benchmark template') FROM n''',
    );
  });
  seed.stop();
  final backfill = Stopwatch()..start();
  await SearchIndex.backfill(db);
  backfill.stop();
  String? lastSql;
  List<Variable> lastVariables = [];
  final repo = SearchRepository(
    db,
    onQuery: (sql, variables) {
      lastSql = sql;
      lastVariables = variables;
    },
  );
  final latency = <int>[];
  final perQuery = <String, List<int>>{};
  final queries = [
    'coffee',
    'احمد',
    'co',
    'breakfast wallet',
    'grocery',
    'preset 9999',
    'EGP',
  ];
  for (final q in queries) {
    await repo.search(SearchQuery(q));
  }
  for (var iteration = 0; iteration < 5; iteration++) {
    for (final q in queries) {
      final watch = Stopwatch()..start();
      await repo.search(SearchQuery(q));
      watch.stop();
      latency.add(watch.elapsedMicroseconds);
      perQuery.putIfAbsent(q, () => []).add(watch.elapsedMicroseconds);
    }
  }
  latency.sort();
  final plan = await db
      .customSelect('EXPLAIN QUERY PLAN $lastSql', variables: lastVariables)
      .get();
  // ignore: avoid_print
  print('SEARCH_PLAN ${plan.map((r) => r.data).toList()}');
  final size = await db
      .customSelect(
        'SELECT page_count*page_size bytes FROM pragma_page_count(),pragma_page_size()',
      )
      .getSingle();
  return {
    'transactions': 100000,
    'otherRecords': 10000,
    'seedMs': seed.elapsedMilliseconds,
    'backfillMs': backfill.elapsedMilliseconds,
    'p95Ms': latency[(latency.length * .95).ceil() - 1] / 1000,
    'maxMs': latency.last / 1000,
    'databaseBytes': size.read<int>('bytes'),
    'queries': queries.join(', '),
    'queryMaxMs': {
      for (final e in perQuery.entries)
        e.key: e.value.reduce((a, b) => a > b ? a : b) / 1000,
    },
  };
}
