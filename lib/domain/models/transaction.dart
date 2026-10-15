/// Immutable domain model for a financial transaction.
class Transaction {
  const Transaction({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    required this.type,
    this.note,
    required this.transactionDate,
    this.linkedTransactionId,
    required this.createdAt,
  });

  final int id;
  final int accountId;
  final int categoryId;
  final double amount;
  final String type;
  final String? note;
  final DateTime transactionDate;
  final int? linkedTransactionId;
  final DateTime createdAt;

  /// Whether this transaction is part of a transfer pair.
  bool get isTransfer => linkedTransactionId != null;

  Transaction copyWith({
    int? id,
    int? accountId,
    int? categoryId,
    double? amount,
    String? type,
    String? note,
    DateTime? transactionDate,
    int? linkedTransactionId,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      note: note ?? this.note,
      transactionDate: transactionDate ?? this.transactionDate,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transaction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Transaction(id: $id, amount: $amount, type: $type, accountId: $accountId)';
}
