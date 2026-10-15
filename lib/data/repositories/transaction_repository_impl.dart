import '../../core/finance/financial_ledger_service.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/database/database.dart' as drift;
import '../../domain/models/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(this._db);

  final drift.AppDatabase _db;
  late final FinancialLedgerService _ledger = FinancialLedgerService(_db);

  Transaction _map(drift.Transaction t) => Transaction(
    id: t.id,
    accountId: t.accountId,
    categoryId: t.categoryId,
    amount: t.amount,
    type: t.type,
    note: t.note,
    transactionDate: t.transactionDate,
    linkedTransactionId: t.linkedTransactionId,
    createdAt: t.createdAt,
  );

  drift.TransactionsCompanion _toCompanion(Transaction t) =>
      drift.TransactionsCompanion(
        id: t.id == 0 ? const Value.absent() : Value(t.id),
        accountId: Value(t.accountId),
        categoryId: Value(t.categoryId),
        amount: Value(t.amount),
        type: Value(t.type),
        note: Value(t.note),
        transactionDate: Value(t.transactionDate),
        linkedTransactionId: Value(t.linkedTransactionId),
        createdAt: Value(t.createdAt),
      );

  @override
  Future<List<Transaction>> getAll() async {
    final rows = await _db.getAllTransactions();
    return rows.map(_map).toList();
  }

  @override
  Stream<List<Transaction>> watchAll() {
    return _db.watchAllTransactions().map((rows) => rows.map(_map).toList());
  }

  @override
  Future<List<Transaction>> getByAccount(int accountId) async {
    final rows = await _db.getTransactionsByAccount(accountId);
    return rows.map(_map).toList();
  }

  @override
  Stream<List<Transaction>> watchByAccount(int accountId) {
    return _db
        .watchTransactionsByAccount(accountId)
        .map((rows) => rows.map(_map).toList());
  }

  @override
  Future<Transaction?> getById(int id) async {
    final row = await _db.getTransactionById(id);
    return row == null ? null : _map(row);
  }

  @override
  Future<void> insert(Transaction transaction) async {
    await _ledger.insertTransactionAndUpdateBalance(_toCompanion(transaction));
  }

  @override
  Future<void> update(Transaction transaction) async {
    await _ledger.updateTransactionAndUpdateBalance(
      drift.Transaction(
        id: transaction.id,
        accountId: transaction.accountId,
        categoryId: transaction.categoryId,
        amount: transaction.amount,
        type: transaction.type,
        note: transaction.note,
        transactionDate: transaction.transactionDate,
        linkedTransactionId: transaction.linkedTransactionId,
        createdAt: transaction.createdAt,
      ),
    );
  }

  @override
  Future<void> delete(int id) async {
    await _ledger.deleteTransactionAndUpdateBalance(id);
  }

  @override
  Future<List<Transaction>> search(String query) async {
    final rows = await _db.searchTransactions(query);
    return rows.map(_map).toList();
  }

  @override
  Future<void> transfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    double? destinationAmount,
    double fee = 0,
    String? note,
    DateTime? date,
  }) async {
    await _ledger.transferBetweenAccounts(
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amount: amount,
      destinationAmount: destinationAmount,
      fee: fee,
      note: note,
      date: date,
    );
  }
}
