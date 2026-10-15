import '../models/account.dart';

/// Repository abstraction for account operations.
abstract class AccountRepository {
  Future<List<Account>> getAll();
  Stream<List<Account>> watchAll();
  Future<Account?> getById(int id);
  Future<int> insert(Account account);
  Future<bool> update(Account account);
  Future<int> delete(int id);
  Future<double> getNetWorth();
}
