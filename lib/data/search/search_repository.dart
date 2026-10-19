import 'dart:async';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../../core/search/search_models.dart';
import 'search_index.dart';

class SearchRepository {
  final AppDatabase db;
  Future<void>? _building;
  final void Function(String, List<Variable>)? onQuery;
  SearchRepository(this.db, {this.onQuery});
  Future<void> prepare() =>
      _building ??= SearchIndex.backfill(db).catchError((Object e) {
        _building = null;
        throw e;
      });
  Future<bool> get ready => SearchIndex.complete(db);

  Future<SearchPage> search(SearchQuery query, {SearchCursor? after}) async {
    final normalized = SearchText.normalize(query.text);
    final terms = RegExp(r'"([^"\n]+)"|([\p{L}\p{N}]+)', unicode: true)
        .allMatches(normalized)
        .map((m) => m.group(1) ?? m.group(2)!)
        .take(20)
        .toList();
    if (terms.isEmpty) return const SearchPage([], null);
    final variables = <Variable>[];
    String bind(Object value) {
      variables.add(
        value is int ? Variable<int>(value) : Variable<String>('$value'),
      );
      return '?${variables.length}';
    }

    final clauses = <String>[];
    final intersections = <String>[];
    for (var i = 0; i < terms.length; i++) {
      final term = terms[i];
      final fragments = term.runes.length >= 3;
      final table = fragments ? 'search_fragments' : 'search_words';
      clauses.add(
        'token_$i AS MATERIALIZED (SELECT rowid FROM $table WHERE $table MATCH ${bind('"${term.replaceAll('"', '""')}"${fragments ? '' : '*'}')})',
      );
      clauses.add(
        """expanded_$i AS (SELECT rowid FROM token_$i UNION
        SELECT d.rowid FROM search_documents d INDEXED BY search_account
        WHERE d.account_id IN (SELECT CAST(a.record_id AS INTEGER) FROM search_documents a WHERE a.kind='account' AND a.rowid IN (SELECT rowid FROM token_$i)) AND d.kind IN ('transaction','goal','template') UNION
        SELECT d.rowid FROM search_documents d INDEXED BY search_category
        WHERE d.category_id IN (SELECT CAST(c.record_id AS INTEGER) FROM search_documents c WHERE c.kind='category' AND c.rowid IN (SELECT rowid FROM token_$i)) AND d.kind IN ('transaction','budget','template'))""",
      );
      intersections.add('SELECT rowid FROM expanded_$i');
    }
    final f = query.filters;
    final where = <String>[];
    if (f.kind != null) where.add('d.kind=${bind(f.kind!)}');
    if (f.accountId != null) where.add('d.account_id=${bind(f.accountId!)}');
    if (f.transactionType != null) {
      where.add('d.tx_type=${bind(f.transactionType!)}');
    }
    if (f.from != null) {
      where.add('d.date>=${bind(f.from!.millisecondsSinceEpoch ~/ 1000)}');
    }
    if (f.to != null) {
      where.add(
        'd.date<${bind(DateTime(f.to!.year, f.to!.month, f.to!.day + 1).millisecondsSinceEpoch ~/ 1000)}',
      );
    }
    if (f.currency != null) where.add('currency=${bind(f.currency!)}');
    if (f.minimum != null) {
      where.add('amount_key>=${bind(amountSearchKey(f.minimum!))}');
    }
    if (f.maximum != null) {
      where.add('amount_key<=${bind(amountSearchKey(f.maximum!))}');
    }
    final q = bind(normalized);
    const exactAmount =
        "coalesce(json_extract(td.payload,'\$.amount'),d.amount)";
    const currency =
        "coalesce(nullif(d.currency,''),json_extract(td.payload,'\$.currency'),a.currency,'')";
    final amountKey =
        "printf('%08d',length(CASE WHEN instr($exactAmount,'.')=0 THEN $exactAmount ELSE substr($exactAmount,1,instr($exactAmount,'.')-1) END)) || ':' || CASE WHEN instr($exactAmount,'.')=0 THEN $exactAmount || '.' ELSE rtrim($exactAmount,'0') END";
    final conditions = where
        .map(
          (w) => w
              .replaceFirst('amount_key', amountKey)
              .replaceFirst('currency=', '$currency='),
        )
        .toList();
    final needsMoney =
        f.currency != null || f.minimum != null || f.maximum != null;
    final rankExpr = f.newest ? '(0+0)' : 'rank';
    final cursorWhere = after == null
        ? ''
        : ' WHERE ($rankExpr,date * -1,rowid * -1)>(${bind(after.rank)},${bind(-after.date)},${bind(-after.rowid)})';
    final sql =
        '''WITH ${clauses.join(',')}, candidates AS (${intersections.join(' INTERSECT ')}), ranked AS (
      SELECT d.rowid,d.date,CASE WHEN d.title_norm=$q THEN 0 WHEN instr(d.title_norm,$q)=1 THEN 1 WHEN instr(d.title_norm,$q)>0 THEN 2 ELSE 3 END rank
      FROM candidates m JOIN search_documents d ON d.rowid=m.rowid
      ${needsMoney ? "LEFT JOIN accounts a ON a.id=d.account_id LEFT JOIN transaction_details td ON d.kind='transaction' AND td.transaction_id=CAST(d.record_id AS INTEGER)" : ''}
      WHERE NOT (d.kind='account' AND EXISTS(SELECT 1 FROM finance_records ar WHERE ar.collection='accountDetails' AND ar.id=d.record_id AND json_extract(ar.payload,'\$.archived')=1))
      ${conditions.isEmpty ? '' : 'AND ${conditions.join(' AND ')}'}
    ), page AS (SELECT * FROM ranked$cursorWhere ORDER BY $rankExpr,date DESC,rowid DESC LIMIT 51)
    SELECT d.kind,d.record_id,d.title,d.body,d.target,$exactAmount amount,$currency currency,p.rowid,p.rank,p.date,
      coalesce(a.name,'') account_name,coalesce(c.name,'') category_name
      FROM page p JOIN search_documents d ON d.rowid=p.rowid
      LEFT JOIN accounts a ON a.id=d.account_id LEFT JOIN categories c ON c.id=d.category_id
      LEFT JOIN transaction_details td ON d.kind='transaction' AND td.transaction_id=CAST(d.record_id AS INTEGER)
      ORDER BY ${f.newest ? '(0+0)' : 'p.rank'},p.date DESC,p.rowid DESC''';
    onQuery?.call(sql, variables);
    final rows = await db.customSelect(sql, variables: variables).get();
    final hits = rows
        .take(50)
        .map(
          (r) => SearchHit(
            kind: r.read('kind'),
            id: r.read('record_id'),
            title: r.read('title'),
            subtitle: [
              r.read<String>('body'),
              r.read<String>('account_name'),
              r.read<String>('category_name'),
            ].where((v) => v.isNotEmpty).join(' · '),
            currency: r.read('currency'),
            amount: r.read('amount'),
            target: r.read('target'),
            rowid: r.read('rowid'),
            rank: f.newest ? 0 : r.read('rank'),
            date: r.read('date'),
          ),
        )
        .toList();
    final last = hits.lastOrNull;
    return SearchPage(
      hits,
      rows.length > 50 && last != null
          ? SearchCursor(last.rank, last.date, last.rowid)
          : null,
    );
  }
}
