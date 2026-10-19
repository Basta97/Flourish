import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flourish/data/database/database.dart';
import 'support/search_benchmark.dart';

void main() {
  test(
    '100k transactions and 10k documents search benchmark',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final result = await benchmarkSearch(db);
      // Device budgets are measured separately; host timing is diagnostic.
      // ignore: avoid_print
      print('SEARCH_BENCHMARK $result');
      expect(result['transactions'], 100000);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
