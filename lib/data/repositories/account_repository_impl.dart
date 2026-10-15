import 'package:drift/drift.dart' hide Column;
import '../../data/database/database.dart' as drift;
import '../../domain/models/account.dart';
import '../../domain/repositories/account_repository.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl(this._db);

  final drift.AppDatabase _db;

  Account _map(drift.Account a) => Account(
    id: a.id,
    name: a.name,
    type: a.type,
    balance: a.balance,
    currency: a.currency,
    color: a.color,
    icon: a.icon,
    createdAt: a.createdAt,
  );

  drift.AccountsCompanion _toCompanion(Account a) => drift.AccountsCompanion(
    id: a.id == 0 ? const Value.absent() : Value(a.id),
    name: Value(a.name),
    type: Value(a.type),
    balance: Value(a.balance),
    currency: Value(a.currency),
    color: Value(a.color),
    icon: Value(a.icon),
    createdAt: Value(a.createdAt),
  );

  @override
  Future<List<Account>> getAll() async {
    final rows = await _db.getAllAccounts();
    return rows.map(_map).toList();
  }

  @override
  Stream<List<Account>> watchAll() {
    return _db.watchAllAccounts().map((rows) => rows.map(_map).toList());
  }

  @override
  Future<Account?> getById(int id) async {
    final row = await _db.getAccountById(id);
    return row == null ? null : _map(row);
  }

  @override
  Future<int> insert(Account account) =>
      _db.insertAccount(_toCompanion(account));

  @override
  Future<bool> update(Account account) => _db.updateAccount(
    drift.Account(
      id: account.id,
      name: account.name,
      type: account.type,
      balance: account.balance,
      currency: account.currency,
      color: account.color,
      icon: account.icon,
      createdAt: account.createdAt,
    ),
  );

  @override
  Future<int> delete(int id) => _db.deleteAccount(id);

  @override
  Future<double> getNetWorth() => _db.getNetWorth();
}
