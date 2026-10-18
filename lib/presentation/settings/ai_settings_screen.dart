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
    ref
        .read(secureStorageProvider)
        .read(key: AiSettings.apiKeyStorageKey)
        .then((k) {
          if (mounted) setState(() => _hasKey = (k ?? '').isNotEmpty);
        });
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
      SnackBar(content: Text(key.isEmpty ? 'API key removed' : 'API key saved')),
    );
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final client = await ref.read(aiClientProvider.future);
      if (client == null) {
        throw const AiException('Add a base URL, model and API key first');
      }
      final reply = await client.completeJson(
        system: 'Reply with the JSON object {"ok": true} and nothing else.',
        user: 'ping',
      );
      _testOk = reply.json['ok'] == true;
      _testResult = _testOk
          ? 'Connected to ${client.model}'
          : 'Connected, but the model did not follow the JSON instruction. Try another model.';
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
      appBar: AppBar(title: const Text('AI Assistant')),
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
              padding: const EdgeInsets.all(Sp.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use AI when unsure'),
                    subtitle: const Text(
                      'Flourish reads alerts on your phone first. Only messages it cannot read confidently are sent to the AI.',
                    ),
                    value: s.enabled,
                    onChanged: (v) => _update(s.copyWith(enabled: v)),
                  ),
                  const SizedBox(height: Sp.sm),
                  DropdownButtonFormField<String>(
                    initialValue: s.presetId,
                    decoration: const InputDecoration(labelText: 'Provider'),
                    items: [
                      for (final p in AiProviderPreset.all)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(p.free ? '${p.label} · free tier' : p.label),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      final p = AiProviderPreset.byId(id);
                      _baseUrl.text = p.baseUrl;
                      _model.text = p.model;
                      _update(
                        s.copyWith(presetId: id, baseUrl: p.baseUrl, model: p.model),
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
                    decoration: const InputDecoration(labelText: 'Base URL'),
                    onChanged: (v) => _update(s.copyWith(baseUrl: v)),
                  ),
                  const SizedBox(height: Sp.md),
                  TextField(
                    controller: _model,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Model'),
                    onChanged: (v) => _update(s.copyWith(model: v)),
                  ),
                  const SizedBox(height: Sp.md),
                  TextField(
                    controller: _key,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'API key',
                      hintText: _hasKey ? '•••••••• (saved)' : 'Paste your key',
                      suffixIcon: IconButton(
                        tooltip: 'Save key',
                        icon: const Icon(Icons.check_rounded),
                        onPressed: _saveKey,
                      ),
                    ),
                    onSubmitted: (_) => _saveKey(),
                  ),
                  const SizedBox(height: Sp.xs),
                  Text(
                    'Stored in the device keychain. Leave empty and save to remove it.',
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
                    label: const Text('Test connection'),
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
            const SizedBox(height: Sp.lg),
            AppCard(
              padding: const EdgeInsets.all(Sp.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask the AI below ${(s.threshold * 100).round()}% confidence',
                    style: AppTextStyles.subtitle,
                  ),
                  Slider(
                    value: s.threshold,
                    min: 0.5,
                    max: 0.95,
                    divisions: 9,
                    label: '${(s.threshold * 100).round()}% confidence',
                    onChanged: (v) => _update(s.copyWith(threshold: v)),
                  ),
                  Text(
                    'Higher sends more messages to the AI (better accuracy, more requests).',
                    style: secondary,
                  ),
                  const SizedBox(height: Sp.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Let AI suggest new categories'),
                    subtitle: const Text(
                      'New categories are shown with ✨ and only created when you save.',
                    ),
                    value: s.allowNewCategories,
                    onChanged: (v) => _update(s.copyWith(allowNewCategories: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hide personal data'),
                    subtitle: Text(
                      s.preset.free
                          ? 'Always on for free providers, which may keep prompts.'
                          : 'Masks account and card numbers, phones and emails before sending.',
                    ),
                    value: s.effectiveRedact,
                    onChanged: s.preset.free
                        ? null
                        : (v) => _update(s.copyWith(redact: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.lg),
            AppCard(
              padding: const EdgeInsets.all(Sp.lg),
              child: Row(
                children: [
                  const Icon(Icons.insights_outlined),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Text(
                      'This month: ${usage['requests'] ?? 0} requests · '
                      '${(usage['promptTokens'] as int? ?? 0) + (usage['completionTokens'] as int? ?? 0)} tokens',
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
