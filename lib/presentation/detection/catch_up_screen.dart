import 'dart:io' show Platform;

import 'package:flourish/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/detection/catch_up_service.dart';
import '../../core/detection/detection_service.dart';
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
import '../wealth/finance_tools_view.dart' show importSpreadsheet;
import 'inbox_screen.dart' show kindLabel;

final catchUpServiceProvider = Provider(
  (ref) => CatchUpService(ref.watch(detectionServiceProvider)),
);

enum _Decision { added, skipped }

/// "Catch up on the last 7 days": bring last week's payments in from pasted
/// alerts or a bank statement, and add only the ones Flourish is missing.
class CatchUpScreen extends ConsumerStatefulWidget {
  const CatchUpScreen({super.key});

  @override
  ConsumerState<CatchUpScreen> createState() => _CatchUpScreenState();
}

class _CatchUpScreenState extends ConsumerState<CatchUpScreen> {
  final _text = TextEditingController();
  bool _busy = false;
  CatchUpResult? _result;
  bool _alreadyMarked = false;
  final _accounts = <int, int?>{};
  final _decisions = <int, _Decision>{};

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    setState(
      () => _text.text = _text.text.trim().isEmpty
          ? text
          : '${_text.text.trim()}\n\n$text',
    );
  }

  Future<void> _check() async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(catchUpServiceProvider)
          .fromText(_text.text);
      if (!mounted) return;
      setState(() {
        _result = result;
        _alreadyMarked = false;
        _decisions.clear();
        _accounts
          ..clear()
          ..addAll({for (final r in result.missing) r.id: r.accountId});
      });
    } catch (e) {
      if (mounted) _snack(describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _statement() => importSpreadsheet(
    context,
    ref,
    since: CatchUpService.since(DateTime.now()),
  );

  Future<bool> _add(DetectedPayment row) async {
    final accountId = _accounts[row.id];
    if (accountId == null) {
      _snack(context.l10n.catchUpChooseAccount);
      return false;
    }
    try {
      await ref
          .read(detectionServiceProvider)
          .confirm(row.id, draft: DetectionDraft(accountId: accountId));
      if (mounted) setState(() => _decisions[row.id] = _Decision.added);
      return true;
    } catch (e) {
      if (mounted) _snack(describeError(e));
      return false;
    }
  }

  Future<void> _skip(DetectedPayment row) async {
    await ref.read(detectionServiceProvider).dismiss(row.id);
    if (mounted) setState(() => _decisions[row.id] = _Decision.skipped);
  }

  Future<void> _addAll() async {
    for (final row in _result!.missing) {
      if (_decisions.containsKey(row.id) || _accounts[row.id] == null) continue;
      if (!await _add(row)) break;
    }
  }

  Future<void> _markAlready() async {
    await ref.read(catchUpServiceProvider).markRecorded(_result!.already);
    if (mounted) setState(() => _alreadyMarked = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final secondary = AppTextStyles.body.copyWith(
      color: AppColors.textSecondary(context),
    );
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: Text(l.catchUpTitle)),
      body: LiquidPageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Sp.screenH,
            Sp.lg,
            Sp.screenH,
            Sp.xxxl,
          ),
          children: [
            Text(l.catchUpIntro, style: secondary),
            const SizedBox(height: Sp.lg),
            _card(
              icon: Icons.sms_outlined,
              title: l.catchUpPasteTitle,
              body: l.catchUpPasteBody,
              children: [
                TextField(
                  controller: _text,
                  minLines: 3,
                  maxLines: 8,
                  decoration: InputDecoration(hintText: l.catchUpPasteHint),
                ),
                const SizedBox(height: Sp.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _paste,
                        icon: const Icon(Icons.content_paste_go),
                        label: Text(l.paste),
                      ),
                    ),
                    const SizedBox(width: Sp.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _check,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.fact_check_outlined),
                        label: Text(l.catchUpCheck),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (result != null) ..._results(context, result),
            const SizedBox(height: Sp.lg),
            _card(
              icon: Icons.description_outlined,
              title: l.catchUpStatementTitle,
              body: l.catchUpStatementBody,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _statement,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(l.catchUpChooseFile),
                ),
              ],
            ),
            if (Platform.isIOS) ...[
              const SizedBox(height: Sp.lg),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
                child: ListTile(
                  leading: const Icon(Icons.bolt_rounded),
                  title: Text(l.iosGuideTitle),
                  subtitle: Text(l.iosGuideSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/detection/iphone'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String body,
    required List<Widget> children,
  }) => AppCard(
    padding: const EdgeInsets.all(Sp.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: Sp.sm),
            Expanded(child: Text(title, style: AppTextStyles.subtitle)),
          ],
        ),
        const SizedBox(height: Sp.xs),
        Text(
          body,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: Sp.md),
        ...children,
      ],
    ),
  );

  List<Widget> _results(BuildContext context, CatchUpResult result) {
    final l = context.l10n;
    final low = AppTextStyles.caption.copyWith(
      color: AppColors.textSecondary(context),
    );
    final accounts =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    final open = result.missing
        .where((r) => !_decisions.containsKey(r.id))
        .toList();
    final addable = open.where((r) => _accounts[r.id] != null).length;
    final skipped = [
      if (result.older > 0) l.catchUpOlder(result.older),
      if (result.ignored > 0) l.catchUpIgnored(result.ignored),
      if (result.repeated > 0) l.catchUpRepeated(result.repeated),
    ];
    return [
      const SizedBox(height: Sp.lg),
      AppCard(
        padding: const EdgeInsets.all(Sp.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  result.missing.isEmpty
                      ? Icons.verified_rounded
                      : Icons.playlist_add_check_rounded,
                  color: result.missing.isEmpty
                      ? AppColors.income
                      : AppColors.primary,
                ),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Text(
                    result.missing.isEmpty
                        ? l.catchUpAllCaughtUp
                        : l.catchUpMissingHeader(result.missing.length),
                    style: AppTextStyles.subtitle,
                  ),
                ),
              ],
            ),
            if (skipped.isNotEmpty) ...[
              const SizedBox(height: Sp.xs),
              Text(skipped.join(' · '), style: low),
            ],
            if (addable > 1) ...[
              const SizedBox(height: Sp.md),
              FilledButton.icon(
                onPressed: _addAll,
                icon: const Icon(Icons.done_all_rounded),
                label: Text(l.catchUpAddAll(addable)),
              ),
            ],
          ],
        ),
      ),
      for (final row in result.missing)
        Padding(
          padding: const EdgeInsets.only(top: Sp.md),
          child: _MissingCard(
            row: row,
            accounts: accounts,
            accountId: _accounts[row.id],
            decision: _decisions[row.id],
            onAccount: (id) => setState(() => _accounts[row.id] = id),
            onAdd: () => _add(row),
            onSkip: () => _skip(row),
          ),
        ),
      if (result.already.isNotEmpty) ...[
        const SizedBox(height: Sp.md),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            title: Text(
              l.catchUpAlreadyHeader(result.already.length),
              style: AppTextStyles.subtitle,
            ),
            children: [
              for (final a in result.already)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(a.payment.merchant ?? kindLabel(a.payment.kind)),
                  trailing: Text(
                    _amount(a.payment),
                    textDirection: TextDirection.ltr,
                    style: AppTextStyles.numberSmall,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.md),
                child: _alreadyMarked
                    ? Text(l.catchUpAdded, style: low)
                    : OutlinedButton(
                        onPressed: _markAlready,
                        child: Text(l.catchUpMarkRecorded),
                      ),
              ),
            ],
          ),
        ),
      ],
    ];
  }
}

