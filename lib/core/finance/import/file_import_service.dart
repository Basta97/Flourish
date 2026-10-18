import 'package:drift/drift.dart' show Value, Variable;
import 'package:uuid/uuid.dart';

import '../../../data/database/database.dart';
import '../../../domain/finance/models.dart';
import '../../detection/category_resolver.dart';
import '../../services/category_suggester.dart';
import '../../theme/app_colors.dart';
import '../financial_ledger_service.dart';
import '../system_categories.dart';
import 'import_source.dart';

/// What happens to a category name found in the file that has no exact
/// match: use an existing category, create it, or file it under "Other".
sealed class CategoryDecision {
  const CategoryDecision();
}

class UseCategory extends CategoryDecision {
  const UseCategory(this.categoryId);
  final int categoryId;
}

class CreateCategory extends CategoryDecision {
  const CreateCategory();
}

class UseFallback extends CategoryDecision {
  const UseFallback();
}

/// A category name from the file, per type, with what the importer would
/// do with it.
class CategoryNeed {
  CategoryNeed({
    required this.type,
    required this.name,
    this.parentName,
    required this.rows,
    required this.decision,
    this.matchedExactly = false,
  });

  final String type;
  final String name;

  /// "Food" for a "Food:Groceries" or category + subcategory pair.
  final String? parentName;
  int rows;
  CategoryDecision decision;

  /// True when an existing category has this name (no question to ask).
  final bool matchedExactly;

  String get key => '$type|${name.toLowerCase()}|${parentName?.toLowerCase()}';
  String get label => parentName == null ? name : '$parentName › $name';
}

/// An account named in the file, and the Flourish account it goes to
/// (null: a new account is created with this name).
class AccountNeed {
  AccountNeed(this.name, this.currency, this.accountId);
  final String name;
  final String currency;
  final int? accountId;
  int rows = 0;
  bool get isNew => accountId == null;
}

enum ImportRowStatus { ready, duplicate, possibleDuplicate, invalid }

class ImportRowPlan {
  ImportRowPlan({
    required this.row,
    required this.key,
    required this.currency,
    required this.status,
    this.accountId,
    this.destinationId,
    this.category,
    this.problem,
  }) : include = status == ImportRowStatus.ready;

  final RawImportRow row;

  /// Duplicate key: the file's own id (OFX FITID) when it has one, else
  /// account + day + amount + type + currency (+ destination). Notes are left
  /// out so a reworded memo is still the same transaction.
  final String key;
  final String currency;
  ImportRowStatus status;
  final int? accountId, destinationId;
  final CategoryNeed? category;
  final String? problem;
  bool include;

  String get account => row.account ?? '';
}

/// Everything the review screen shows before anything is written.
class ImportPlan {
  ImportPlan({
    required this.sourceId,
    required this.sourceName,
    required this.rows,
    required this.categories,
    required this.accounts,
    required this.accountMap,
    required this.errors,
    required this.warnings,
  });

  final String sourceId, sourceName;
  final List<ImportRowPlan> rows;
  final List<CategoryNeed> categories;
  /// Every account the file names.
  final List<AccountNeed> accounts;

  /// File account name (lower case) → chosen Flourish account.
  final Map<String, int> accountMap;

  List<AccountNeed> get newAccounts => accounts.where((a) => a.isNew).toList();
  final List<ImportIssue> errors, warnings;

  Iterable<ImportRowPlan> get included => rows.where((r) => r.include);
  int count(ImportRowStatus s) => rows.where((r) => r.status == s).length;

  /// Category names that need a decision (no exact match).
  List<CategoryNeed> get unresolved =>
      categories.where((c) => !c.matchedExactly).toList();

  /// Signed totals of the included rows, per account and currency.
  Map<String, Amount> totalsByAccount() {
    final totals = <String, Amount>{};
    for (final r in included) {
      final key = '${r.account} (${r.currency})';
      final sign = r.row.type == 'income' ? Amount.one : -Amount.one;
      totals[key] = (totals[key] ?? Amount.zero) + r.row.amount * sign;
      if (r.row.type == 'transfer') {
        final to = '${r.row.destinationAccount} (${r.currency})';
        totals[to] = (totals[to] ?? Amount.zero) + r.row.amount;
      }
    }
    return totals;
  }
}

