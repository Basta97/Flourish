import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/finance/import/file_import_service.dart';
import '../../core/finance/import/import_sources.dart';
import '../../core/finance/system_categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/error_text.dart';
import '../../data/database/database.dart';
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
  });

  final ImportParseResult parsed;
  final String sourceName;

  @override
  ConsumerState<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends ConsumerState<ImportReviewScreen> {
  ImportPlan? _plan;
  final _accountMap = <String, int>{};
  final _decisions = <String, CategoryDecision>{};
  final _includes = <String, bool>{};
  bool _busy = true;
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
        if (kept != null && r.status != ImportRowStatus.invalid) r.include = kept;
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
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            'Imported ${outcome.imported} transaction${outcome.imported == 1 ? '' : 's'}'
            '${outcome.skipped > 0 ? ' · ${outcome.skipped} skipped' : ''}. '
            'Reconcile opening balances if needed.',
          ),
          action: SnackBarAction(
            label: 'Undo',
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
          SnackBar(content: Text('Import failed: ${describeError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final count = plan?.included.length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Review import')),
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
                label: Text(
                  count == 1 ? 'Import 1 transaction' : 'Import $count transactions',
                ),
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
                  _summary(context, plan),
                  if (plan.accounts.isNotEmpty) _accounts(context, plan),
                  if (plan.unresolved.isNotEmpty) _categories(context, plan),
                  _totals(context, plan),
                  _rows(context, plan),
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
      '${plan.count(ImportRowStatus.ready)} new',
      if (plan.count(ImportRowStatus.duplicate) > 0)
        '${plan.count(ImportRowStatus.duplicate)} already imported',
      if (plan.count(ImportRowStatus.possibleDuplicate) > 0)
        '${plan.count(ImportRowStatus.possibleDuplicate)} possible duplicates',
      if (plan.count(ImportRowStatus.invalid) + plan.errors.length > 0)
        '${plan.count(ImportRowStatus.invalid) + plan.errors.length} unreadable',
    ];
    return _section(context, plan.sourceName, [
      Text(lines.join(' · '), style: AppTextStyles.body),
      if (unverified)
        Padding(
          padding: const EdgeInsets.only(top: Sp.xs),
          child: Text(
            'This layout was built from documentation, not a real export. '
            'Check a few rows below before importing.',
            style: _low(context),
          ),
        ),
      for (final issue in [...plan.errors, ...plan.warnings].take(8))
        Padding(
          padding: const EdgeInsets.only(top: Sp.xs),
          child: Text('• $issue', style: _low(context)),
        ),
      if (plan.errors.length + plan.warnings.length > 8)
        Text(
          '…and ${plan.errors.length + plan.warnings.length - 8} more',
          style: _low(context),
        ),
    ]);
  }

  Widget _accounts(BuildContext context, ImportPlan plan) {
    final existing = ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    return _section(context, 'Accounts', [
      for (final a in plan.accounts)
        Padding(
          padding: const EdgeInsets.only(top: Sp.sm),
          child: DropdownButtonFormField<int>(
            key: ValueKey('acct-${a.name}-${a.accountId}'),
            initialValue: a.accountId ?? -1,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: '“${a.name}” in the file · ${_rowsLabel(a.rows)}',
            ),
            items: [
              DropdownMenuItem(
                value: -1,
                child: Text('Create new account (${a.currency})'),
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
    return _section(context, 'Categories not in Flourish', [
      Text(
        'Choose where each one goes. New categories keep the parent from the file.',
        style: _low(context),
      ),
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
              labelText: '${c.label} · ${c.type} · ${_rowsLabel(c.rows)}',
            ),
            items: [
              DropdownMenuItem(value: 'new', child: Text('Create “${c.name}”')),
              const DropdownMenuItem(value: 'other', child: Text('Other')),
              for (final x in all.where((x) => x.type == c.type))
                DropdownMenuItem(value: '${x.id}', child: Text(x.name)),
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
    return _section(context, 'Change per account', [
      if (totals.isEmpty) Text('Nothing selected', style: _low(context)),
      for (final e in totals.entries)
        Row(
          children: [
            Expanded(child: Text(e.key, style: AppTextStyles.body)),
            Text(
              '${e.value > Amount.zero ? '+' : ''}'
              '${CurrencyFormatter.format(e.value.toDouble(), currency: e.key.substring(e.key.lastIndexOf('(') + 1, e.key.length - 1))}',
              style: AppTextStyles.number,
            ),
          ],
        ),
    ]);
  }

  Widget _rows(BuildContext context, ImportPlan plan) {
    final shown = plan.rows.take(300).toList();
    final date = DateFormat.yMMMd();
    return _section(context, 'Transactions', [
      for (final (i, r) in shown.indexed)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: r.include,
          onChanged: r.status == ImportRowStatus.invalid
              ? null
              : (v) => setState(() {
                  r.include = v ?? false;
                  _includes['$i'] = r.include;
                }),
          title: Text(
            maxLines: 1,
            [
              (r.row.payee ?? r.row.note ?? r.category?.name ?? r.row.type)
                  .replaceAll(RegExp(r'\s*\n\s*'), ' · '),
              '${r.row.type == 'income' ? '+' : r.row.type == 'expense' ? '−' : '⇄ '}'
                  '${CurrencyFormatter.format(r.row.amount.toDouble(), currency: r.currency)}',
            ].join(' · '),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              date.format(r.row.date),
              r.row.type == 'transfer'
                  ? '${r.account} → ${r.row.destinationAccount}'
                  : r.account,
              ?r.category?.label,
              switch (r.status) {
                ImportRowStatus.duplicate => 'Already imported',
                ImportRowStatus.possibleDuplicate => 'Possible duplicate',
                ImportRowStatus.invalid => r.problem ?? 'Cannot import',
                ImportRowStatus.ready => null,
              },
            ].nonNulls.join(' · '),
            style: _low(context),
          ),
        ),
      if (plan.rows.length > shown.length)
        Text(
          '${plan.rows.length - shown.length} more rows follow the same choices',
          style: _low(context),
        ),
    ]);
  }
}

String _rowsLabel(int n) => n == 1 ? '1 row' : '$n rows';
