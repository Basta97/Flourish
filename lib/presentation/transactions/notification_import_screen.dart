import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';

import 'package:flourish/core/detection/message_splitter.dart';
import 'package:flourish/core/detection/parsed_payment.dart';
import 'package:flourish/core/models/shared_import_draft.dart';
import 'package:flourish/core/services/shared_import_service.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/utils/error_text.dart';
import 'package:flourish/presentation/providers/ai_providers.dart';
import 'package:flourish/presentation/providers/finance_providers.dart';
import 'package:flourish/shared/widgets/app_card.dart';
import 'package:flourish/shared/widgets/liquid_page.dart';

/// Three buttons share one row on a phone, so trim the theme's generous
/// horizontal padding; otherwise the labels wrap letter-by-letter.
final ButtonStyle _compactButton = ButtonStyle(
  padding: WidgetStateProperty.all(
    const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 14),
  ),
  iconSize: WidgetStateProperty.all(18),
);

/// Smart Import: paste, share or photograph one or many bank alerts. Every
/// message goes through the same detection as captured notifications and
/// lands in the payments inbox for review.
class NotificationImportScreen extends ConsumerStatefulWidget {
  const NotificationImportScreen({super.key, this.initialDraft});

  final SharedImportDraft? initialDraft;

  @override
  ConsumerState<NotificationImportScreen> createState() =>
      _NotificationImportScreenState();
}

class _NotificationImportScreenState
    extends ConsumerState<NotificationImportScreen> {
  final _text = TextEditingController();
  bool _busy = false;
  String? _imagePath;
  bool _attachReceipt = false;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.initialDraft?.imagePath;
    WidgetsBinding.instance.addPostFrameCallback((_) => _seed());
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _seed() async {
    final draft = widget.initialDraft;
    if (draft == null) return;
    final text = draft.bestText;
    if (text.isNotEmpty) {
      setState(() => _text.text = text);
    } else if (draft.imagePath != null) {
      await _recognize(draft.imagePath!);
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    setState(() => _text.text = text);
    await _analyze();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.firstOrNull?.path;
    if (path == null) return;
    setState(() => _imagePath = path);
    await _recognize(path);
  }

  Future<void> _recognize(String path) async {
    setState(() => _busy = true);
    try {
      final text = await SharedImportService.recognizeImage(path);
      if (!mounted) return;
      if (text.trim().isEmpty) {
        _snack('No readable text found. Type or paste the alert instead.');
        return;
      }
      setState(() => _text.text = text);
    } catch (e) {
      if (mounted) _snack('Text recognition failed: ${describeError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Splits the text into messages, detects each one, and opens the inbox.
  Future<void> _analyze() async {
    final messages = MessageSplitter.split(_text.text);
    if (messages.isEmpty) return;
    setState(() => _busy = true);
    final service = ref.read(detectionServiceProvider);
    final source = switch (widget.initialDraft?.source) {
      final s? when s.isNotEmpty => s,
      _ => _imagePath != null ? 'ocr' : 'paste',
    };
    final added = <int>[];
    try {
      final now = DateTime.now();
      for (final m in messages) {
        final row = await service.ingest(
          RawMessage(
            text: m,
            receivedAt: now,
            source: source,
            sender: widget.initialDraft?.sender,
          ),
        );
        if (row != null) added.add(row.id);
      }
      String? aiNote;
      if (added.isNotEmpty) {
        try {
          await service.assistPending();
        } catch (e) {
          aiNote = 'AI unavailable, showing on-device results';
        }
      }
      if (_attachReceipt && _imagePath != null && added.length == 1) {
        final dir = await getApplicationDocumentsDirectory();
        final kept = await File(_imagePath!).copy(
          paths.join(
            dir.path,
            'receipt-${DateTime.now().microsecondsSinceEpoch}${paths.extension(_imagePath!)}',
          ),
        );
        await service.attachReceipt(added.single, kept.path);
      }
      if (!mounted) return;
      final skipped = messages.length - added.length;
      _snack(
        [
          if (added.isEmpty)
            'No new payments found'
          else
            '${added.length} payment${added.length == 1 ? '' : 's'} ready to review',
          if (skipped > 0)
            '$skipped skipped (codes, offers, notices or already added)',
          ?aiNote,
        ].join(' · '),
      );
      if (added.isNotEmpty) context.pushReplacement('/inbox');
    } catch (e) {
      if (mounted) _snack('Could not analyse: ${describeError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.initialDraft;
    final aiReady = ref.watch(aiAssistProvider).valueOrNull != null;
    final secondary = AppTextStyles.body.copyWith(
      color: AppColors.textSecondary(context),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Import')),
      body: LiquidPageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Sp.screenH,
            Sp.lg,
            Sp.screenH,
            Sp.xxxl,
          ),
          children: [
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
                      _imagePath != null
                          ? Icons.photo_camera_back_outlined
                          : Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: Sp.lg),
                  Text(
                    _imagePath != null
                        ? 'Review shared payment screenshot'
                        : 'Paste bank, wallet or Apple Pay alerts',
                    style: AppTextStyles.title,
                  ),
                  const SizedBox(height: Sp.sm),
                  Text(
                    'Paste one alert or many at once. Each one is read on '
                    'your phone and added to Payments to review.',
                    style: secondary,
                  ),
                  if (_imagePath != null) ...[
                    const SizedBox(height: Sp.lg),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Rad.lg),
                      child: Image.file(
                        File(_imagePath!),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Keep this image as a receipt'),
                      value: _attachReceipt,
                      onChanged: (v) => setState(() => _attachReceipt = v),
                    ),
                  ],
                  const SizedBox(height: Sp.lg),
                  TextField(
                    controller: _text,
                    minLines: 4,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: draft?.source == null
                          ? 'Alert text'
                          : 'Alert text (from ${draft!.source})',
                      hintText:
                          'Example: Apple Pay: Card 1234 spent 24.90 USD at Starbucks',
                    ),
                  ),
                  const SizedBox(height: Sp.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _paste,
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
                          onPressed: _busy ? null : _analyze,
                          style: _compactButton,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: const Text('Analyze'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.lg),
            Row(
              children: [
                Icon(
                  aiReady ? Icons.psychology_alt_outlined : Icons.memory_rounded,
                  size: 18,
                  color: AppColors.textSecondary(context),
                ),
                const SizedBox(width: Sp.sm),
                Expanded(
                  child: Text(
                    aiReady
                        ? 'Unclear alerts get a second reading from AI.'
                        : 'Read on your phone. Add an AI provider for tricky alerts.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/settings/ai'),
                  child: Text(aiReady ? 'AI settings' : 'Set up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
