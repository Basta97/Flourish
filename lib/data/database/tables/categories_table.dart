import 'package:drift/drift.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  TextColumn get type => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Set for categories the ledger books automatically (see
  /// SystemCategories); survives renaming.
  TextColumn get systemKey => text().nullable()();

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('income', 'expense'))",
  ];
}
