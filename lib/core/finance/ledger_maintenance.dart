import 'package:drift/drift.dart';
import '../../data/database/database.dart';
import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';
import 'fx_policy.dart';
import 'system_categories.dart';

/// One-off repairs for data written by earlier versions. Each task records a
/// marker so it runs once; the FX repair works in bounded batches until done.
class LedgerMaintenance {
  final AppDatabase db;
  LedgerMaintenance(this.db);
  FinanceStore get store => FinanceStore(db);

  Future<void> run({required String preferredCurrency}) async {
    await _once('merge-system-categories-v1', _mergeLegacyCategories);
    await _once(
      'seeded-account-currency-v1',
      () => _seededAccountCurrency(preferredCurrency),
    );
    await _repairFxSnapshots();
  }

  Future<void> _once(String id, Future<void> Function() task) async {
    if (await store.get('maintenance', id) != null) return;
    await db.transaction(() async {
      await task();
      await store.put('maintenance', id, {
        'id': id,
        'date': DateTime.now().toIso8601String(),
      }, notify: false);
    });
  }

  /// Earlier versions created categories such as "Transfer transfer" and
  /// "Transfer asset"; fold them into the registry's system categories.
  Future<void> _mergeLegacyCategories() async {
    for (final system in SystemCategories.all) {
      for (final legacyName in system.legacyNames) {
        final legacy =
            await (db.select(db.categories)..where(
                  (c) => c.type.equals(system.type) & c.name.equals(legacyName),
                ))
                .get();
        if (legacy.isEmpty) continue;
        final target = await SystemCategories.idFor(db, system.key);
        for (final old in legacy) {
          if (old.id == target) continue;
          await _repoint(old.id, target);
          await db.deleteCategory(old.id);
        }
      }
    }
  }

  Future<void> _repoint(int from, int to) async {
    await (db.update(db.transactions)..where((t) => t.categoryId.equals(from)))
        .write(TransactionsCompanion(categoryId: Value(to)));
    await (db.update(db.recurringTransactions)
          ..where((r) => r.categoryId.equals(from)))
        .write(RecurringTransactionsCompanion(categoryId: Value(to)));
    await (db.update(db.budgets)..where((b) => b.categoryId.equals(from)))
        .write(BudgetsCompanion(categoryId: Value(to)));
    for (final link in await store.list('categoryParents')) {
      if (link['child'] == from) {
        await store.remove('categoryParents', '$from');
        await store.put('categoryParents', '$to', {...link, 'child': to});
      } else if (link['parent'] == from) {
        await store.put('categoryParents', '${link['child']}', {
          ...link,
          'parent': to,
        });
      }
    }
    for (final template in await store.list('templates')) {
      if (template['category'] == '$from') {
        await store.put('templates', template['id'], {
          ...template,
          'category': '$to',
        });
      }
    }
  }

  /// New installs used to seed "Cash" and "Bank Account" in USD whatever the
  /// reporting currency. Switch them while they are still untouched.
  Future<void> _seededAccountCurrency(String preferred) async {
    for (final a in await db.getAllAccounts()) {
      if (!['Cash', 'Bank Account'].contains(a.name) ||
          a.currency == preferred ||
          await store.balance(a.id) != Amount.zero ||
          await db.accountHasHistory(a.id)) {
        continue;
      }
      await (db.update(db.accounts)..where((t) => t.id.equals(a.id))).write(
        AccountsCompanion(currency: Value(preferred)),
      );
    }
  }

  /// Snapshots written before [FxPolicy] could carry a rate of any age.
  /// Re-check up to [batch] of them per run: keep rates that fall inside the
  /// window (stamping their date) and drop the rest so the next market
  /// refresh fetches the rate for the entry's own date.
  Future<int> _repairFxSnapshots({int batch = 300}) async {
    final rows = await db
        .customSelect(
          "SELECT transaction_id, payload FROM transaction_details "
          "WHERE payload NOT LIKE '%\"ratesAt\"%' LIMIT $batch",
        )
        .get();
    if (rows.isEmpty) return 0;
    final fx = (await store.list(
      'fx',
    )).map(MarketObservation.fromJson).toList();
    for (final row in rows) {
      final id = row.read<int>('transaction_id');
      final details = await store.transactionDetails(id);
      if (details == null) continue;
      final currency = details['currency'] as String?;
      final date = DateTime.tryParse(details['date'] as String? ?? '');
      final rates = Map<String, dynamic>.from(details['rates'] as Map? ?? {});
      final ratesAt = <String, String>{};
      if (currency != null && date != null) {
        for (final target in rates.keys.toList()) {
          if (target == currency) continue;
          final candidates =
              fx
                  .where(
                    (o) =>
                        o.key == '$currency/$target' &&
                        FxPolicy.usableFor(o.effectiveAt, date),
                  )
                  .toList()
                ..sort((a, b) {
                  if (a.manual != b.manual) return a.manual ? -1 : 1;
                  return b.effectiveAt.compareTo(a.effectiveAt);
                });
          final best = candidates.firstOrNull;
          if (best == null) {
            rates.remove(target);
          } else {
            rates[target] = '${best.value}';
            ratesAt[target] = best.effectiveAt.toIso8601String();
          }
        }
      }
      await store.setTransactionDetails(id, {
        ...details,
        'rates': rates,
        'ratesAt': ratesAt,
      });
    }
    return rows.length;
  }
}