class ImportOutcome {
  const ImportOutcome(this.batchId, this.imported, this.skipped);
  final String batchId;
  final int imported, skipped;
}

/// Turns parsed file rows into a reviewable [ImportPlan] and books the
/// accepted rows through the ledger in one database transaction.
class FileImportService {
  FileImportService(this.ledger);
  final FinancialLedgerService ledger;
  AppDatabase get db => ledger.db;

  static const importsCollection = 'imports';

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String keyOf(RawImportRow r, String currency) {
    final account = (r.account ?? '').toLowerCase();
    if (r.externalId != null && r.externalId!.trim().isNotEmpty) {
      return 'fitid:$account|${r.externalId!.trim()}';
    }
    return 'row:$account|${_day(r.date)}|${r.amount}|${r.type}|$currency|'
        '${(r.destinationAccount ?? '').toLowerCase()}';
  }

  Future<ImportPlan> plan(
    ImportParseResult parsed, {
    required String sourceName,
    required String defaultCurrency,
    Map<String, int> accountMap = const {},
  }) async {
    final accounts = await db.getAllAccounts();
    final all = await db.getAllCategories();
    final pickable = SystemCategories.pickable(all);
    final resolver = CategoryResolver(all);
    final recent = (await db.getAllTransactions()).take(500).toList();
    Account? accountNamed(String? name) {
      if (name == null) return null;
      final n = name.trim().toLowerCase();
      final mapped = accountMap[n];
      if (mapped != null) {
        return accounts.where((a) => a.id == mapped).firstOrNull;
      }
      return accounts.where((a) => a.name.trim().toLowerCase() == n).firstOrNull;
    }

    final needs = <String, CategoryNeed>{};
    final fileAccounts = <String, AccountNeed>{};
    void note(String name, String currency) => fileAccounts
        .putIfAbsent(
          name.trim().toLowerCase(),
          () => AccountNeed(name.trim(), currency, accountNamed(name)?.id),
        )
        .rows++;
    final seen = <String>{};
    final rows = <ImportRowPlan>[];

    for (final r in parsed.rows) {
      final account = accountNamed(r.account);
      final currency = r.currency ?? account?.currency ?? defaultCurrency;
      final key = keyOf(r, currency);
      String? problem;
      int? destinationId;

      // A new account takes the currency of its first row.
      String? currencyOf(String? name) =>
          accountNamed(name)?.currency ??
          fileAccounts[name?.trim().toLowerCase()]?.currency;

      if ((r.account ?? '').trim().isEmpty) {
        problem = 'No account named';
      } else if (currencyOf(r.account) case final c? when c != currency) {
        problem = '${account?.name ?? r.account} is in $c, this row is in $currency';
      } else {
        note(r.account!, currency);
      }
      if (problem == null && r.type == 'transfer') {
        final to = accountNamed(r.destinationAccount);
        if ((r.destinationAccount ?? '').trim().isEmpty) {
          problem = 'Transfer without a destination account';
        } else if (currencyOf(r.destinationAccount) case final c?
            when c != currency) {
          problem = 'Transfers across currencies must be entered by hand';
        } else {
          note(r.destinationAccount!, currency);
          destinationId = to?.id;
        }
      }

      CategoryNeed? need;
      if (problem == null && r.type != 'transfer') {
        need = _categoryNeed(r, needs, pickable, resolver, recent);
      }

      var status = problem != null
          ? ImportRowStatus.invalid
          : !seen.add(key) ||
                await ledger.store.get(importsCollection, key) != null
          ? ImportRowStatus.duplicate
          : ImportRowStatus.ready;
      if (status == ImportRowStatus.ready &&
          account != null &&
          await _similarExists(account.id, r)) {
        status = ImportRowStatus.possibleDuplicate;
      }
      rows.add(
        ImportRowPlan(
          row: r,
          key: key,
          currency: currency,
          status: status,
          accountId: account?.id,
          destinationId: destinationId,
          category: need,
          problem: problem,
        ),
      );
    }
    return ImportPlan(
      sourceId: parsed.sourceId,
      sourceName: sourceName,
      rows: rows,
      categories: needs.values.toList()
        ..sort((a, b) => b.rows.compareTo(a.rows)),
      accounts: fileAccounts.values.toList(),
      accountMap: accountMap,
      errors: parsed.errors,
      warnings: parsed.warnings,
    );
  }

