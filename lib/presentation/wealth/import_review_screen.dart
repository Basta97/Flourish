import 'package:flourish/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/finance/import/file_import_service.dart';
import '../../core/finance/import/import_sources.dart';
import '../../core/finance/system_categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/error_text.dart';
import '../../data/database/database.dart';
import '../../shared/category_label.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/liquid_page.dart';
import '../providers/account_providers.dart';
import '../providers/category_providers.dart';
import '../providers/finance_providers.dart';
import '../providers/theme_providers.dart';
import '../providers/transaction_providers.dart';

/// Everything an import would do, before it does it: which accounts and
/// categories rows go to, what is a duplicate, and the totals.
class ImportReviewScreen extends ConsumerStatefulWidget {
  const ImportReviewScreen({
    super.key,
    required this.parsed,
    required this.sourceName,
    this.catchUp = false,
  });

  final ImportParseResult parsed;
  final String sourceName;

  /// "Catch up on the last 7 days": file accounts default to the person's
  /// own account of that currency, and rows already in Flourish are folded
  /// away so only the missing ones are asked about.
  final bool catchUp;

  @override
  ConsumerState<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends ConsumerState<ImportReviewScreen> {
  ImportPlan? _plan;
  final _accountMap = <String, int>{};
  final _decisions = <String, CategoryDecision>{};
  final _includes = <String, bool>{};
  bool _busy = true;
  bool _autoMapped = false;
  String? _error;

  FileImportService get _service =>
      FileImportService(ref.read(financialLedgerProvider));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _replan());
  }

  /// Re-plans after an account choice, keeping the person's other choices.
  Future<void> _replan() async {
    setState(() => _busy = true);
    try {
      final plan = await _service.plan(
        widget.parsed,
        sourceName: widget.sourceName,
        defaultCurrency: ref.read(defaultCurrencyProvider),
        accountMap: Map.of(_accountMap),
      );
      for (final c in plan.categories) {
        final kept = _decisions[c.key];
        if (kept != null) c.decision = kept;
      }
      for (final (i, r) in plan.rows.indexed) {
        final kept = _includes['$i'];
        if (kept != null && r.status != ImportRowStatus.invalid) {
          r.include = kept;
        }
      }
      if (widget.catchUp && !_autoMapped) {
        _autoMapped = true;
        // A statement names the account by number; the only non-cash
        // account in that currency is almost certainly the one.
        final accounts = await ref.read(databaseProvider).getAllAccounts();
        var mapped = false;
        for (final need in plan.newAccounts) {
          final candidates = accounts
              .where((a) => a.currency == need.currency && a.type != 'cash')
              .toList();
          if (candidates.length == 1) {
            _accountMap[need.name.toLowerCase()] = candidates.single.id;
            mapped = true;
          }
        }
        if (mapped) return _replan();
      }
      if (mounted) setState(() => _plan = plan);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final plan = _plan!;
    setState(() => _busy = true);
    final service = _service;
    // The snackbar's Undo outlives this screen, so it refreshes through the
    // container rather than this widget's ref.
    final container = ProviderScope.containerOf(context);
    void refresh() {
      container.invalidate(accountsProvider);
      container.invalidate(transactionsProvider);
      container.invalidate(categoriesProvider);
      container.read(databaseProvider).notifyFinanceChanged();
    }

    try {
      final outcome = await service.apply(plan);
      refresh();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final l = context.l10n;
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            '${l.importedSummary(outcome.imported)}'
            '${outcome.skipped > 0 ? ' · ${l.skippedCount(outcome.skipped)}' : ''}. '
            '${l.reconcileOpening}',
          ),
          action: SnackBarAction(
            label: l.undo,
            onPressed: () async {
              await service.undo(outcome.batchId);
              refresh();
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.importFailed(describeError(e)))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final count = plan?.included.length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.catchUp
              ? context.l10n.catchUpReviewTitle
              : context.l10n.reviewImport,
        ),
      ),
      bottomNavigationBar: plan == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                Sp.screenH,
                Sp.sm,
                Sp.screenH,
                Sp.md,
              ),
              child: FilledButton.icon(
                onPressed: _busy || count == 0 ? null : _apply,
                icon: const Icon(Icons.download_done_rounded),
                label: Text(context.l10n.importCount(count)),
              ),
            ),
      body: LiquidPageBackground(
        child: plan == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Text(_error!),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  Sp.screenH,
                  Sp.lg,
                  Sp.screenH,
                  Sp.xxxl,
                ),
                children: [
                  if (widget.catchUp) _catchUpHeader(context, plan),
                  _summary(context, plan),
                  if (plan.accounts.isNotEmpty) _accounts(context, plan),
                  if (plan.unresolved.isNotEmpty) _categories(context, plan),
                  _totals(context, plan),
                  if (!widget.catchUp)
                    _rows(context, plan, plan.rows, context.l10n.transactions)
                  else ...[
                    _rows(
                      context,
                      plan,
                      plan.rows.where((r) => !_alreadyThere(r)).toList(),
                      context.l10n.catchUpReviewTitle,
                    ),
                    if (plan.rows.any(_alreadyThere))
                      _rows(
                        context,
                        plan,
                        plan.rows.where(_alreadyThere).toList(),
                        context.l10n.catchUpAlreadyHeader(
                          plan.rows.where(_alreadyThere).length,
                        ),
                        collapsed: true,
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  TextStyle _low(BuildContext context) =>
      AppTextStyles.caption.copyWith(color: AppColors.textSecondary(context));

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: Sp.lg),
        child: AppCard(
          padding: const EdgeInsets.all(Sp.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.subtitle),
              const SizedBox(height: Sp.sm),
              ...children,
            ],
          ),
        ),
      );

  Widget _summary(BuildContext context, ImportPlan plan) {
    final preset = ImportSources.byId(plan.sourceId);
    final unverified = preset is CsvPreset && !preset.verified;
    final lines = <String>[
      context.l10n.newCount(plan.count(ImportRowStatus.ready)),
      if (plan.count(ImportRowStatus.duplicate) > 0)
        context.l10n.alreadyImportedCount(
          plan.count(ImportRowStatus.duplicate),
        ),
      if (plan.count(ImportRowStatus.possibleDuplicate) > 0)
        context.l10n.possibleDuplicatesCount(
          plan.count(ImportRowStatus.possibleDuplicate),
        ),
      if (plan.count(ImportRowStatus.invalid) + plan.errors.length > 0)
        context.l10n.unreadableCount(
          plan.count(ImportRowStatus.invalid) + plan.errors.length,
        ),
    ];
    return _section(context, plan.sourceName, [
      Text(lines.join(' · '), style: AppTextStyles.body),
      if (unverified)
        Padding(
          padding: const EdgeInsets.only(top: Sp.xs),
          child: Text(context.l10n.unverifiedLayout, style: _low(context)),
        ),
      for (final issue in [...plan.errors, ...plan.warnings].take(8))
        Padding(
          padding: const EdgeInsets.only(top: Sp.xs),
          child: Text('• $issue', style: _low(context)),
        ),
      if (plan.errors.length + plan.warnings.length > 8)
        Text(
          context.l10n.andMore(plan.errors.length + plan.warnings.length - 8),
          style: _low(context),
        ),
    ]);
  }

  Widget _accounts(BuildContext context, ImportPlan plan) {
    final existing =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    return _section(context, context.l10n.navAccounts, [
      for (final a in plan.accounts)
        Padding(
          padding: const EdgeInsets.only(top: Sp.sm),
          child: DropdownButtonFormField<int>(
            key: ValueKey('acct-${a.name}-${a.accountId}'),
            initialValue: a.accountId ?? -1,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.l10n.accountInFile(
                a.name,
                context.l10n.rowCount(a.rows),
              ),
            ),
            items: [
              DropdownMenuItem(
                value: -1,
                child: Text(context.l10n.createNewAccount(a.currency)),
              ),
              for (final x in existing.where((x) => x.currency == a.currency))
                DropdownMenuItem(value: x.id, child: Text(x.name)),
            ],
            onChanged: (v) {
              final key = a.name.toLowerCase();
              if (v == null || v == -1) {
                _accountMap.remove(key);
              } else {
                _accountMap[key] = v;
              }
              _replan();
            },
          ),
        ),
    ]);
  }

  Widget _categories(BuildContext context, ImportPlan plan) {
    final all = SystemCategories.pickable(
      ref.watch(categoriesProvider).valueOrNull ?? const <Category>[],
    );
    return _section(context, context.l10n.categoriesNotInApp, [
      Text(context.l10n.chooseCategoryDest, style: _low(context)),
      for (final c in plan.unresolved)
        Padding(
          padding: const EdgeInsets.only(top: Sp.sm),
          child: DropdownButtonFormField<String>(
            key: ValueKey('cat-${c.key}'),
            initialValue: switch (c.decision) {
              UseCategory(:final categoryId) => '$categoryId',
              CreateCategory() => 'new',
              UseFallback() => 'other',
            },
            isExpanded: true,
            decoration: InputDecoration(
              labelText:
                  '${c.label} · ${c.type} · ${context.l10n.rowCount(c.rows)}',
            ),
            items: [
              DropdownMenuItem(
                value: 'new',
                child: Text(context.l10n.createNamed(c.name)),
              ),
              DropdownMenuItem(value: 'other', child: Text(context.l10n.other)),
              for (final x in all.where((x) => x.type == c.type))
                DropdownMenuItem(value: '${x.id}', child: Text(x.displayName)),
            ],
            onChanged: (v) => setState(() {
              c.decision = switch (v) {
                'new' => const CreateCategory(),
                'other' || null => const UseFallback(),
                _ => UseCategory(int.parse(v)),
              };
              _decisions[c.key] = c.decision;
            }),
          ),
        ),
    ]);
  }

  Widget _totals(BuildContext context, ImportPlan plan) {
    final totals = plan.totalsByAccount();
    return _section(context, context.l10n.changePerAccount, [
      if (totals.isEmpty)
        Text(context.l10n.nothingSelected, style: _low(context)),
      for (final e in totals.entries)
        Row(
          children: [
            Expanded(child: Text(e.key, style: AppTextStyles.body)),
            Text(
              textDirection: TextDirection.ltr,
              '${e.value > Amount.zero ? '+' : ''}'
              '${CurrencyFormatter.format(e.value.toDouble(), currency: e.key.substring(e.key.lastIndexOf('(') + 1, e.key.length - 1))}',
              style: AppTextStyles.number,
            ),
          ],
        ),
    ]);
  }

  static bool _alreadyThere(ImportRowPlan r) =>
      r.status == ImportRowStatus.duplicate ||
      r.status == ImportRowStatus.possibleDuplicate;

  Widget _catchUpHeader(BuildContext context, ImportPlan plan) {
    final missing = plan.rows.where((r) => !_alreadyThere(r)).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.lg),
      child: AppCard(
        padding: const EdgeInsets.all(Sp.lg),
        child: Row(
          children: [
            Icon(
              missing == 0
                  ? Icons.verified_rounded
                  : Icons.playlist_add_check_rounded,
              color: missing == 0 ? AppColors.income : AppColors.primary,
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Text(
                missing == 0
                    ? context.l10n.catchUpAllCaughtUp
                    : context.l10n.catchUpMissingHeader(missing),
                style: AppTextStyles.subtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rows(
    BuildContext context,
    ImportPlan plan,
    List<ImportRowPlan> rows,
    String title, {
    bool collapsed = false,
  }) {
    final shown = rows.take(300).toList();
    final date = DateFormat.yMMMd();
    final tiles = [
      for (final r in shown)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: r.include,
          onChanged: r.status == ImportRowStatus.invalid
              ? null
              : (v) => setState(() {
                  r.include = v ?? false;
                  _includes['${plan.rows.indexOf(r)}'] = r.include;
                }),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            (r.row.payee ?? r.row.note ?? r.category?.name ?? r.row.type)
                .replaceAll(RegExp(r'\s*\n\s*'), ' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          secondary: Text(
            '${r.row.type == 'income'
                ? '+'
                : r.row.type == 'expense'
                ? '−'
                : '⇄ '}'
            '${CurrencyFormatter.format(r.row.amount.toDouble(), currency: r.currency)}',
            textDirection: TextDirection.ltr,
            style: AppTextStyles.numberSmall.copyWith(
              color: r.row.type == 'income'
                  ? AppColors.income
                  : AppColors.textPrimary(context),
            ),
          ),
          subtitle: Text(
            [
              date.format(r.row.date),
              r.row.type == 'transfer'
                  ? '${r.account} → ${r.row.destinationAccount}'
                  : r.account,
              ?r.category?.label,
              switch (r.status) {
                ImportRowStatus.duplicate => context.l10n.alreadyImported,
                ImportRowStatus.possibleDuplicate =>
                  context.l10n.possibleDuplicate,
                ImportRowStatus.invalid =>
                  r.problem ?? context.l10n.cannotImport,
                ImportRowStatus.ready => null,
              },
            ].nonNulls.join(' · '),
            style: _low(context),
          ),
        ),
      if (rows.length > shown.length)
        Text(
          context.l10n.moreRowsFollow(rows.length - shown.length),
          style: _low(context),
        ),
    ];
    if (!collapsed) return _section(context, title, tiles);
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.lg),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          shape: const Border(),
          title: Text(title, style: AppTextStyles.subtitle),
          children: tiles,
        ),
      ),
    );
  }
}
