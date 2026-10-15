import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as paths;
import '../../core/services/shared_import_service.dart';
import 'package:flourish/presentation/providers/finance_providers.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flourish/core/models/shared_import_draft.dart';
import 'package:flourish/core/services/transaction_notification_parser.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/providers/account_providers.dart';
import 'package:flourish/presentation/providers/category_providers.dart';
import 'package:flourish/presentation/providers/theme_providers.dart';
import 'package:flourish/presentation/providers/transaction_providers.dart';
import 'package:flourish/shared/widgets/app_card.dart';
import 'package:flourish/shared/widgets/category_icon_widget.dart';
import 'package:flourish/shared/widgets/liquid_page.dart';

class NotificationImportScreen extends ConsumerStatefulWidget {
  const NotificationImportScreen({super.key, this.initialDraft});

  final SharedImportDraft? initialDraft;

  @override
  ConsumerState<NotificationImportScreen> createState() =>
      _NotificationImportScreenState();
}

class _NotificationImportScreenState
    extends ConsumerState<NotificationImportScreen> {
  final _notificationController = TextEditingController();
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();

  ParsedTransactionNotification? _parsed;
  String _type = 'expense';
  int? _accountId;
  int? _categoryId;
  bool _saving = false;
  bool _didSeedInitialDraft = false;
  String? _selectedImagePath;
  bool _attachReceipt = false;
  @override
  void initState() {
    super.initState();
    _selectedImagePath = widget.initialDraft?.imagePath;
  }

  @override
  void dispose() {
    _notificationController.dispose();
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _parseNotification(List<Category> categories) {
    final parsed = TransactionNotificationParser.parse(
      _notificationController.text,
    );
    final matchedCategory = _suggestCategory(categories, parsed);
    setState(() {
      _parsed = parsed;
      _type = parsed.type;
      _merchantController.text = parsed.merchant;
      _amountController.text = parsed.amount?.toStringAsFixed(2) ?? '';
      _categoryId = matchedCategory?.id;
    });
  }

  void _seedFromDraft(List<Category> categories) {
    if (_didSeedInitialDraft) return;
    final draft = widget.initialDraft;
    if (draft == null) return;
    _didSeedInitialDraft = true;
    final text = draft.bestText;
    if (text.isEmpty && draft.imagePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final recognized = await SharedImportService.recognizeImage(
            draft.imagePath!,
          );
          if (mounted) {
            _notificationController.text = recognized;
            _parseNotification(categories);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Image recognition failed: $e')),
            );
          }
        }
      });
      return;
    }
    if (text.isEmpty) return;
    _notificationController.text = text;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _parseNotification(categories);
    });
  }

  Category? _suggestCategory(
    List<Category> categories,
    ParsedTransactionNotification parsed,
  ) {
    final filtered = categories.where((c) => c.type == parsed.type).toList();
    if (filtered.isEmpty) return null;
    final keyword = parsed.suggestedCategoryKeyword;
    if (keyword == null) return filtered.first;
    return filtered
        .where((c) => c.name.toLowerCase().contains(keyword))
        .cast<Category?>()
        .firstWhere((c) => c != null, orElse: () => filtered.first);
  }

  Future<void> _pasteFromClipboard(List<Category> categories) async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text == null || data!.text!.trim().isEmpty) return;
    _notificationController.text = data.text!;
    _parseNotification(categories);
  }

  Future<void> _pickPhoto(List<Category> categories) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    setState(() => _selectedImagePath = path);
    try {
      final text = await SharedImportService.recognizeImage(path);
      if (!mounted) return;
      _notificationController.text = text;
      _parseNotification(categories);
      if (text.trim().isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'No readable text found. Type or paste the transaction text.',
            ),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Text recognition failed: $e')),
      );
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null ||
        amount <= 0 ||
        _accountId == null ||
        _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select account, category, and a valid amount first.'),
        ),
      );
      return;
    }

    final prior = ref.read(transactionsProvider).valueOrNull ?? [];
    if (prior.any(
      (t) =>
          t.accountId == _accountId &&
          t.type == _type &&
          (t.amount - amount).abs() < 0.005 &&
          DateTime.now().difference(t.createdAt).inDays < 2,
    )) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Possible duplicate'),
          content: const Text(
            'A recent transaction has the same account, type, and amount. Save another one?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save another'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      final merchant = _merchantController.text.trim();
      final rawNote = _notificationController.text.trim();
      final source = widget.initialDraft?.source;
      final note = [
        if (merchant.isNotEmpty) merchant,
        if (source != null && source.isNotEmpty) 'Source: $source',
        if (rawNote.isNotEmpty) 'Imported from notification: $rawNote',
      ].join(' • ');

      File? retained;
      try {
        if (_attachReceipt && _selectedImagePath != null) {
          final directory = await getApplicationDocumentsDirectory();
          retained = await File(_selectedImagePath!).copy(
            paths.join(
              directory.path,
              'receipt-${DateTime.now().microsecondsSinceEpoch}${paths.extension(_selectedImagePath!)}',
            ),
          );
        }
        await ref.read(databaseProvider).transaction(() async {
          final tx = await ref
              .read(financialLedgerProvider)
              .recordCash(
                accountId: _accountId!,
                amount: Amount.fromNum(amount),
                type: _type,
                categoryId: _categoryId!,
                note: note.isEmpty ? null : note,
              );
          if (retained != null) {
            final id = ref.read(financialLedgerProvider).newId();
            await ref.read(financeStoreProvider).put('attachments', id, {
              'id': id,
              'path': retained.path,
              'transactionId': tx,
              'date': DateTime.now().toIso8601String(),
            });
          }
        });
      } catch (_) {
        if (retained != null && await retained.exists()) {
          await retained.delete();
        }
        rethrow;
      }

      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction created from notification.'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Could not save: $e")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final currency =
        accountsAsync.valueOrNull
            ?.where((a) => a.id == _accountId)
            .firstOrNull
            ?.currency ??
        ref.watch<String>(defaultCurrencyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Smart Import')),
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
              _seedDraftMarker(categories),
              if (_selectedImagePath != null)
                SwitchListTile(
                  title: const Text('Keep this image as a receipt'),
                  value: _attachReceipt,
                  onChanged: (value) => setState(() => _attachReceipt = value),
                ),
              AppCard(
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
                        widget.initialDraft?.imagePath != null
                            ? Icons.photo_camera_back_outlined
                            : Icons.auto_awesome_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: Sp.lg),
                    Text(
                      widget.initialDraft?.imagePath != null
                          ? 'Review shared payment screenshot'
                          : 'Paste Apple Pay or bank alerts',
                      style: AppTextStyles.title,
                    ),
                    const SizedBox(height: Sp.sm),
                    Text(
                      widget.initialDraft?.source == 'share-extension'
                          ? 'This draft came from the iOS share sheet. Flourish extracted text from the shared content and prepared a transaction draft for review.'
                          : 'iOS does not allow Flourish to read other apps\' notifications directly. Paste the alert text here and Flourish will extract the transaction details for you.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    if (widget.initialDraft?.imagePath != null) ...[
                      const SizedBox(height: Sp.lg),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Rad.lg),
                        child: Image.file(
                          File(widget.initialDraft!.imagePath!),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 140,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.glass(context),
                                  borderRadius: BorderRadius.circular(Rad.lg),
                                ),
                                child: Text(
                                  'Shared screenshot ready for review',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Sp.lg),
                    TextField(
                      controller: _notificationController,
                      minLines: 4,
                      maxLines: 7,
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
                            onPressed: () => _pasteFromClipboard(categories),
                            icon: const Icon(Icons.content_paste_go),
                            label: const Text('Paste'),
                          ),
                        ),
                        const SizedBox(width: Sp.md),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickPhoto(categories),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Photo'),
                          ),
                        ),
                        const SizedBox(width: Sp.md),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _parseNotification(categories),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Analyze'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Sp.lg),
              if (_parsed != null) ...[
                AppCard(
                  padding: const EdgeInsets.all(Sp.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(Sp.md),
                            decoration: BoxDecoration(
                              color:
                                  (_parsed!.isExpense
                                          ? AppColors.expense
                                          : AppColors.income)
                                      .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(Rad.md),
                            ),
                            child: Icon(
                              _parsed!.isExpense
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: _parsed!.isExpense
                                  ? AppColors.expense
                                  : AppColors.income,
                            ),
                          ),
                          const SizedBox(width: Sp.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Detection confidence',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                                const SizedBox(height: Sp.xs),
                                Text(
                                  '${(_parsed!.confidence * 100).round()}%',
                                  style: AppTextStyles.number,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Sp.lg),
                      LinearProgressIndicator(
                        value: _parsed!.confidence,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(Rad.full),
                        backgroundColor: AppColors.glassStroke(context),
                      ),
                      const SizedBox(height: Sp.lg),
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
                        selected: {_type},
                        onSelectionChanged: (value) =>
                            setState(() => _type = value.first),
                      ),
                      const SizedBox(height: Sp.md),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixText:
                              '${CurrencyFormatter.symbolFor(currency)} ',
                        ),
                      ),
                      const SizedBox(height: Sp.md),
                      TextField(
                        controller: _merchantController,
                        decoration: const InputDecoration(
                          labelText: 'Merchant or note title',
                        ),
                      ),
                      if (widget.initialDraft?.source != null) ...[
                        const SizedBox(height: Sp.md),
                        AppCard.outlined(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Sp.md,
                            vertical: Sp.sm,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.link_rounded, size: 16),
                              const SizedBox(width: Sp.sm),
                              Text(
                                'Source: ${widget.initialDraft!.source}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: Sp.md),
                      accountsAsync.when(
                        data: (accounts) {
                          final defaultAccountId =
                              _accountId ??
                              (accounts.isNotEmpty ? accounts.first.id : null);
                          if (_accountId == null && defaultAccountId != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && _accountId == null) {
                                setState(() => _accountId = defaultAccountId);
                              }
                            });
                          }
                          return DropdownButtonFormField<int>(
                            initialValue: defaultAccountId,
                            decoration: const InputDecoration(
                              labelText: 'Account',
                            ),
                            items: accounts
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(a.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _accountId = value),
                          );
                        },
                        loading: () => const SizedBox(height: 60),
                        error: (error, stackTrace) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: Sp.md),
                      DropdownButtonFormField<int>(
                        initialValue: _resolvedCategoryValue(categories),
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: categories
                            .where((c) => c.type == _type)
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Row(
                                  children: [
                                    CategoryIconWidget(
                                      iconName: c.icon,
                                      color: Color(c.color),
                                      size: 28,
                                      iconSize: 14,
                                    ),
                                    const SizedBox(width: Sp.sm),
                                    Text(c.name),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _categoryId = value),
                      ),
                      const SizedBox(height: Sp.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Create Transaction'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Failed to load categories: $error')),
        ),
      ),
    );
  }

  int? _resolvedCategoryValue(List<Category> categories) {
    final filtered = categories.where((c) => c.type == _type).toList();
    if (filtered.isEmpty) return null;
    if (_categoryId != null && filtered.any((c) => c.id == _categoryId)) {
      return _categoryId;
    }
    return filtered.first.id;
  }

  Widget _seedDraftMarker(List<Category> categories) {
    _seedFromDraft(categories);
    return const SizedBox.shrink();
  }
}