String _amount(DetectedPayment row) {
  if (row.amount == null) return '—';
  final sign = row.direction == 'income' ? '+' : '−';
  return '$sign${CurrencyFormatter.format(double.parse(row.amount!), currency: row.currency ?? '')}';
}

class _MissingCard extends ConsumerWidget {
  const _MissingCard({
    required this.row,
    required this.accounts,
    required this.accountId,
    required this.decision,
    required this.onAccount,
    required this.onAdd,
    required this.onSkip,
  });

  final DetectedPayment row;
  final List<Account> accounts;
  final int? accountId;
  final _Decision? decision;
  final ValueChanged<int?> onAccount;
  final VoidCallback onAdd, onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final low = AppTextStyles.caption.copyWith(
      color: AppColors.textSecondary(context),
    );
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final category = categories
        .where((c) => c.id == row.categoryId)
        .firstOrNull;
    final when = row.occurredAt ?? row.receivedAt;
    final done = decision != null;
    return Opacity(
      opacity: done ? 0.55 : 1,
      child: AppCard(
        padding: const EdgeInsets.all(Sp.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.merchant ?? kindLabel(row.kind),
                        style: AppTextStyles.bodyMedium,
                      ),
                      Text(
                        [
                          DateFormat.MMMd(
                            Localizations.localeOf(context).toString(),
                          ).format(when),
                          kindLabel(row.kind),
                          ?category?.name,
                        ].join(' · '),
                        style: low,
                      ),
                    ],
                  ),
                ),
                Text(
                  _amount(row),
                  textDirection: TextDirection.ltr,
                  style: AppTextStyles.number.copyWith(
                    color: row.direction == 'income' ? AppColors.income : null,
                  ),
                ),
              ],
            ),
            if (!done) ...[
              const SizedBox(height: Sp.md),
              DropdownButtonFormField<int>(
                initialValue: accountId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.account),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name} · ${a.currency}'),
                    ),
                ],
                onChanged: onAccount,
              ),
              const SizedBox(height: Sp.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onSkip, child: Text(l.catchUpSkip)),
                  const SizedBox(width: Sp.sm),
                  FilledButton(onPressed: onAdd, child: Text(l.catchUpAdd)),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: Sp.sm),
                child: Text(
                  decision == _Decision.added
                      ? l.catchUpAdded
                      : l.catchUpSkipped,
                  style: low.copyWith(
                    color: decision == _Decision.added
                        ? AppColors.income
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
