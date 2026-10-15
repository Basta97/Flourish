/// Immutable domain model for a financial account.
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.currency,
    required this.color,
    required this.icon,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String type;
  final double balance;
  final String currency;
  final int color;
  final String icon;
  final DateTime createdAt;

  Account copyWith({
    int? id,
    String? name,
    String? type,
    double? balance,
    String? currency,
    int? color,
    String? icon,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Account && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Account(id: $id, name: $name, type: $type, balance: $balance)';
}