  /// Category for a row: the file's name (exact, then similar), else a
  /// suggestion from the payee (history and keywords), else "Other".
  CategoryNeed? _categoryNeed(
    RawImportRow r,
    Map<String, CategoryNeed> needs,
    List<Category> pickable,
    CategoryResolver resolver,
    List<Transaction> recent,
  ) {
    var name = (r.subcategory ?? r.category)?.trim();
    var parent = r.subcategory != null ? r.category?.trim() : null;
    // QIF and some apps write "Parent:Child" in one field.
    if (parent == null && name != null && name.contains(':')) {
      final parts = name.split(':').map((p) => p.trim()).toList();
      parent = parts.first;
      name = parts.last;
    }
    if (name == null || name.isEmpty) {
      final text = [r.payee, r.note].nonNulls.join(' ');
      final suggested = CategorySuggester.suggest(
        text,
        recent,
        categories: pickable,
        type: r.type,
      );
      if (suggested == null) return null;
      name = pickable.firstWhere((c) => c.id == suggested).name;
      parent = null;
    }
    final probe = CategoryNeed(
      type: r.type,
      name: name,
      parentName: parent == null || parent.isEmpty ? null : parent,
      rows: 0,
      decision: const UseFallback(),
    );
    final existing = needs[probe.key];
    if (existing != null) {
      existing.rows++;
      return existing;
    }
    final exact = pickable
        .where(
          (c) => c.type == r.type && c.name.toLowerCase() == name!.toLowerCase(),
        )
        .firstOrNull;
    final similar = exact ?? resolver.findSimilar(name, r.type);
    final need = CategoryNeed(
      type: r.type,
      name: name,
      parentName: probe.parentName,
      rows: 1,
      decision: similar != null ? UseCategory(similar.id) : const CreateCategory(),
      matchedExactly: exact != null,
    );
    needs[need.key] = need;
    return need;
  }

  /// A transaction already in the account with the same type and amount
  /// within a day: the same payment entered by hand or by an earlier import
  /// of another file.
  Future<bool> _similarExists(int accountId, RawImportRow r) async {
    if (r.type == 'transfer') return false;
    final rows = await db
        .customSelect(
          'SELECT id FROM transactions WHERE account_id = ? AND type = ? '
          'AND ABS(amount - ?) < 0.005 AND transaction_date BETWEEN ? AND ? LIMIT 1',
          variables: [
            Variable(accountId),
            Variable(r.type),
            Variable(r.amount.toDouble()),
            Variable(r.date.subtract(const Duration(days: 1))),
            Variable(r.date.add(const Duration(days: 1))),
          ],
        )
        .get();
    return rows.isNotEmpty;
  }

