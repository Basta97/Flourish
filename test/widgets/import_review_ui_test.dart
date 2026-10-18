import 'dart:io';

import 'package:drift/native.dart';
import 'package:flourish/core/ai/ai_column_mapper.dart';
import 'package:flourish/core/finance/import/import_sources.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/core/theme/app_theme.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/providers/database_provider.dart';
import 'package:flourish/presentation/wealth/import_review_screen.dart';
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

  testWidgets('a Money Manager export is reviewed and imported', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.runAsync(() async {
      for (final a in await db.getAllAccounts()) {
        await (db.delete(db.accounts)..where((t) => t.id.equals(a.id))).go();
      }
    });
    final content = File(
      'test/fixtures/imports/money_manager.csv',
    ).readAsStringSync();
    final source = ImportSources.detect('money_manager.csv', content)!;
    final parsed = source.parse(
      content,
      options: const ImportOptions(defaultCurrency: 'EGP'),
    );

    Future<void> settle([int rounds = 10]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // Futures started by the widget run in the fake-async zone; pump while
    // awaiting the database so its transaction can finish.
    Future<T> drive<T>(Future<T> work) async {
      var done = false;
      late T result;
      work.then((v) {
        result = v;
        done = true;
      });
      for (var i = 0; i < 400 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
      }
      return result;
    }

    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => ImportReviewScreen(
                        parsed: parsed,
                        sourceName: source.name,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle();

    expect(find.text(source.name), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Categories not in Flourish'), findsOneWidget);
    expect(find.textContaining('Create “Lunch”'), findsOneWidget);
    final button = find.byWidgetPredicate(
      (w) => w is FilledButton && w.onPressed != null,
    );
    final rows = parsed.rows.length;
    final transfers = parsed.rows.where((r) => r.type == 'transfer').length;
    expect(transfers, 1);
    expect(find.textContaining('Import $rows transactions'), findsOneWidget);
    await tester.tap(button.last);
    await settle(14);

    final count = (await drive(db.getAllTransactions())).length;
    // A transfer is booked as two legs.
    expect(count, rows + transfers);
    expect(find.textContaining('Imported $rows transactions'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await drive(db.close());
  });

  group('AiColumnMapper.parse', () {
    test('keeps valid, unique indexes and a date format that reads the sample', () {
      final m = AiColumnMapper.parse(
        {
          'columns': {'date': 0, 'amount': 2, 'note': 2, 'account': 9},
          'date_format': 'dd.MM.yyyy',
          'decimal_separator': ',',
          'signed_amounts': true,
        },
        4,
        [
          ['03.02.2024', 'x', '-12,50', 'EUR'],
        ],
      );
      expect(m.columns, {'date': 0, 'amount': 2});
      expect(m.dateFormat, 'dd.MM.yyyy');
      expect(m.decimalSeparator, ',');
      expect(m.signedAmounts, isTrue);
    });

    test('a date format that does not read the sample is dropped', () {
      final m = AiColumnMapper.parse(
        {
          'columns': {'date': 0},
          'date_format': 'MM/dd/yyyy',
        },
        1,
        [
          ['31/01/2024'],
        ],
      );
      expect(m.dateFormat, isNull);
    });
  });
}
