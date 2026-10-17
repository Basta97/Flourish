import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:flourish/core/detection/category_resolver.dart';
import 'package:flourish/core/detection/detection_pipeline.dart';
import 'package:flourish/core/detection/local_parser.dart';
import 'package:flourish/core/detection/text_normalizer.dart';
import 'package:flourish/core/detection/transaction_candidate.dart';
import 'package:flourish/core/models/shared_import_draft.dart';
import 'package:flourish/core/services/shared_import_service.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/providers/account_providers.dart';
import 'package:flourish/presentation/providers/category_providers.dart';
import 'package:flourish/presentation/providers/detection_providers.dart';
import 'package:flourish/presentation/providers/finance_providers.dart';
import 'package:flourish/presentation/providers/transaction_providers.dart';
import 'package:flourish/shared/widgets/app_card.dart';
import 'package:flourish/shared/widgets/category_icon_widget.dart';
import 'package:flourish/shared/widgets/liquid_page.dart';

/// Three buttons share one row on a phone, so trim the theme's generous
/// horizontal padding; otherwise the labels wrap letter-by-letter.
final ButtonStyle _compactButton = ButtonStyle(
  padding: WidgetStateProperty.all(
    const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 14),
  ),
  iconSize: WidgetStateProperty.all(18),
);

/// Dropdown value standing for "the new category the resolver proposed".
const _newCategoryValue = -1;

/// Smart Import: paste / share / photograph bank alerts (or hand over rows
/// from a file), review every detected transaction, and save them together.
class NotificationImportScreen extends ConsumerStatefulWidget {
  const NotificationImportScreen({
    super.key,
    this.initialDraft,
    this.initialCandidates,
    this.sourceLabel,
  });

  final SharedImportDraft? initialDraft;

  /// Pre-parsed rows (file imports); skips the text input card.
  final List<TransactionCandidate>? initialCandidates;
  final String? sourceLabel;

  @override
  ConsumerState<NotificationImportScreen> createState() =>
      _NotificationImportScreenState();
}

class _ReviewDraft {
  _ReviewDraft(this.item, CategoryResolution resolution)
    : include = item.selectedByDefault,
      type = item.candidate.type,
      accountId = item.accountId,
      date = item.candidate.date ?? DateTime.now() {
    amount.text = item.candidate.amount?.fixed(_decimals(item.candidate)) ?? '';
    merchant.text = item.candidate.merchant;
    applyCategory(resolution);
  }

  final DetectedItem item;
  final amount = TextEditingController();
  final merchant = TextEditingController();
  bool include;
  String type;
  int? accountId;
  int? categoryId;
  ProposedCategory? newCategory;
  CategoryReason? reason;
  DateTime date;
  bool alwaysUse = false;

  TransactionCandidate get candidate => item.candidate;

  static int _decimals(TransactionCandidate c) =>
      TextNormalizer.threeDecimalCurrencies.contains(c.currency) ? 3 : 2;

  void applyCategory(CategoryResolution r) {
    categoryId = r.categoryId;
    newCategory = r.categoryId == null ? r.proposed : null;
    reason = r.reason;
  }

  void dispose() {
    amount.dispose();
    merchant.dispose();
  }
}

