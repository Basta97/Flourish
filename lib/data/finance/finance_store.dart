import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../../domain/finance/models.dart';

/// Versioned local financial records. Exact values are persisted as decimal text.
class FinanceStore {
  final AppDatabase db;
  FinanceStore(this.db);
  static const tables = [
    'finance_records',
    'exact_balances',
    'transaction_details',
  ];
  static Future<void> create(AppDatabase db) async {
    await db.customStatement('''CREATE TABLE IF NOT EXISTS finance_records (
      collection TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL,
      PRIMARY KEY(collection, id))''');
    await db.customStatement('''CREATE TABLE IF NOT EXISTS exact_balances (
      account_id INTEGER PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
      balance TEXT NOT NULL, opening TEXT NOT NULL)''');
    await db.customStatement('''CREATE TABLE IF NOT EXISTS transaction_details (
      transaction_id INTEGER PRIMARY KEY REFERENCES transactions(id) ON DELETE CASCADE,
      payload TEXT NOT NULL)''');
    for (final account in await db.getAllAccounts()) {
      final history = await db.getTransactionsByAccount(account.id);
      var impact = Amount.zero;
      for (final t in history) {
        final sign = (t.type == 'income') != (account.type == 'credit')
            ? 1
            : -1;
        impact += Amount.fromNum(t.amount) * Amount('$sign');
      }
      final balance = Amount.fromNum(account.balance);
      await db.customStatement(
        'INSERT OR IGNORE INTO exact_balances VALUES (?, ?, ?)',
        [account.id, '$balance', '${balance - impact}'],
      );
    }
  }

  Future<List<Json>> list(String collection) async =>
      (await db
              .customSelect(
                'SELECT payload FROM finance_records WHERE collection = ? ORDER BY id',
                variables: [Variable(collection)],
              )
              .get())
          .map((r) => jsonDecode(r.read<String>('payload')) as Json)
          .toList();
  Future<Json?> get(String collection, String id) async {
    final rows = await db
        .customSelect(
          'SELECT payload FROM finance_records WHERE collection = ? AND id = ?',
          variables: [Variable(collection), Variable(id)],
        )
        .get();
    return rows.isEmpty
        ? null
        : jsonDecode(rows.first.read<String>('payload')) as Json;
  }

  Future<void> put(
    String collection,
    String id,
    Json payload, {
    bool notify = true,
  }) async {
    if (collection == 'activity') {
      payload = {'sequence': DateTime.now().microsecondsSinceEpoch, ...payload};
    }
    await db.customStatement(
      'INSERT INTO finance_records VALUES (?, ?, ?) ON CONFLICT(collection,id) DO UPDATE SET payload=excluded.payload',
      [collection, id, jsonEncode(payload)],
    );
    if (notify) db.notifyFinanceChanged();
  }

  Future<void> remove(String collection, String id) async {
    await db.customStatement(
      'DELETE FROM finance_records WHERE collection=? AND id=?',
      [collection, id],
    );
    db.notifyFinanceChanged();
  }

  Future<Json?> transactionDetails(int id) async {
    final rows = await db
        .customSelect(
          'SELECT payload FROM transaction_details WHERE transaction_id=?',
          variables: [Variable(id)],
        )
        .get();
    return rows.isEmpty
        ? null
        : jsonDecode(rows.first.read<String>('payload')) as Json;
  }

  /// Details for many transactions in a few queries instead of one each.
  Future<Map<int, Json>> transactionDetailsFor(Iterable<int> ids) async {
    final out = <int, Json>{};
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 500) {
      final chunk = list.sublist(i, (i + 500).clamp(0, list.length));
      final rows = await db
          .customSelect(
            'SELECT transaction_id, payload FROM transaction_details '
            'WHERE transaction_id IN (${List.filled(chunk.length, '?').join(',')})',
            variables: [for (final id in chunk) Variable(id)],
          )
          .get();
      for (final r in rows) {
        out[r.read<int>('transaction_id')] =
            jsonDecode(r.read<String>('payload')) as Json;
      }
    }
    return out;
  }

  Future<void> setTransactionDetails(
    int id,
    Json payload,
  ) => db.customStatement(
    'INSERT INTO transaction_details VALUES (?, ?) ON CONFLICT(transaction_id) DO UPDATE SET payload=excluded.payload',
    [id, jsonEncode(payload)],
  );
  Future<Amount> balance(int id) async {
    final rows = await db
        .customSelect(
          'SELECT balance FROM exact_balances WHERE account_id=?',
          variables: [Variable(id)],
        )
        .get();
    if (rows.isNotEmpty) return amountOf(rows.first.read<String>('balance'));
    final a = await db.getAccountById(id);
    if (a == null) throw StateError('Account no longer exists');
    return Amount.fromNum(a.balance);
  }

  Future<void> changeBalance(int id, Amount delta) async {
    final current = await balance(id);
    final updated = current + delta;
    await db.customStatement(
      'INSERT INTO exact_balances VALUES (?, ?, ?) ON CONFLICT(account_id) DO UPDATE SET balance=excluded.balance',
      [id, '$updated', '$current'],
    );
    await (db.update(db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(balance: Value(updated.toDouble())),
    );
    db.notifyFinanceChanged();
  }
}

class PortfolioRepository {
  final FinanceStore store;
  PortfolioRepository(this.store);
  Future<List<Holding>> getAll() async =>
      (await store.list('holdings')).map(Holding.fromJson).toList();
  Future<Holding?> get(String id) async {
    final j = await store.get('holdings', id);
    return j == null ? null : Holding.fromJson(j);
  }

  Future<void> save(Holding holding) =>
      store.put('holdings', holding.id, holding.toJson());
  Future<List<Json>> activity(String id) async =>
      (await store.list('activity')).where((a) => a['holdingId'] == id).toList()
        ..sort((a, b) => (b['date'] as String).compareTo(a['date']));
}

class ContractRepository {
  final FinanceStore store;
  ContractRepository(this.store);
  Future<List<FinanceContract>> getAll() async =>
      (await store.list('contracts')).map(FinanceContract.fromJson).toList();
  Future<List<ScheduledPayment>> payments(String id) async =>
      (await store.list('payments'))
          .map(ScheduledPayment.fromJson)
          .where((p) => p.contractId == id)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  Future<void> save(FinanceContract contract) =>
      store.put('contracts', contract.id, contract.toJson());
}
