import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Guards the rule that money only moves through FinancialLedgerService:
/// anything else that writes transaction rows or balances would bypass
/// validation, FX snapshots and the exact-balance store.
void main() {
  final writes = RegExp(
    r'changeBalance\(|\.insertTransaction\(|\.updateTransaction\(|'
    r'\.deleteTransaction\(|into\((db\.)?transactions\)|'
    r'update\((db\.)?transactions\)|delete\((db\.)?transactions\)',
  );
  const allowed = {
    // The ledger itself and the stores/row primitives it is built on.
    'lib/core/finance/financial_ledger_service.dart',
    'lib/data/finance/finance_store.dart',
    'lib/data/database/database.dart',
    'lib/data/database/database.g.dart',
    // Re-points entries from merged legacy categories; never moves money.
    'lib/core/finance/ledger_maintenance.dart',
    // Whole-file restore of a legacy JSON backup, which carries its balances.
    'lib/presentation/settings/settings_screen.dart',
  };

  test('only the ledger writes transactions or balances', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final path = file.path.replaceAll(r'\', '/');
      if (allowed.contains(path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (writes.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}
