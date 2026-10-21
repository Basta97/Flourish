import 'package:flourish/core/theme/app_theme.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/l10n/app_localizations.dart';
import 'package:flourish/presentation/transactions/widgets/transaction_form_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Category _category(int id, String name) {
  return Category(
    id: id,
    name: name,
    icon: 'more_horiz',
    color: 0xFF4FD1A1,
    type: 'expense',
    isDefault: false,
    sortOrder: id,
  );
}

void main() {
  Future<void> pumpGrid(WidgetTester tester, {VoidCallback? onAdd}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CategoryGrid(
            categories: [_category(1, 'Groceries')],
            selectedId: 1,
            onSelected: (_) {},
            onAdd: onAdd,
          ),
        ),
      ),
    );
  }

  testWidgets('shows a trailing New tile that calls onAdd', (tester) async {
    var added = 0;
    await pumpGrid(tester, onAdd: () => added++);

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    await tester.tap(find.text('New'));
    expect(added, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides the New tile when onAdd is not given', (tester) async {
    await pumpGrid(tester);

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('New'), findsNothing);
  });
}