class _NotificationImportScreenState
    extends ConsumerState<NotificationImportScreen> {
  final _notificationController = TextEditingController();
  final List<_ReviewDraft> _drafts = [];
  CategoryResolver? _resolver;
  bool _busy = false;
  bool _saving = false;
  bool _analyzed = false;
  bool _aiUsed = false;
  String? _aiError;
  String? _selectedImagePath;
  bool _attachReceipt = false;

  @override
  void initState() {
    super.initState();
    _selectedImagePath = widget.initialDraft?.imagePath;
    WidgetsBinding.instance.addPostFrameCallback((_) => _seed());
  }

  @override
  void dispose() {
    _notificationController.dispose();
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _seed() async {
    final rows = widget.initialCandidates;
    if (rows != null) {
      await _run((p) => p.enrich(rows));
      return;
    }
    final draft = widget.initialDraft;
    if (draft == null) return;
    final text = draft.bestText;
    if (text.isNotEmpty) {
      _notificationController.text = text;
      await _analyze();
      return;
    }
    if (draft.imagePath != null) await _recognize(draft.imagePath!);
  }

  Future<void> _analyze({bool forceAi = false}) async {
    final text = _notificationController.text.trim();
    if (text.isEmpty) return;
    await _run((p) => p.detectText(text, forceAi: forceAi));
  }

  /// Re-runs only the AI stage on what is already in review.
  Future<void> _askAi() async {
    if (widget.initialCandidates != null) {
      final rows = _drafts.map((d) => d.candidate).toList();
      await _run((p) => p.enrich(rows, forceAi: true));
    } else {
      await _analyze(forceAi: true);
    }
  }

  Future<void> _run(
    Future<DetectionResult> Function(DetectionPipeline) detect,
  ) async {
    setState(() => _busy = true);
    try {
      final pipeline = await ref.read(detectionPipelineProvider.future);
      final result = await detect(pipeline);
      final resolver = await pipeline.learning.resolver(
        allowNewCategories: ref.read(aiSettingsProvider).allowNewCategories,
      );
      if (!mounted) return;
      setState(() {
        for (final d in _drafts) {
          d.dispose();
        }
        _drafts
          ..clear()
          ..addAll(result.items.map((i) => _ReviewDraft(i, i.category)));
        _resolver = resolver;
        _aiError = result.aiError;
        _aiUsed = result.aiUsed;
        _analyzed = true;
      });
    } catch (e) {
      if (mounted) _snack('Could not analyse: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text == null || data!.text!.trim().isEmpty) return;
    _notificationController.text = data.text!;
    await _analyze();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.firstOrNull?.path;
    if (path == null) return;
    setState(() => _selectedImagePath = path);
    await _recognize(path);
  }

  Future<void> _recognize(String path) async {
    try {
      final text = await SharedImportService.recognizeImage(path);
      if (!mounted) return;
      _notificationController.text = text;
      if (text.trim().isEmpty) {
        _snack('No readable text found. Type or paste the transaction text.');
        return;
      }
      await _analyze();
    } catch (e) {
      if (mounted) _snack('Text recognition failed: $e');
    }
  }

  void _snack(String message, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message), action: action));

  void _changeType(_ReviewDraft d, String type) {
    setState(() {
      d.type = type;
      final r = _resolver?.resolve(d.candidate, type: type);
      if (r != null) {
        d.applyCategory(r);
      } else {
        d.categoryId = null;
        d.newCategory = null;
      }
    });
  }

  Future<void> _pickDate(_ReviewDraft d) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: d.date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(
        () => d.date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          d.date.hour,
          d.date.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    final selected = _drafts.where((d) => d.include).toList();
    if (selected.isEmpty) {
      _snack('Select at least one transaction to save.');
      return;
    }
    for (final (i, d) in selected.indexed) {
      final amount = TextNormalizer.parseAmount(
        d.amount.text,
        currency: d.candidate.currency,
      );
      if (amount == null ||
          d.accountId == null ||
          (d.categoryId == null && d.newCategory == null)) {
        _snack(
          'Item ${i + 1}: choose an account, a category and a valid amount.',
        );
        return;
      }
    }

    setState(() => _saving = true);
    final ledger = ref.read(financialLedgerProvider);
    final pipeline = await ref.read(detectionPipelineProvider.future);
    final batchId = const Uuid().v4();
    final source =
        widget.sourceLabel ?? widget.initialDraft?.source ?? 'smart-import';
    File? retained;
    try {
      if (_attachReceipt && _selectedImagePath != null && selected.length == 1) {
        final directory = await getApplicationDocumentsDirectory();
        retained = await File(_selectedImagePath!).copy(
          paths.join(
            directory.path,
            'receipt-${DateTime.now().microsecondsSinceEpoch}${paths.extension(_selectedImagePath!)}',
          ),
        );
      }
      await ref.read(databaseProvider).transaction(() async {
        for (final d in selected) {
          final merchant = d.merchant.text.trim();
          final merchantKey = LocalTransactionParser.normalizeMerchant(merchant);
          final categoryId =
              d.categoryId ??
              await pipeline.learning.ensureCategory(
                ProposedCategory(
                  name: d.newCategory!.name,
                  type: d.type,
                  icon: d.newCategory!.icon,
                  colorIndex: d.newCategory!.colorIndex,
                  parentName: d.newCategory!.parentName,
                ),
              );
          final id = await ledger.recordCash(
            accountId: d.accountId!,
            amount: TextNormalizer.parseAmount(
              d.amount.text,
              currency: d.candidate.currency,
            )!,
            type: d.type,
            categoryId: categoryId,
            note: merchant.isEmpty ? null : merchant,
            date: d.date,
          );
          await ledger.annotate(id, {
            'merchant': merchant,
            'merchantKey': merchantKey,
            'source': source,
            'importBatchId': batchId,
            'rawText': d.candidate.rawText,
            if (d.candidate.currency != null)
              'originalCurrency': d.candidate.currency,
          });
          final learned = d.candidate.copyWith(merchantKey: merchantKey);
          await pipeline.learnFromSave(
            learned,
            accountId: d.accountId!,
            categoryId: categoryId,
            type: d.type,
          );
          if (d.alwaysUse && merchantKey.isNotEmpty) {
            await pipeline.learning.addRule(
              pattern: merchantKey,
              categoryId: categoryId,
              type: d.type,
            );
          }
          if (retained != null) {
            final attachmentId = ledger.newId();
            await ref.read(financeStoreProvider).put('attachments', attachmentId, {
              'id': attachmentId,
              'path': retained.path,
              'transactionId': id,
              'date': DateTime.now().toIso8601String(),
            });
          }
        }
      });
      await rememberImportAccount(selected.last.accountId!);
      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(categoriesProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            selected.length == 1
                ? 'Transaction saved.'
                : '${selected.length} transactions saved.',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await ledger.undoImportBatch(batchId);
              ref.invalidate(transactionsProvider);
              ref.invalidate(accountsProvider);
            },
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (retained != null && await retained.exists()) await retained.delete();
      if (mounted) _snack('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final categoriesAsync = ref.watch(categoriesProvider);
    final aiReady = ref.watch(aiExtractorProvider).valueOrNull != null;
    final fromFile = widget.initialCandidates != null;
    final selectedCount = _drafts.where((d) => d.include).length;

    return Scaffold(
      appBar: AppBar(title: Text(fromFile ? 'Review import' : 'Smart Import')),
      bottomNavigationBar: _drafts.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                Sp.screenH,
                Sp.sm,
                Sp.screenH,
                Sp.md,
              ),
              child: FilledButton.icon(
                onPressed: _saving || _busy || selectedCount == 0 ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  selectedCount == 1
                      ? 'Create transaction'
                      : 'Create $selectedCount transactions',
                ),
              ),
            ),
      body: LiquidPageBackground(
        child: categoriesAsync.when(
          data: (categories) => ListView(
            padding: const EdgeInsets.fromLTRB(
              Sp.screenH,
              Sp.lg,
              Sp.screenH,
              Sp.xxxl,
            ),
            children: [
              if (!fromFile) _inputCard(context),
              if (_selectedImagePath != null && _drafts.length == 1)
                SwitchListTile(
                  title: const Text('Keep this image as a receipt'),
                  value: _attachReceipt,
                  onChanged: (value) => setState(() => _attachReceipt = value),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(Sp.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_busy && _analyzed) _aiBar(context, aiReady),
              if (!_busy && _analyzed && _drafts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(Sp.lg),
                  child: Text(
                    'No transactions found in this text.',
                    style: AppTextStyles.body,
                  ),
                ),
              if (!_busy)
                for (final (i, d) in _drafts.indexed)
                  Padding(
                    padding: const EdgeInsets.only(top: Sp.lg),
                    child: _reviewCard(context, i, d, accounts, categories),
                  ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Failed to load categories: $error')),
        ),
      ),
    );
  }

  Widget _inputCard(BuildContext context) {
    final draft = widget.initialDraft;
    return AppCard(
      padding: const EdgeInsets.all(Sp.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Rad.lg),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.22),
                  AppColors.secondary.withValues(alpha: 0.12),
                ],
              ),
            ),
            child: Icon(
              draft?.imagePath != null
                  ? Icons.photo_camera_back_outlined
                  : Icons.auto_awesome_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: Sp.lg),
          Text(
            draft?.imagePath != null
                ? 'Review shared payment screenshot'
                : 'Paste bank, wallet or Apple Pay alerts',
            style: AppTextStyles.title,
          ),
          const SizedBox(height: Sp.sm),
          Text(
            draft?.source == 'share-extension'
                ? 'This draft came from the share sheet. Review what Flourish found below.'
                : 'Paste one alert or many at once. Flourish reads them on your phone and prepares each transaction for review.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          if (draft?.imagePath != null) ...[
            const SizedBox(height: Sp.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(Rad.lg),
              child: Image.file(
                File(draft!.imagePath!),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox(height: 0),
              ),
            ),
          ],
          const SizedBox(height: Sp.lg),
          TextField(
            controller: _notificationController,
            minLines: 4,
            maxLines: 9,
            decoration: const InputDecoration(
              labelText: 'Notification text',
              hintText:
                  'Example: Apple Pay: Card 1234 spent 24.90 USD at Starbucks',
            ),
          ),
          const SizedBox(height: Sp.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pasteFromClipboard,
                  style: _compactButton,
                  icon: const Icon(Icons.content_paste_go),
                  label: const Text('Paste'),
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickPhoto,
                  style: _compactButton,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Photo'),
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _analyze(),
                  style: _compactButton,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Analyze'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aiBar(BuildContext context, bool aiReady) {
    final secondary = AppTextStyles.caption.copyWith(
      color: AppColors.textSecondary(context),
    );
    final String message;
    if (_aiError != null) {
      message = 'AI unavailable — showing on-device results. $_aiError';
    } else if (_aiUsed) {
      message = 'Unclear messages were checked with AI.';
    } else if (aiReady) {
      message = 'Read on your phone. Not right? Ask the AI.';
    } else {
      message = 'Read on your phone. Add an AI provider for tricky messages.';
    }
    return Padding(
      padding: const EdgeInsets.only(top: Sp.lg),
      child: Row(
        children: [
          Icon(
            _aiError != null ? Icons.cloud_off_outlined : Icons.memory_rounded,
            size: 18,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(width: Sp.sm),
          Expanded(child: Text(message, style: secondary)),
          if (aiReady)
            TextButton(
              onPressed: _busy || _drafts.isEmpty ? null : _askAi,
              child: const Text('Ask AI'),
            )
          else
            TextButton(
              onPressed: () => context.push('/settings/ai'),
              child: const Text('Set up'),
            ),
        ],
      ),
    );
  }

  Widget _reviewCard(
    BuildContext context,
    int index,
    _ReviewDraft d,
    List<Account> accounts,
    List<Category> categories,
  ) {
    final c = d.candidate;
    final account = accounts.where((a) => a.id == d.accountId).firstOrNull;
    final currency = account?.currency ?? c.currency ?? 'USD';
    final ofType = categories.where((x) => x.type == d.type).toList();
    final categoryValue = d.categoryId != null && ofType.any((x) => x.id == d.categoryId)
        ? d.categoryId
        : d.newCategory != null
        ? _newCategoryValue
        : null;
    final expense = d.type == 'expense';
    final tint = expense ? AppColors.expense : AppColors.income;

    return Opacity(
      opacity: d.include ? 1 : 0.6,
      child: AppCard(
        padding: const EdgeInsets.all(Sp.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: d.include,
                  onChanged: (v) => setState(() => d.include = v ?? false),
                ),
                Container(
                  padding: const EdgeInsets.all(Sp.sm),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(Rad.md),
                  ),
                  child: Icon(
                    expense
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: tint,
                    size: 18,
                  ),
                ),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Text(
                    d.merchant.text.isNotEmpty
                        ? d.merchant.text
                        : 'Transaction ${index + 1}',
                    style: AppTextStyles.subtitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _ConfidenceChip(c.confidence, ai: c.source == CandidateSource.ai),
              ],
            ),
            ..._warnings(context, d, account),
            const SizedBox(height: Sp.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'expense',
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_downward_rounded),
                ),
                ButtonSegment(
                  value: 'income',
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
              ],
              selected: {d.type},
              onSelectionChanged: (v) => _changeType(d, v.first),
            ),
            const SizedBox(height: Sp.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: d.amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '${CurrencyFormatter.symbolFor(currency)} ',
                    ),
                  ),
                ),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(d),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: c.date != null ? 'Date (from alert)' : 'Date',
                        suffixIcon: const Icon(Icons.event_outlined, size: 18),
                      ),
                      child: Text(DateFormat.yMMMd().format(d.date)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.md),
            TextField(
              controller: d.merchant,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Merchant or note',
              ),
            ),
            const SizedBox(height: Sp.md),
            DropdownButtonFormField<int>(
              key: ValueKey('account-$index-${d.accountId}'),
              initialValue: d.accountId,
              decoration: const InputDecoration(labelText: 'Account'),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.name} · ${a.currency}'),
                  ),
              ],
              onChanged: (v) => setState(() => d.accountId = v),
            ),
            const SizedBox(height: Sp.md),
            DropdownButtonFormField<int>(
              key: ValueKey('category-$index-${d.type}-$categoryValue'),
              initialValue: categoryValue,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Category',
                helperText: _reasonLabel(d.reason),
              ),
              items: [
                if (d.newCategory != null)
                  DropdownMenuItem(
                    value: _newCategoryValue,
                    child: Text(
                      '✨ New: ${d.newCategory!.name}'
                      '${d.newCategory!.parentName == null ? '' : ' (under ${d.newCategory!.parentName})'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                for (final x in ofType)
                  DropdownMenuItem(
                    value: x.id,
                    child: Row(
                      children: [
                        CategoryIconWidget(
                          iconName: x.icon,
                          color: Color(x.color),
                          size: 28,
                          iconSize: 14,
                        ),
                        const SizedBox(width: Sp.sm),
                        Flexible(
                          child: Text(x.name, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() {
                if (v == _newCategoryValue) {
                  d.categoryId = null;
                } else {
                  d.categoryId = v;
                }
                d.reason = null;
              }),
            ),
            if (d.merchant.text.trim().length >= 2)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: d.alwaysUse,
                onChanged: (v) => setState(() => d.alwaysUse = v ?? false),
                title: Text(
                  'Always use this category for ${d.merchant.text.trim()}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _warnings(
    BuildContext context,
    _ReviewDraft d,
    Account? account,
  ) {
    final c = d.candidate;
    final notes = <(IconData, String)>[
      if (!c.kind.movesMoney)
        (Icons.block_outlined, 'Looks like ${_kindLabel(c.kind)}, not a transaction.'),
      if (c.amount == null && c.kind.movesMoney)
        (Icons.help_outline, 'No amount found — enter it before saving.'),
      if (d.item.duplicate?.kind == DuplicateKind.sameMessage)
        (Icons.content_copy_outlined, 'This alert was already imported.'),
      if (d.item.duplicate?.kind == DuplicateKind.similarTransaction)
        (
          Icons.content_copy_outlined,
          'A transaction with the same amount and account exists around this date.',
        ),
      if (account != null && c.currency != null && c.currency != account.currency)
        (
          Icons.currency_exchange,
          'The alert is in ${c.currency} but ${account.name} is in ${account.currency}. '
              'Pick a ${c.currency} account or enter the ${account.currency} amount.',
        ),
    ];
    return [
      for (final (icon, text) in notes)
        Padding(
          padding: const EdgeInsets.only(top: Sp.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppColors.warning),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  static String _kindLabel(TransactionKind kind) => switch (kind) {
    TransactionKind.otp => 'a verification code',
    TransactionKind.declined => 'a declined payment',
    TransactionKind.promo => 'an offer',
    TransactionKind.paymentDue => 'a payment reminder',
    TransactionKind.balanceOnly => 'a balance notice',
    _ => 'a notice',
  };

  static String? _reasonLabel(CategoryReason? reason) => switch (reason) {
    CategoryReason.rule => 'From your rule',
    CategoryReason.memory => 'Same as last time for this merchant',
    CategoryReason.history => 'Based on similar past transactions',
    CategoryReason.ai || CategoryReason.aiNew => 'Suggested by AI',
    CategoryReason.concept || CategoryReason.conceptNew => 'Suggested from the merchant',
    CategoryReason.fallback => 'No match — please check',
    null => null,
  };
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip(this.confidence, {required this.ai});
  final double confidence;
  final bool ai;

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.75
        ? AppColors.income
        : confidence >= 0.5
        ? AppColors.warning
        : AppColors.expense;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Rad.full),
      ),
      child: Text(
        '${ai ? 'AI · ' : ''}${(confidence * 100).round()}%',
        style: AppTextStyles.caption.copyWith(color: color),
      ),
    );
  }
}
