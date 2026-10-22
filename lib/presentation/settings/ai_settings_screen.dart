import 'package:flourish/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_client.dart';
import '../../core/ai/ai_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/liquid_page.dart';
import '../providers/ai_providers.dart';
import '../providers/finance_providers.dart';
import 'screenshot_ai_disclosure.dart';

/// Provider, key and behaviour of the optional AI stage of Smart Import.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  late final _baseUrl = TextEditingController(
    text: ref.read(aiSettingsProvider).baseUrl,
  );
  late final _model = TextEditingController(
    text: ref.read(aiSettingsProvider).model,
  );
  final _key = TextEditingController();
  bool _hasKey = false;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    ref.read(secureStorageProvider).read(key: AiSettings.apiKeyStorageKey).then(
      (k) {
        if (mounted) setState(() => _hasKey = (k ?? '').isNotEmpty);
      },
    );
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _update(AiSettings next) async {
    ref.read(aiSettingsProvider.notifier).state = next;
    await next.save();
  }

  Future<void> _saveKey() async {
    final storage = ref.read(secureStorageProvider);
    final key = _key.text.trim();
    if (key.isEmpty) {
      await storage.delete(key: AiSettings.apiKeyStorageKey);
    } else {
      await storage.write(key: AiSettings.apiKeyStorageKey, value: key);
    }
    _key.clear();
    ref.invalidate(aiApiKeyProvider);
    if (!mounted) return;
    setState(() => _hasKey = key.isNotEmpty);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          key.isEmpty ? context.l10n.apiKeyRemoved : context.l10n.apiKeySaved,
        ),
      ),
    );
  }

  /// Lists the models the saved key can use, so a renamed or retired model
  /// is one tap to fix.
  Future<void> _chooseModel() async {
    final l = context.l10n;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    List<String> models = const [];
    try {
      final client = await ref.read(aiClientProvider.future);
      if (client == null) {
        throw AiException(l.saveApiKeyFirst);
      }
      models = await client.listModels();
      if (models.isEmpty) throw AiException(l.noModelsForKey);
    } on Exception catch (e) {
      _testOk = false;
      _testResult = '$e';
    } finally {
      if (mounted) setState(() => _testing = false);
    }
    if (models.isEmpty || !mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final m in models)
              ListTile(
                title: Text(m),
                trailing: m == _model.text.trim()
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _model.text = picked;
    await _update(ref.read(aiSettingsProvider).copyWith(model: picked));
    await _test();
  }

  Future<void> _test() async {
    final l = context.l10n;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final client = await ref.read(aiClientProvider.future);
      if (client == null) {
        throw AiException(l.addAiConfigFirst);
      }
      final reply = await client.completeJson(
        system: 'Reply with the JSON object {"ok": true} and nothing else.',
        user: 'ping',
      );
      _testOk = reply.json['ok'] == true;
      _testResult = _testOk ? l.connectedTo(client.model) : l.connectedNoJson;
    } on Exception catch (e) {
      _testOk = false;
      _testResult = '$e';
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(aiSettingsProvider);
    final usage = ref.watch(_usageProvider).valueOrNull ?? const {};
    final secondary = AppTextStyles.body.copyWith(
      color: AppColors.textSecondary(context),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.aiAssistant)),
      body: LiquidPageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Sp.screenH,
            Sp.lg,
            Sp.screenH,
            Sp.xxxl,
          ),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: Sp.lg,
                bottom: Sp.sm,
              ),
              child: Text(
                context.l10n.aiConnection.toUpperCase(),
                style: AppTextStyles.eyebrow.copyWith(
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
            AppCard(
              padding: const EdgeInsets.all(Sp.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.useAiWhenUnsure),
                    subtitle: Text(context.l10n.useAiWhenUnsureSubtitle),
                    value: s.enabled,
                    onChanged: (v) => _update(s.copyWith(enabled: v)),
                  ),
                  SwitchListTile(
                    key: const ValueKey('ai-automatic'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.aiAutomatic),
                    subtitle: Text(
                      s.automatic
                          ? context.l10n.aiAutomaticOn(s.host)
                          : context.l10n.aiAutomaticOff,
                    ),
                    value: s.automatic,
                    onChanged: !s.enabled || s.host.isEmpty
                        ? null
                        : (v) async {
                            if (v && !await confirmAutomaticAi(context, s)) {
                              return;
                            }
                            await _update(
                              s.copyWith(autoConsentHost: v ? s.host : ''),
                            );
                          },
                  ),
                  const SizedBox(height: Sp.sm),
                  DropdownButtonFormField<String>(
                    initialValue: s.presetId,
                    decoration: InputDecoration(
                      labelText: context.l10n.provider,
                    ),
                    items: [
                      for (final p in AiProviderPreset.all)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            p.free ? context.l10n.freeTier(p.label) : p.label,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      final p = AiProviderPreset.byId(id);
                      _baseUrl.text = p.baseUrl;
                      _model.text = p.model;
                      _update(
                        s.copyWith(
                          presetId: id,
                          baseUrl: p.baseUrl,
                          model: p.model,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: Sp.sm),
                  Text(s.preset.keyHint, style: AppTextStyles.caption),
                  const SizedBox(height: Sp.md),
                  TextField(
                    controller: _baseUrl,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: context.l10n.baseUrl,
                    ),
                    onChanged: (v) => _update(s.copyWith(baseUrl: v)),
                  ),
                  const SizedBox(height: Sp.md),
                  TextField(
                    controller: _model,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: context.l10n.model,
                      suffixIcon: IconButton(
                        tooltip: context.l10n.chooseModel,
                        icon: const Icon(Icons.list_alt_rounded),
                        onPressed: _testing ? null : _chooseModel,
                      ),
                    ),
                    onChanged: (v) => _update(s.copyWith(model: v)),
                  ),
                  const SizedBox(height: Sp.md),
                  TextField(
                    controller: _key,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.l10n.apiKey,
                      hintText: _hasKey
                          ? context.l10n.apiKeySavedHint
                          : context.l10n.pasteYourKey,
                      suffixIcon: IconButton(
                        tooltip: context.l10n.saveKey,
                        icon: const Icon(Icons.check_rounded),
                        onPressed: _saveKey,
                      ),
                    ),
                    onSubmitted: (_) => _saveKey(),
                  ),
                  const SizedBox(height: Sp.xs),
                  Text(
                    context.l10n.keyStorageNote,
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: Sp.xs),
                  Text(
                    context.l10n.aiProviderPolicy,
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: Sp.lg),
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _test,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering_rounded),
                    label: Text(context.l10n.testConnection),
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: Sp.sm),
                    Text(
                      _testResult!,
                      style: AppTextStyles.caption.copyWith(
                        color: _testOk ? AppColors.income : AppColors.expense,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Sp.xxl),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: Sp.lg,
                bottom: Sp.sm,
              ),
              child: Text(
                context.l10n.aiBehaviour.toUpperCase(),
                style: AppTextStyles.eyebrow.copyWith(
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
            AppCard(
              padding: const EdgeInsets.all(Sp.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.askBelowConfidence(
                      (s.threshold * 100).round(),
                    ),
                    style: AppTextStyles.subtitle,
                  ),
                  Slider(
                    value: s.threshold,
                    min: 0.5,
                    max: 0.95,
                    divisions: 9,
                    padding: const EdgeInsets.symmetric(vertical: Sp.md),
                    label: context.l10n.percentConfidence(
                      (s.threshold * 100).round(),
                    ),
                    onChanged: (v) => _update(s.copyWith(threshold: v)),
                  ),
                  Text(context.l10n.higherSendsMore, style: secondary),
                  const SizedBox(height: Sp.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.aiSuggestCategories),
                    subtitle: Text(context.l10n.aiSuggestCategoriesSubtitle),
                    value: s.allowNewCategories,
                    onChanged: (v) =>
                        _update(s.copyWith(allowNewCategories: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.hidePersonalData),
                    subtitle: Text(
                      s.preset.free
                          ? context.l10n.hidePersonalDataFree
                          : context.l10n.hidePersonalDataSubtitle,
                    ),
                    value: s.effectiveRedact,
                    onChanged: s.preset.free
                        ? null
                        : (v) => _update(s.copyWith(redact: v)),
                  ),
                  if (defaultTargetPlatform == TargetPlatform.android)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.readArabicScreenshots),
                      subtitle: Text(
                        s.preset.readsImages == false
                            ? context.l10n.providerNoImages(s.preset.label)
                            : context.l10n.sendsImageUnmasked,
                      ),
                      value: s.screenshotOcr,
                      onChanged: (v) async {
                        if (v && !await confirmScreenshotAi(context, s)) return;
                        await _update(s.copyWith(screenshotOcr: v));
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: Sp.xxl),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: Sp.lg,
                bottom: Sp.sm,
              ),
              child: Text(
                context.l10n.aiUsage.toUpperCase(),
                style: AppTextStyles.eyebrow.copyWith(
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
            AppCard(
              padding: const EdgeInsets.all(Sp.lg),
              child: Row(
                children: [
                  const Icon(Icons.insights_outlined),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Text(
                      context.l10n.aiUsageThisMonth(
                        '${usage['requests'] ?? 0}',
                        '${(usage['promptTokens'] as int? ?? 0) + (usage['completionTokens'] as int? ?? 0)}',
                      ),
                      style: secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _usageProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(aiUsageTrackerProvider).thisMonth(),
);
