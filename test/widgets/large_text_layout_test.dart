import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_theme.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/accounts/widgets/account_card.dart';
import 'package:flourish/presentation/wealth/widgets/asset_tile.dart';
import 'package:flourish/shared/widgets/progress.dart';
import 'package:flourish/shared/widgets/segmented_pill.dart';
import 'package:flourish/shared/widgets/stat_pill.dart';
import 'package:flourish/shared/widgets/transaction_swipe_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Renders the shared building blocks at the largest supported text size
/// (1.3×) on a narrow phone. Any RenderFlex overflow fails the test.
String _egp(double v) => CurrencyFormatter.format(v, currency: 'EGP');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final now = DateTime(2026, 10, 15, 13, 44);
  final account = Account(
    id: 1,
    name: 'Everyday spending account',
    type: 'bank',
    balance: -1234567.89,
    currency: 'EGP',
    color: AppColors.accountGradients.first.first.toARGB32(),
    icon: 'account_balance',
    createdAt: now,
  );
  final transaction = Transaction(
    id: 1,
    accountId: 1,
    categoryId: 1,
    amount: 98765.43,
    type: 'expense',
    note: 'A fairly long note that should truncate rather than overflow',
    transactionDate: now,
    createdAt: now,
  );

  final cases = <String, Widget>{
    'stat pills row': const Row(
      children: [
        Expanded(
          child: StatPill(
            label: 'Income',
            icon: Icons.south_west_rounded,
            tone: Colors.green,
            value: 123456,
            format: _egp,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: StatPill(
            label: 'Spending',
            icon: Icons.north_east_rounded,
            tone: Colors.red,
            value: 98765,
            format: _egp,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: StatPill(
            label: 'Saved',
            icon: Icons.savings_outlined,
            tone: Colors.teal,
            value: null,
            format: _egp,
          ),
        ),
      ],
    ),
    'segmented pill': SegmentedPill(
      labels: const ['Holdings', 'Obligations', 'Reports', 'Tools'],
      selectedIndex: 1,
      onChanged: (_) {},
    ),
    'account card': AccountCard(account: account),
    'account card large': AccountCard(account: account, large: true),
    'asset tile': const AssetTile(
      icon: Icons.workspace_premium_rounded,
      tint: Colors.amber,
      title: 'Gold bullion held at the bank vault',
      subtitle: 'gold · 125.5 grams · Bank vault\nManual quote',
      value: 'EGP 4,567,890.12',
      secondary: '+123,456.78 EGP',
    ),
    'transaction tile': TransactionSwipeTile(
      transaction: transaction,
      currency: 'EGP',
      accountName: account.name,
      compact: true,
    ),
    'progress ring': const ProgressRing(
      value: 0.62,
      color: Colors.green,
      child: Text('62%'),
    ),
  };

  for (final brightness in Brightness.values) {
    for (final entry in cases.entries) {
      testWidgets('${entry.key} fits at 1.3× text (${brightness.name})', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1125, 2436); // 375 × 812 pt
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: brightness == Brightness.dark
                  ? AppTheme.dark()
                  : AppTheme.light(),
              home: MediaQuery.withClampedTextScaling(
                minScaleFactor: 1.3,
                maxScaleFactor: 1.3,
                child: Scaffold(
                  body: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [entry.value],
                  ),
                ),
              ),
            ),
          ),
        );
        // Let entrance animations and counters finish.
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
