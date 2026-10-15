import '../models/transaction.dart';

/// Repository abstraction for transaction operations.
abstract class TransactionRepository {
  Future<List<Transaction>> getAll();
  Stream<List<Transaction>> watchAll();
  Future<List<Transaction>> getByAccount(int accountId);
  Stream<List<Transaction>> watchByAccount(int accountId);
  Future<Transaction?> getById(int id);
  Future<void> insert(Transaction transaction);
  Future<void> update(Transaction transaction);
  Future<void> delete(int id);
  Future<List<Transaction>> search(String query);
  Future<void> transfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    double? destinationAmount,
    double fee = 0,
    String? note,
    DateTime? date,
  });
}
