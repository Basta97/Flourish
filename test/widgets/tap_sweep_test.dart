import 'dart:io';

import 'package:drift/native.dart';
import 'package:flourish/core/router/app_router.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/core/theme/app_theme.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/presentation/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Taps each control on each page, one per fresh app, and reports any
/// framework error. Exploratory: run with SWEEP_DB and TAP_SWEEP=1.
void main() {
  final source = Platform.environment['SWEEP_DB'];
  final enabled = Platform.environment['TAP_SWEEP'] == '1';
  final only = Platform.environment['TAP_PAGE'];
  const pages = [
    '/dashboard',
    '/transactions',
    '/accounts',
    '/insights?tab=spending',
    '/insights?tab=budgets',
    '/insights?tab=goals',
    '/insights?tab=holdings',
    '/insights?tab=obligations',
    '/settings',
    '/settings/detection',
    '/categories/manage',
    '/recurring',
    '/inbox',
    '/catch-up',
    '/payment-methods',
    '/templates',
    '/exchange-rates',
    '/smart-import',
  ];

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({
      'default_currency': 'EGP',
      'setup_done': true,
    });
    await PreferencesService.init();
    FlutterSecureStorage.setMockInitialValues({});
  });

  AppDatabase open() {
    if (source == null) return AppDatabase.forTesting(NativeDatabase.memory());
    final copy = File(
      '${Directory.systemTemp.createTempSync('tap').path}/f.db',
    );
    File(source).copySync(copy.path);
    for (final suffix in ['-wal', '-shm']) {
      final extra = File('$source$suffix');
      if (extra.existsSync()) extra.copySync('${copy.path}$suffix');
    }
    return AppDatabase.forTesting(NativeDatabase(copy));
  }

  Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Finder tappables() => find.byWidgetPredicate(
    (w) =>
        (w is InkWell && w.onTap != null) ||
        (w is GestureDetector && w.onTap != null) ||
        (w is IconButton && w.onPressed != null) ||
        (w is ButtonStyleButton && w.onPressed != null) ||
        (w is FloatingActionButton && w.onPressed != null) ||
        (w is Switch && w.onChanged != null) ||
        (w is Checkbox && w.onChanged != null) ||
        (w is ChoiceChip && w.onSelected != null) ||
        (w is FilterChip && w.onSelected != null) ||
        (w is ListTile && w.onTap != null),
    skipOffstage: true,
  );

  for (final page in pages) {
    if (only != null && page != only) continue;
    testWidgets(
      'tap everything on $page',
      skip: !enabled,
      (tester) async {
        tester.view.physicalSize = const Size(1206, 2622);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (_) async => null,
        );

        final report = <String>[];
        var tapped = 0;
        final previous = FlutterError.onError;
        final errors = <String>[];
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (text.contains('MissingPluginException')) return;
          final where = details.stack
              .toString()
              .split('\n')
              .where((l) => l.contains('package:flourish'))
              .take(3)
              .join('\n  ');
          errors.add('${text.split('\n').first}\n  $where');
        };
        try {
          var index = 0;
          var count = 1;
          while (index < count && index < 60) {
            final db = open();
            appRouter.go(page);
            await tester.pumpWidget(
              ProviderScope(
                key: UniqueKey(),
                overrides: [databaseProvider.overrideWithValue(db)],
                child: MaterialApp.router(
                  theme: AppTheme.light(),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  routerConfig: appRouter,
                ),
              ),
            );
            await settle(tester);
            errors.clear();
            final targets = tappables().evaluate().toList();
            count = targets.length;
            if (index < count) {
              final target = targets[index];
              final label = _describe(target);
              try {
                final box = target.renderObject as RenderBox?;
                if (box != null && box.hasSize && box.attached) {
                  final center = box.localToGlobal(
                    box.size.center(Offset.zero),
                  );
                  if (tester.view.physicalSize.contains(center * 3)) {
                    tapped++;
                    await tester.tapAt(center);
                    await settle(tester);
                  }
                }
              } catch (e) {
                errors.add('$e');
              }
              final pending = tester.takeException();
              if (pending != null &&
                  !'$pending'.contains('MissingPluginException')) {
                errors.add('$pending');
              }
              if (errors.isNotEmpty) {
                report.add('#$index $label\n${errors.toSet().join('\n')}');
              }
            }
            await tester.pumpWidget(const SizedBox());
            var done = false;
            db.close().whenComplete(() => done = true);
            for (var i = 0; i < 400 && !done; i++) {
              await tester.pump(const Duration(milliseconds: 20));
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 2)),
              );
            }
            index++;
          }
        } finally {
          FlutterError.onError = previous;
        }
        // ignore: avoid_print
        print(
          '== $page ($tapped taps): ${report.isEmpty ? 'clean' : '\n${report.join('\n')}'}',
        );
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  }
}

String _describe(Element element) {
  final texts = <String>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is Text && w.data != null) texts.add(w.data!);
    if (w is Icon && w.icon != null) {
      texts.add('icon:${w.icon!.codePoint.toRadixString(16)}');
    }
    if (texts.length < 3) e.visitChildren(visit);
  }

  visit(element);
  final w = element.widget;
  final tip = w is IconButton ? w.tooltip : null;
  return '${w.runtimeType}${tip != null ? ' "$tip"' : ''} ${texts.take(3).join(' | ')}';
}
