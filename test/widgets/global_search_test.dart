import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/data/search/search_repository.dart';
import 'package:flourish/core/search/search_models.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/presentation/search/search_screen.dart';

class _Delayed extends SearchRepository {
  _Delayed(super.db);
  final requests = <String, Completer<SearchPage>>{};
  @override
  Future<void> prepare() async {}
  @override
  Future<SearchPage> search(SearchQuery query, {SearchCursor? after}) =>
      requests.putIfAbsent(query.text, Completer<SearchPage>.new).future;
}

SearchPage page(String title) => SearchPage([
  SearchHit(
    kind: 'feature',
    id: title,
    title: title,
    subtitle: '',
    currency: '',
    amount: '',
    target: '/tools',
    rowid: 1,
    rank: 1,
    date: 0,
  ),
], null);
void main() {
  testWidgets('late responses cannot replace newer results or undo clear', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = _Delayed(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [searchRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SearchScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'first');
    await tester.pump(const Duration(milliseconds: 151));
    await tester.enterText(find.byType(TextField), 'second');
    await tester.pump(const Duration(milliseconds: 151));
    repository.requests['second']!.complete(page('Latest result'));
    await tester.pump();
    repository.requests['first']!.complete(page('Stale result'));
    await tester.pump();
    expect(find.text('Latest result'), findsOneWidget);
    expect(find.text('Stale result'), findsNothing);
    await tester.enterText(find.byType(TextField), 'third');
    await tester.pump(const Duration(milliseconds: 151));
    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    repository.requests['third']!.complete(page('Cleared result'));
    await tester.pump();
    expect(find.text('Cleared result'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
