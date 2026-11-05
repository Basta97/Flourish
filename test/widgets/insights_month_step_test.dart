import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/core/theme/app_theme.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/presentation/insights/spending_stats_view.dart';
import 'package:flourish/presentation/providers/database_provider.dart';
import 'package:flourish/shared/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'default_currency': 'EGP'});
    await PreferencesService.init();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // Stepping to another month used to swap the page for skeletons and replay
  // every entrance, which read as a slow tap.
  testWidgets('stepping months keeps the report on screen', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.runAsync(() async {
      final bank = await db.insertAccount(
        AccountsCompanion.insert(
          name: 'Bank',
          type: 'bank',
          color: 0,
          icon: 'account_balance',
          currency: const Value('EGP'),
          balance: const Value(5000),
        ),
      );
      final category = (await db.getAllCategories()).first;
      await db.insertTransaction(
        TransactionsCompanion.insert(
          accountId: bank,
          categoryId: category.id,
          amount: 250,
          type: 'expense',
          transactionDate: DateTime.now(),
        ),
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: SpendingStatsView()),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Daily spending'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pump();
    expect(find.byType(ShimmerLoading), findsNothing);
    expect(find.text('Daily spending'), findsOneWidget);

    await settle(tester);
    expect(tester.takeException(), isNull);

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
