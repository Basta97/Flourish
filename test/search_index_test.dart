import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/data/search/search_repository.dart';
import 'package:flourish/core/search/search_models.dart';

void main() {
  test('indexes bilingual records and updates from direct SQL', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = SearchRepository(db);
    await repository.prepare();
    await db.customStatement(
      "INSERT INTO accounts(name,type,currency,color,icon,created_at) VALUES ('محفظة أحمد','cash','EGP',0,'wallet',1)",
    );
    expect(
      (await repository.search(
        const SearchQuery('احمد'),
      )).hits.any((h) => h.kind == 'account'),
      true,
    );
    await db.customStatement(
      "UPDATE accounts SET name='Alexandria' WHERE name='محفظة أحمد'",
    );
    expect(
      (await repository.search(
        const SearchQuery('xand'),
      )).hits.any((h) => h.kind == 'account'),
      true,
    );
    expect(
      (await repository.search(const SearchQuery('احمد'))).hits.isEmpty,
      true,
    );
    expect(
      (await repository.search(
        const SearchQuery('نسخ احتياطي'),
      )).hits.any((h) => h.kind == 'feature'),
      true,
    );
    expect(
      (await repository.search(
        const SearchQuery('" OR * % _'),
      )).hits.where((h) => h.kind == 'account').isEmpty,
      true,
    );
    expect(
      await db
          .customSelect('PRAGMA integrity_check')
          .getSingle()
          .then((r) => r.data.values.first),
      'ok',
    );
  });
}
