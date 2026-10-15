/// Immutable domain model for a savings goal.
class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
    required this.accountId,
    required this.color,
    required this.icon,
    required this.createdAt,
  });

  final int id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime deadline;
  final int accountId;
  final int color;
  final String icon;
  final DateTime createdAt;

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  bool get isCompleted => currentAmount >= targetAmount;

  Goal copyWith({
    int? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    int? accountId,
    int? color,
    String? icon,
    DateTime? createdAt,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      accountId: accountId ?? this.accountId,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Goal && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Goal(id: $id, name: $name, target: $targetAmount, current: $currentAmount)';
}
