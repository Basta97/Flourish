import 'package:flourish/l10n/l10n.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';

import 'package:flourish/core/ai/ai_client.dart';
import 'package:flourish/core/ai/ai_screenshot_reader.dart';
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
import 'package:flourish/presentation/settings/screenshot_ai_disclosure.dart';
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

  /// Android's on-device reader (ML Kit Latin) cannot read Arabic, so
  /// there a screenshot may also be read by a vision model, on request.
  bool get _aiReadable =>
      defaultTargetPlatform == TargetPlatform.android &&
      _imagePath != null &&
      ref.read(aiClientProvider).valueOrNull != null;

  Future<void> _recognize(String path) async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final text = await SharedImportService.recognizeImage(path);
      if (!mounted) return;
      if (text.trim().isEmpty) {
        _snack(_aiReadable ? l.noTextTryAi : l.noTextTypeInstead);
        return;
      }
      setState(() => _text.text = text);
    } catch (e) {
      if (mounted) _snack(l.textRecognitionFailed(describeError(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readWithAi() async {
    final l = context.l10n;
    final path = _imagePath;
    final client = await ref.read(aiClientProvider.future);
    if (path == null || client == null || !mounted) return;
    var settings = ref.read(aiSettingsProvider);
    if (settings.preset.readsImages == false) {
      _snack(l.providerNoImagesSettings(settings.preset.label));
      return;
    }
    if (!settings.screenshotOcr) {
      if (!await confirmScreenshotAi(context, settings)) return;
      settings = settings.copyWith(screenshotOcr: true);
      ref.read(aiSettingsProvider.notifier).state = settings;
      await settings.save();
    }
    setState(() => _busy = true);
    try {
      final text =
          await AiScreenshotReader(
            client,
            usage: ref.read(aiUsageTrackerProvider),
          ).read(
            await File(path).readAsBytes(),
            mimeType: AiScreenshotReader.mimeTypeFor(path),
          );
      if (!mounted) return;
      if (text.isEmpty) {
        _snack(l.aiNoText);
        return;
      }
      setState(() => _text.text = text);
    } on AiException catch (e) {
      if (mounted) {
        _snack(
          e.statusCode == 400 || e.statusCode == 404
              ? l.modelCannotReadImage(e.message)
              : l.aiReadingFailed(e.message),
        );
      }
    } catch (e) {
      if (mounted) _snack(l.aiReadingFailed(describeError(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Splits the text into messages, detects each one, and opens the inbox.
  Future<void> _analyze() async {
    final l = context.l10n;
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
          userInitiated: true,
        );
        if (row != null) added.add(row.id);
      }
      String? aiNote;
      if (added.isNotEmpty) {
        try {
          // Only what was pasted here: other pending alerts are sent only
          // with consent to automatic reading.
          await service.assistPending(
            ids: added,
            userInitiated: true,
            unclearOnly: true,
          );
        } catch (e) {
          aiNote = l.aiUnavailableOnDevice;
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
          if (added.isEmpty) l.noNewPayments else l.paymentsReady(added.length),
          if (skipped > 0) l.skippedNotices(skipped),
          ?aiNote,
        ].join(' · '),
      );
      if (added.isNotEmpty) context.pushReplacement('/inbox');
    } catch (e) {
      if (mounted) _snack(l.couldNotAnalyse(describeError(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.initialDraft;
    final aiReady = ref.watch(aiAssistProvider).valueOrNull != null;
    ref.watch(aiClientProvider);
    final aiReadable = _aiReadable;
    final secondary = AppTextStyles.body.copyWith(
      color: AppColors.textSecondary(context),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.smartImport)),
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
                        ? context.l10n.reviewSharedScreenshot
                        : context.l10n.pasteAlertsTitle,
                    style: AppTextStyles.title,
                  ),
                  const SizedBox(height: Sp.sm),
                  Text(context.l10n.pasteAlertsBody, style: secondary),
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
                      title: Text(context.l10n.keepAsReceipt),
                      value: _attachReceipt,
                      onChanged: (v) => setState(() => _attachReceipt = v),
                    ),
                    if (aiReadable)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: _busy ? null : _readWithAi,
                          icon: const Icon(Icons.translate_rounded),
                          label: Text(context.l10n.readWithAiArabic),
                        ),
                      ),
                  ],
                  const SizedBox(height: Sp.lg),
                  TextField(
                    controller: _text,
                    minLines: 4,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: draft?.source == null
                          ? context.l10n.alertText
                          : context.l10n.alertTextFrom(draft!.source),
                      hintText: context.l10n.alertExample,
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
                          label: Text(context.l10n.paste),
                        ),
                      ),
                      const SizedBox(width: Sp.md),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _pickPhoto,
                          style: _compactButton,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(context.l10n.photo),
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
                          label: Text(context.l10n.analyze),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.md),
            // Lines up with the card's content above.
            Padding(
              padding: const EdgeInsetsDirectional.only(start: Sp.xl),
              child: Row(
                children: [
                  Icon(
                    aiReady
                        ? Icons.psychology_alt_outlined
                        : Icons.memory_rounded,
                    size: 18,
                    color: AppColors.textSecondary(context),
                  ),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: Text(
                      aiReady
                          ? context.l10n.aiSecondReading
                          : context.l10n.readOnPhone,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/settings/ai'),
                    child: Text(
                      aiReady ? context.l10n.aiSettings : context.l10n.setUp,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.md),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
              child: ListTile(
                leading: const Icon(Icons.history_rounded),
                title: Text(context.l10n.catchUpTitle),
                subtitle: Text(context.l10n.catchUpSubtitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/catch-up'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
