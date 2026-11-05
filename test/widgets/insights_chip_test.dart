import 'package:drift/native.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_theme.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/presentation/insights/insights_screen.dart';
import 'package:flourish/presentation/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'default_currency': 'EGP'});
    await PreferencesService.init();
    FlutterSecureStorage.setMockInitialValues({});
  });

  Color chipColor(WidgetTester tester, String label) {
    final box = tester.widget<Container>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .first,
    );
    return (box.decoration! as ShapeDecoration).color!;
  }

  // The chip also must not be covered by an ink ripple, which used to fade
  // over the new colour for a quarter second.
  testWidgets('tapped chip lights up on the next frame', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final theme = AppTheme.light();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: theme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const InsightsScreen(),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    final accent = theme.extension<FlourishPalette>()!.accent;
    expect(chipColor(tester, 'Spending'), accent);

    await tester.tap(find.text('Budgets'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(chipColor(tester, 'Budgets'), accent);
    expect(chipColor(tester, 'Spending'), isNot(accent));
    expect(
      find.ancestor(of: find.text('Budgets'), matching: find.byType(InkWell)),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
    var closed = false;
    db.close().whenComplete(() => closed = true);
    for (var i = 0; i < 400 && !closed; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
    }
  });
}
