import 'package:flourish/core/router/app_router.dart';
import 'package:flourish/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('island nav switches tabs at iPhone size', (tester) async {
    // iPhone 17-class screen with notch and home-indicator insets.
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 186, bottom: 102);
    tester.view.viewPadding = const FakeViewPadding(top: 186, bottom: 102);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          builder: (context, state, child) => ScaffoldWithNavBar(child: child),
          routes: [
            for (final path in [
              '/dashboard',
              '/transactions',
              '/accounts',
              '/wealth',
            ])
              GoRoute(
                path: path,
                builder: (context, state) => Center(child: Text('page $path')),
              ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.text('page /dashboard'), findsOneWidget);

    for (final (label, path) in [
      ('Ledger', '/transactions'),
      ('Accounts', '/accounts'),
      ('Wealth', '/wealth'),
      ('Home', '/dashboard'),
    ]) {
      final target = tester.getCenter(find.bySemanticsLabel(label));
      await tester.tapAt(target);
      await tester.pumpAndSettle();
      expect(find.text('page $path'), findsOneWidget, reason: label);
    }
  });
}
