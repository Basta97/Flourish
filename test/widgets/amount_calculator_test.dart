import 'package:flourish/core/theme/app_theme.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/shared/widgets/amount_calculator_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> showCalculator(
    WidgetTester tester,
    TextEditingController controller, {
    ValueChanged<String>? onChanged,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(960, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.3,
          maxScaleFactor: 1.3,
          child: child!,
        ),
        home: Scaffold(
          body: TextField(
            controller: controller,
            decoration: InputDecoration(
              suffixIcon: AmountCalculatorButton(
                controller: controller,
                decimalPlaces: 2,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calculate_outlined));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey('calculator-$key')));
    await tester.pumpAndSettle();
  }

  testWidgets('equals updates the amount and invokes normal form changes', (
    tester,
  ) async {
    final controller = TextEditingController(text: '12.50');
    addTearDown(controller.dispose);
    String? changed;
    await showCalculator(tester, controller, onChanged: (v) => changed = v);
    for (final key in ['+', '7', '.', '5']) {
      await press(tester, key);
    }
    expect(controller.text, '12.50');
    await press(tester, '=');
    expect(controller.text, '20');
    expect(changed, '20');
    expect(find.byKey(const ValueKey('calculator-expression')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('errors retain the amount and can be corrected or cancelled', (
    tester,
  ) async {
    final controller = TextEditingController(text: '50');
    addTearDown(controller.dispose);
    await showCalculator(tester, controller);
    await press(tester, '÷');
    await press(tester, '0');
    await press(tester, '=');
    expect(find.text('Cannot divide by zero.'), findsOneWidget);
    expect(controller.text, '50');
    await press(tester, '⌫');
    await press(tester, '2');
    await press(tester, '=');
    expect(controller.text, '25');
    await tester.tap(find.byIcon(Icons.calculate_outlined));
    await tester.pumpAndSettle();
    await press(tester, 'AC');
    await press(tester, '9');
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.text, '25');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic keypad fits a narrow screen with larger text', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await showCalculator(tester, controller, locale: const Locale('ar'));
    expect(find.text('الآلة الحاسبة'), findsOneWidget);
    for (final key in ['(', '1', '+', '2', ')', '×', '3', '=']) {
      await press(tester, key);
    }
    expect(controller.text, '9');
    expect(tester.takeException(), isNull);
  });
}
