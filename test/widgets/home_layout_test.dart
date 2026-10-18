import 'package:drift/native.dart';
import 'package:flourish/core/router/app_router.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/core/theme/app_theme.dart';
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/presentation/dashboard/dashboard_screen.dart';
import 'package:flourish/presentation/dashboard/widgets/motivation_card.dart';
import 'package:flourish/presentation/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'default_currency': 'EGP'});
    await PreferencesService.init();
  });

  tearDown(() {
    CurrencyFormatter.hidden = false;
    CurrencyFormatter.rtl = false;
    Intl.defaultLocale = null;
  });

  void phone(WidgetTester tester) {
    // iPhone 17-class screen with notch and home-indicator insets.
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 186, bottom: 102);
    tester.view.viewPadding = const FakeViewPadding(top: 186, bottom: 102);
    addTearDown(tester.view.reset);
  }

  /// Alternates real time (for the database) and fake time (for widgets).
  Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// Unmounts the screen, then closes the database outside fake time.
  Future<void> finish(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox());
    var done = false;
    db.close().whenComplete(() => done = true);
    for (var i = 0; i < 400 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
    }
  }

  Future<AppDatabase> pumpHome(WidgetTester tester, {Locale? locale}) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const DashboardScreen(),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('home starts right under the status bar', (tester) async {
    phone(tester);
    final db = await pumpHome(tester);
    final greeting = find.textContaining(RegExp('^Good '));
    expect(greeting, findsOneWidget);
    // Status bar is 62pt; the greeting sits within a normal header below it,
    // not a third of the way down the screen as the large app bar had it.
    expect(tester.getTopLeft(greeting).dy, lessThan(130));
    expect(tester.getTopLeft(greeting).dx, 20);
    expect(find.byType(MotivationCard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester, db);
  });

  testWidgets('the eye button hides and shows amounts', (tester) async {
    phone(tester);
    final db = await pumpHome(tester);
    expect(find.byTooltip('Hide amounts'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide amounts'));
    await settle(tester, rounds: 2);
    expect(CurrencyFormatter.hidden, isFalse); // Set by FlourishApp only.
    expect(find.byTooltip('Show amounts'), findsOneWidget);
    expect(PreferencesService.getBool('hide_amounts'), isTrue);
    await tester.tap(find.byTooltip('Show amounts'));
    await settle(tester, rounds: 2);
    expect(PreferencesService.getBool('hide_amounts'), isFalse);
    await finish(tester, db);
  });

  testWidgets('home lays out right to left in Arabic', (tester) async {
    phone(tester);
    final db = await pumpHome(tester, locale: const Locale('ar'));
    expect(
      find.text('مساء الخير').evaluate().isNotEmpty ||
          find.text('صباح الخير').evaluate().isNotEmpty ||
          find.text('تصبح على خير').evaluate().isNotEmpty,
      isTrue,
    );
    final context = tester.element(find.byType(DashboardScreen));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(find.text('النشاط الأخير'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester, db);
  });

  test('privacy mode masks every amount', () {
    CurrencyFormatter.hidden = true;
    expect(CurrencyFormatter.format(1234.5, currency: 'EGP'), 'EGP ••••');
    expect(CurrencyFormatter.formatCompact(99999, currency: 'USD'), r'$••••');
  });

  test('amounts keep Latin digits and a left-to-right mark in Arabic', () {
    Intl.defaultLocale = 'ar';
    CurrencyFormatter.rtl = true;
    expect(
      CurrencyFormatter.format(-1234.5, currency: 'EGP'),
      '‎-EGP 1,234.50',
    );
  });

  testWidgets('the Add button asks which kind of entry to add', (tester) async {
    phone(tester);
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          builder: (context, state, child) => ScaffoldWithNavBar(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const Center(child: Text('home')),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.bySemanticsLabel('Add')));
    await tester.pumpAndSettle();
    for (final label in ['Expense', 'Income', 'Transfer', 'Scan or import']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // Tapping outside closes it without opening a form.
    await tester.tapAt(const Offset(200, 200));
    await tester.pumpAndSettle();
    expect(find.text('Scan or import'), findsNothing);
  });
}
