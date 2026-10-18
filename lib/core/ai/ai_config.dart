import '../services/preferences_service.dart';

/// A starting point for an OpenAI-compatible endpoint. The user can edit the
/// URL and model afterwards, so a provider renaming a model never breaks the
/// app.
class AiProviderPreset {
  const AiProviderPreset({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.model,
    required this.keyHint,
    this.free = false,
    this.supportsJsonMode = true,
    this.readsImages,
  });

  final String id;
  final String label;
  final String baseUrl;
  final String model;
  final String keyHint;

  /// Free tiers may train on prompts, so redaction is forced on.
  final bool free;
  final bool supportsJsonMode;

  /// Whether the preset's default model accepts images; null when it
  /// depends on the model the person picks.
  final bool? readsImages;

  static const all = <AiProviderPreset>[
    AiProviderPreset(
      id: 'deepseek',
      label: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-chat',
      keyHint: 'platform.deepseek.com → API keys',
      readsImages: false,
    ),
    AiProviderPreset(
      id: 'openrouter',
      label: 'OpenRouter (free models)',
      baseUrl: 'https://openrouter.ai/api/v1',
      // The free lineup changes monthly, so the user picks a current one.
      model: '',
      keyHint:
          'openrouter.ai/keys — pick any model ending in :free at openrouter.ai/models',
      free: true,
      supportsJsonMode: false,
    ),
    AiProviderPreset(
      id: 'groq',
      label: 'Groq',
      baseUrl: 'https://api.groq.com/openai/v1',
      model: 'llama-3.3-70b-versatile',
      keyHint: 'console.groq.com/keys (free tier)',
      free: true,
      readsImages: false,
    ),
    AiProviderPreset(
      id: 'gemini',
      label: 'Google Gemini',
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
      // An alias Google keeps pointed at the current Flash model.
      model: 'gemini-flash-latest',
      keyHint: 'aistudio.google.com/apikey (free tier)',
      free: true,
      readsImages: true,
    ),
    AiProviderPreset(
      id: 'custom',
      label: 'Custom (OpenAI-compatible)',
      baseUrl: '',
      model: '',
      keyHint: 'Any server that implements /chat/completions',
    ),
  ];

  static AiProviderPreset byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);
}

/// Non-secret AI preferences. The API key itself lives in secure storage
/// under [AiSettings.apiKeyStorageKey].
class AiSettings {
  const AiSettings({
    this.enabled = false,
    this.presetId = 'deepseek',
    this.baseUrl = 'https://api.deepseek.com',
    this.model = 'deepseek-chat',
    this.threshold = 0.75,
    this.allowNewCategories = true,
    this.redact = true,
    this.screenshotOcr = false,
  });

  static const apiKeyStorageKey = 'ai_api_key';

  final bool enabled;
  final String presetId;
  final String baseUrl;
  final String model;

  /// Local results below this confidence are sent to the AI.
  final double threshold;
  final bool allowNewCategories;
  final bool redact;

  /// Android only: screenshots the on-device reader cannot read (Arabic)
  /// may be sent, as images, to the AI. Off until the person agrees.
  final bool screenshotOcr;

  AiProviderPreset get preset => AiProviderPreset.byId(presetId);

  /// Free providers always get redacted text, whatever the toggle says.
  bool get effectiveRedact => redact || preset.free;

  bool get configured => baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  AiSettings copyWith({
    bool? enabled,
    String? presetId,
    String? baseUrl,
    String? model,
    double? threshold,
    bool? allowNewCategories,
    bool? redact,
    bool? screenshotOcr,
  }) => AiSettings(
    enabled: enabled ?? this.enabled,
    presetId: presetId ?? this.presetId,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    threshold: threshold ?? this.threshold,
    allowNewCategories: allowNewCategories ?? this.allowNewCategories,
    redact: redact ?? this.redact,
    screenshotOcr: screenshotOcr ?? this.screenshotOcr,
  );

  static AiSettings load() {
    const d = AiSettings();
    try {
      var model = PreferencesService.getString('ai_model', defaultValue: d.model);
      // The first Gemini default was a dated model id; follow the alias.
      if (model == 'gemini-2.5-flash' || model == 'gemini-2.0-flash') {
        model = 'gemini-flash-latest';
      }
      return AiSettings(
        enabled: PreferencesService.getBool('ai_enabled'),
        presetId: PreferencesService.getString(
          'ai_preset',
          defaultValue: d.presetId,
        ),
        baseUrl: PreferencesService.getString(
          'ai_base_url',
          defaultValue: d.baseUrl,
        ),
        model: model,
        threshold: PreferencesService.getDouble(
          'ai_threshold',
          defaultValue: d.threshold,
        ),
        allowNewCategories: PreferencesService.getBool(
          'ai_new_categories',
          defaultValue: d.allowNewCategories,
        ),
        redact: PreferencesService.getBool('ai_redact', defaultValue: true),
        screenshotOcr: PreferencesService.getBool('ai_screenshot_ocr'),
      );
    } on StateError {
      return d; // Preferences not initialised (tests).
    }
  }

  Future<void> save() async {
    await PreferencesService.setBool('ai_enabled', enabled);
    await PreferencesService.setString('ai_preset', presetId);
    await PreferencesService.setString('ai_base_url', baseUrl.trim());
    await PreferencesService.setString('ai_model', model.trim());
    await PreferencesService.setDouble('ai_threshold', threshold);
    await PreferencesService.setBool('ai_new_categories', allowNewCategories);
    await PreferencesService.setBool('ai_redact', redact);
    await PreferencesService.setBool('ai_screenshot_ocr', screenshotOcr);
  }
}
