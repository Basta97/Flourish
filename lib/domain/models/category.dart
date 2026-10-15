/// Immutable domain model for a transaction category.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    required this.isDefault,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final String icon;
  final int color;
  final String type;
  final bool isDefault;
  final int sortOrder;

  Category copyWith({
    int? id,
    String? name,
    String? icon,
    int? color,
    String? type,
    bool? isDefault,
    int? sortOrder,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Category(id: $id, name: $name, type: $type)';
}
