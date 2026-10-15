/// Immutable domain model for a spending budget.
class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.period,
    required this.startDate,
    required this.createdAt,
  });

  final int id;
  final int categoryId;
  final double amount;
  final String period;
  final DateTime startDate;
  final DateTime createdAt;

  Budget copyWith({
    int? id,
    int? categoryId,
    double? amount,
    String? period,
    DateTime? startDate,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Budget && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Budget(id: $id, categoryId: $categoryId, amount: $amount, period: $period)';
}
