/// Immutable domain model for a recurring transaction.
class RecurringTransaction {
  const RecurringTransaction({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    required this.type,
    this.note,
    required this.frequency,
    required this.nextDate,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final int accountId;
  final int categoryId;
  final double amount;
  final String type;
  final String? note;
  final String frequency;
  final DateTime nextDate;
  final bool isActive;
  final DateTime createdAt;

  RecurringTransaction copyWith({
    int? id,
    int? accountId,
    int? categoryId,
    double? amount,
    String? type,
    String? note,
    String? frequency,
    DateTime? nextDate,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      note: note ?? this.note,
      frequency: frequency ?? this.frequency,
      nextDate: nextDate ?? this.nextDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'RecurringTransaction(id: $id, amount: $amount, frequency: $frequency, active: $isActive)';
}