  /// Books every included row of [plan]. Accounts and categories it needs
  /// are created first; all or nothing.
  Future<ImportOutcome> apply(ImportPlan plan) => db.transaction(() async {
    final batchId = const Uuid().v4();
    final accountIds = <String, int>{
      for (final a in await db.getAllAccounts()) a.name.trim().toLowerCase(): a.id,
      ...plan.accountMap,
    };
    Future<int> account(String name, String currency) async {
      final key = name.trim().toLowerCase();
      return accountIds[key] ??= await db.insertAccount(
        AccountsCompanion.insert(
          name: name.trim(),
          type: 'bank',
          color: AppColors.categoryPalette[accountIds.length % 12],
          icon: 'account_balance',
          currency: Value(currency),
        ),
      );
    }

    final categoryIds = <String, int>{};
    Future<int> category(CategoryNeed need) async {
      final cached = categoryIds[need.key];
      if (cached != null) return cached;
      final id = switch (need.decision) {
        UseCategory(:final categoryId) => categoryId,
        UseFallback() => (await db.fallbackCategoryFor(need.type)).id,
        CreateCategory() => await CategoryResolver.ensure(
          db,
          ledger.store,
          ProposedCategory(
            name: need.name,
            type: need.type,
            icon: 'category',
            colorIndex: need.name.codeUnits.fold<int>(0, (a, b) => a + b) % 12,
            parentName: need.parentName,
          ),
        ),
      };
      // A parent named in the file is matched to an existing category with
      // the same meaning ("Food" → "Food & Drinks") or created.
      if (need.decision is CreateCategory && need.parentName != null) {
        final all = await db.getAllCategories();
        final parentId =
            CategoryResolver(all).findRelated(need.parentName!, need.type)?.id ??
            await CategoryResolver.ensure(
              db,
              ledger.store,
              ProposedCategory(
                name: need.parentName!,
                type: need.type,
                icon: 'category',
                colorIndex:
                    need.parentName!.codeUnits.fold<int>(0, (a, b) => a + b) % 12,
              ),
            );
        if (parentId != id) {
          await ledger.store.put('categoryParents', '$id', {
            'child': id,
            'parent': parentId,
          });
        }
      }
      return categoryIds[need.key] = id;
    }

    var imported = 0, skipped = 0;
    for (final r in plan.rows) {
      if (!r.include || r.status == ImportRowStatus.invalid) {
        skipped++;
        continue;
      }
      if (await ledger.store.get(importsCollection, r.key) != null &&
          r.status != ImportRowStatus.duplicate) {
        skipped++;
        continue;
      }
      final row = r.row;
      final from = await account(row.account!, r.currency);
      // Some apps write payee and description on separate lines.
      final note = [row.payee, row.note].nonNulls
          .map((s) => s.trim().replaceAll(RegExp(r'\s*\n\s*'), ' · '))
          .where((s) => s.isNotEmpty)
          .toSet()
          .join(' · ');
      if (row.type == 'transfer') {
        final to = await account(row.destinationAccount!, r.currency);
        await ledger.transfer(
          fromAccountId: from,
          toAccountId: to,
          amount: row.amount,
          date: row.date,
          note: note.isEmpty ? null : note,
          source: 'import',
          sourceRef: batchId,
        );
      } else {
        await ledger.recordCash(
          accountId: from,
          amount: row.amount,
          type: row.type,
          categoryId: r.category == null
              ? (await db.fallbackCategoryFor(row.type)).id
              : await category(r.category!),
          note: note.isEmpty ? null : note,
          merchant: row.payee?.split('\n').first.trim(),
          date: row.date,
          source: 'import',
          sourceRef: batchId,
        );
      }
      await ledger.store.put(importsCollection, r.key, {
        'date': DateTime.now().toIso8601String(),
        'batch': batchId,
        'source': plan.sourceId,
      }, notify: false);
      imported++;
    }
    db.notifyFinanceChanged();
    return ImportOutcome(batchId, imported, skipped);
  });

  /// Removes everything one import booked, so the file can be imported
  /// again. Accounts and categories it created stay.
  Future<int> undo(String batchId) => db.transaction(() async {
    final rows = await (db.select(
      db.transactions,
    )..where((t) => t.sourceRef.equals(batchId))).get();
    var removed = 0;
    for (final t in rows) {
      if (await db.getTransactionById(t.id) == null) continue; // other leg
      await ledger.deleteTransactionAndUpdateBalance(t.id);
      removed++;
    }
    await db.customStatement(
      "DELETE FROM finance_records WHERE collection = ? AND json_extract(payload, '\$.batch') = ?",
      [importsCollection, batchId],
    );
    db.notifyFinanceChanged();
    return removed;
  });
}
