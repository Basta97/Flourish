import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/ai/ai_client.dart';
import '../../core/ai/ai_config.dart';
import '../../core/ai/ai_transaction_extractor.dart';
import '../../core/detection/category_store.dart';
import '../../core/detection/detection_pipeline.dart';
import '../../core/services/preferences_service.dart';
import 'database_provider.dart';
import 'finance_providers.dart';

final aiSettingsProvider = StateProvider<AiSettings>((ref) => AiSettings.load());

final aiHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final aiApiKeyProvider = FutureProvider<String?>((ref) async {
  ref.watch(aiSettingsProvider);
  final key = await ref
      .watch(secureStorageProvider)
      .read(key: AiSettings.apiKeyStorageKey);
  return key == null || key.trim().isEmpty ? null : key.trim();
});

/// A client for the configured provider, or null when AI is not set up.
final aiClientProvider = FutureProvider<AiClient?>((ref) async {
  final settings = ref.watch(aiSettingsProvider);
  final key = await ref.watch(aiApiKeyProvider.future);
  if (!settings.configured || key == null) return null;
  return AiClient(
    httpClient: ref.watch(aiHttpClientProvider),
    baseUrl: settings.baseUrl,
    apiKey: key,
    model: settings.model,
    jsonMode: settings.preset.supportsJsonMode,
  );
});

final aiUsageTrackerProvider = Provider(
  (ref) => AiUsageTracker(ref.watch(financeStoreProvider)),
);

final aiExtractorProvider = FutureProvider<AiTransactionExtractor?>((ref) async {
  final settings = ref.watch(aiSettingsProvider);
  if (!settings.enabled) return null;
  final client = await ref.watch(aiClientProvider.future);
  if (client == null) return null;
  return AiTransactionExtractor(
    client,
    cache: FinanceStoreAiCache(ref.watch(financeStoreProvider)),
    usage: ref.watch(aiUsageTrackerProvider),
    redact: settings.effectiveRedact,
    allowNewCategories: settings.allowNewCategories,
  );
});

const _lastImportAccountKey = 'last_import_account_id';

int? lastImportAccount() {
  try {
    final id = PreferencesService.getInt(_lastImportAccountKey, defaultValue: -1);
    return id < 0 ? null : id;
  } on StateError {
    return null;
  }
}

Future<void> rememberImportAccount(int id) async {
  try {
    await PreferencesService.setInt(_lastImportAccountKey, id);
  } on StateError {
    // Preferences not initialised (tests).
  }
}

final detectionPipelineProvider = FutureProvider<DetectionPipeline>((ref) async {
  return DetectionPipeline(
    db: ref.watch(databaseProvider),
    store: ref.watch(financeStoreProvider),
    settings: ref.watch(aiSettingsProvider),
    extractor: await ref.watch(aiExtractorProvider.future),
    lastUsedAccount: lastImportAccount(),
  );
});

final categoryLearningProvider = Provider(
  (ref) => CategoryLearningStore(
    ref.watch(databaseProvider),
    ref.watch(financeStoreProvider),
  ),
);
