import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:http/http.dart' as http;
import 'package:flourish/app.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/core/finance/market_data_service.dart';
import 'package:flourish/core/search/search_models.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/data/search/search_repository.dart';
import 'package:flourish/presentation/providers/database_provider.dart';
import 'package:flourish/presentation/providers/finance_providers.dart';
import 'package:flourish/presentation/providers/locale_providers.dart';
import 'package:flourish/presentation/search/search_screen.dart';
import 'package:flourish/presentation/currencies/exchange_rates_screen.dart';
import 'package:flourish/presentation/transactions/widgets/edit_transaction_sheet.dart';
import 'package:flourish/shared/widgets/global_search_button.dart';
import '../test/support/search_benchmark.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'global search → editable result → filters → converter → Arabic privacy',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'app_locale': 'en',
        'app_lock_enabled': false,
        'default_currency': 'EGP',
      });
      await PreferencesService.init();
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final directory = await Directory.systemTemp.createTemp(
        'flourish-search-ui',
      );
      final db = AppDatabase.forTesting(
        NativeDatabase.createInBackground(File('${directory.path}/qa.db')),
      );
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final ledger = container.read(financialLedgerProvider),
          store = container.read(financeStoreProvider);
      final account = await db.insertAccount(
        AccountsCompanion.insert(
          name: 'QA orchard wallet',
          type: 'cash',
          currency: const Value('EGP'),
          color: 0,
          icon: 'wallet',
        ),
      );
      final categories = await db.getAllCategories();
      final expense = categories
              .firstWhere((c) => c.name == 'Food & Drinks')
              .id,
          income = categories.firstWhere((c) => c.type == 'income').id;
      final id = await ledger.recordCash(
        accountId: account,
        categoryId: expense,
        amount: Amount('25.5'),
        type: 'expense',
        note: 'QA orchard coffee',
      );
      await ledger.recordCash(
        accountId: account,
        categoryId: income,
        amount: Amount('50'),
        type: 'income',
        note: 'QA orchard salary',
      );
      final now = DateTime.now();
      for (final manual in [false, true]) {
        await container
            .read(marketDataProvider)
            .save(
              'fx',
              MarketObservation(
                key: 'USD/EGP',
                currency: 'EGP',
                source: manual
                    ? 'Manual reference override'
                    : 'Frankfurter reference',
                value: Amount(manual ? '55' : '50'),
                effectiveAt: now,
                retrievedAt: now,
                manual: manual,
              ),
            );
      }
      await container.read(searchRepositoryProvider).prepare();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FlourishApp(),
        ),
      );
      await tester.pumpAndSettle();
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byType(GlobalSearchButton).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'orchard coffee');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.byKey(ValueKey('transaction:$id')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('transaction:$id')));
      await tester.pumpAndSettle();
      expect(find.byType(EditTransactionSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(EditTransactionSheet))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Transaction filters'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate((w) => w is DropdownButtonFormField<String>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Income').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'orchard');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.byKey(ValueKey('transaction:$id')), findsNothing);
      expect(find.textContaining('QA orchard salary'), findsWidgets);
      // Clear filters and use the same search to reach a feature.
      await tester.tap(find.text('All').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'exchange');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('feature:2')));
      await tester.pumpAndSettle();
      expect(find.byType(ExchangeRatesScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '2');
      await tester.pumpAndSettle();
      expect(find.text('EGP 110.00'), findsOneWidget);
      expect(find.textContaining('Provider reference'), findsWidgets);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Favorite pairs'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favorite pairs'));
      await tester.pumpAndSettle();
      expect((await store.list('fxFavorites')).single['pair'], 'USD/EGP');
      await container.read(hideAmountsProvider.notifier).toggle();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 700));
      await tester.pumpAndSettle();
      expect(find.text('••••'), findsOneWidget);
      await container.read(appLocaleProvider.notifier).set(const Locale('ar'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 700));
      await tester.pumpAndSettle();
      expect(find.text('أسعار الصرف'), findsOneWidget);
      expect(find.text('محول العملات'), findsOneWidget);
      binding.reportData = {
        'uiFlow': 'passed',
        'database': 'isolated temporary file',
      };
      // Preserve screenshots in the test runner output without accessing personal data.
      final screenshot = await binding.takeScreenshot('search-currency-arabic');
      final screenshotPath =
          '${Directory.systemTemp.path}/flourish-currency-arabic.png';
      if (const bool.fromEnvironment('QA_CAPTURE')) {
        await File(screenshotPath).writeAsBytes(screenshot);
        debugPrint('QA_SCREENSHOT $screenshotPath');
        await Future<void>.delayed(const Duration(seconds: 20));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      container.dispose();
      await db.close();
      await directory.delete(recursive: true);
    },
  );
  testWidgets(
    'native SQLite capability and 100k search benchmark',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp(
        'flourish-search-perf',
      );
      final db = AppDatabase.forTesting(
        NativeDatabase.createInBackground(File('${directory.path}/perf.db')),
      );
      final result = await benchmarkSearch(db);
      // ignore: avoid_print
      print('DEVICE_SEARCH_BENCHMARK $result');
      binding.reportData = {...binding.reportData ?? {}, 'benchmark': result};
      SharedPreferences.setMockInitialValues({
        'app_locale': 'en',
        'app_lock_enabled': false,
        'default_currency': 'EGP',
      });
      await PreferencesService.init();
      Duration? firstFrame;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SearchScreen(
              onResultsVisible: (elapsed) => firstFrame = elapsed,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final visible = Stopwatch()..start();
      await tester.enterText(find.byType(TextField).first, 'coffee');
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      visible.stop();
      expect(find.byType(ListTile), findsWidgets);
      debugPrint(
        'SEARCH_FIRST_VISIBLE_MS ${firstFrame?.inMilliseconds}, INPUT_TO_SETTLED_MS ${visible.elapsedMilliseconds}',
      );
      expect(firstFrame, isNotNull);
      binding.reportData = {
        ...binding.reportData ?? {},
        'firstVisibleMs': firstFrame!.inMilliseconds,
      };
      final warmFrames = <int>[];
      for (final text in ['grocery', 'coffee', 'school', 'coffee', 'grocery']) {
        firstFrame = null;
        await tester.enterText(find.byType(TextField).first, text);
        await tester.pumpAndSettle(const Duration(milliseconds: 16));
        expect(firstFrame, isNotNull);
        warmFrames.add(firstFrame!.inMilliseconds);
      }
      debugPrint('SEARCH_WARM_VISIBLE_MS $warmFrames');
      binding.reportData = {
        ...binding.reportData ?? {},
        'warmVisibleMs': warmFrames,
      };
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final page = await SearchRepository(
        db,
      ).search(const SearchQuery('coffee'));
      expect(page.hits, isNotEmpty);
      await db.close();
      await directory.delete(recursive: true);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
  testWidgets('live Frankfurter catalog and requested pair', (tester) async {
    final client = http.Client();
    try {
      final provider = FrankfurterProvider(client);
      final currencies = await provider.currencies();
      expect(currencies.any((c) => c.code == 'EGP'), true);
      expect(currencies.length, greaterThan(100));
      final rates = await provider.fetch('USD', {'EGP', 'BRL'});
      expect(rates.any((r) => r.key == 'USD/EGP'), true);
      expect(rates.any((r) => r.key == 'USD/BRL'), true);
      // ignore: avoid_print
      print(
        'LIVE_FX ${currencies.length} currencies, ${rates.map((r) => '${r.key}=${r.value} (${r.effectiveAt})').join(', ')}',
      );
    } finally {
      client.close();
    }
  });
}
