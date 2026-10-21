import 'package:flourish/core/theme/app_theme.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/l10n/app_localizations.dart';
import 'package:flourish/presentation/categories/categories_management_screen.dart';
import 'package:flourish/presentation/providers/category_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Category _category(int id, String name, String type, {String? systemKey}) {
  return Category(
    id: id,
    name: name,
    icon: 'more_horiz',
    color: 0xFF4FD1A1,
    type: type,
    isDefault: false,
    sortOrder: id,
    systemKey: systemKey,
  );
}

void main() {
  testWidgets('manage categories page renders without errors', (tester) async {
    final categories = [
      _category(1, 'Groceries', 'expense'),
      _category(2, 'Rent', 'expense'),
      _category(3, 'Salary', 'income'),
      _category(4, 'Other', 'expense', systemKey: 'other_expense'),
      _category(5, 'Transfer Out', 'expense', systemKey: 'transfer_out'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value(categories)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CategoriesManagementScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Transfer Out'), findsNothing);
  });

  testWidgets('add sheet rejects a name already used by the same type', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final categories = [_category(1, 'Groceries', 'expense')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value(categories)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CategoriesManagementScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '  groceries ');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(
      find.text('A category with this name already exists'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
