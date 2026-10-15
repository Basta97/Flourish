import 'package:drift/drift.dart';
import 'categories_table.dart';

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.cascade)();
  RealColumn get amount => real()();
  TextColumn get period => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    "CHECK (period IN ('weekly', 'monthly', 'yearly'))",
  ];
}
