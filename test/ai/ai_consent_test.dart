import 'package:drift/native.dart';
import 'package:flourish/core/ai/ai_config.dart';
import 'package:flourish/core/ai/ai_payment_assist.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/data/finance/finance_store.dart';
import 'package:flourish/domain/finance/models.dart';
import 'package:flourish/presentation/providers/ai_providers.dart';
import 'package:flourish/presentation/settings/ai_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Usage extends AiUsageTracker {
  _Usage()
    : super(FinanceStore(AppDatabase.forTesting(NativeDatabase.memory())));
  @override
  Future<Json> thisMonth() async => const {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('AiSettings.automatic', () {
    test('is off by default and needs consent for the current host', () {
      const off = AiSettings();
      expect(off.automatic, isFalse);
      final on = off.copyWith(enabled: true);
      expect(on.automatic, isFalse, reason: 'enabling AI is not consent');
      final agreed = on.copyWith(autoConsentHost: on.host);
      expect(agreed.automatic, isTrue);
      expect(agreed.copyWith(enabled: false).automatic, isFalse);
    });

    test('consent lapses when the base URL points elsewhere', () {
      final agreed = const AiSettings(
        enabled: true,
      ).copyWith(autoConsentHost: 'api.deepseek.com');
      expect(agreed.automatic, isTrue);
      final moved = agreed.copyWith(baseUrl: 'https://api.groq.com/openai/v1');
      expect(moved.automatic, isFalse);
    });

    test('settings saved by older versions do not grant consent', () async {
      SharedPreferences.setMockInitialValues({
        'ai_enabled': true,
        'ai_preset': 'deepseek',
        'ai_base_url': 'https://api.deepseek.com',
        'ai_model': 'deepseek-chat',
      });
      await PreferencesService.init();
      final loaded = AiSettings.load();
      expect(loaded.enabled, isTrue);
      expect(loaded.automatic, isFalse);

      await loaded.copyWith(autoConsentHost: loaded.host).save();
      expect(AiSettings.load().automatic, isTrue);
      await AiSettings.load().copyWith(autoConsentHost: '').save();
      expect(AiSettings.load().automatic, isFalse);
    });
  });

  group('AI settings screen', () {
    Future<ProviderContainer> pump(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'ai_enabled': true,
        'ai_preset': 'gemini',
        'ai_base_url':
            'https://generativelanguage.googleapis.com/v1beta/openai',
        'ai_model': 'gemini-flash-latest',
      });
      await PreferencesService.init();
      final container = ProviderContainer(
        overrides: [aiUsageTrackerProvider.overrideWithValue(_Usage())],
      );
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(2400, 3600);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AiSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    Finder automaticSwitch() => find.descendant(
      of: find.byKey(const ValueKey('ai-automatic')),
      matching: find.byType(Switch),
    );

    testWidgets('declining the disclosure keeps automatic reading off', (
      tester,
    ) async {
      final container = await pump(tester);
      await tester.tap(automaticSwitch());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('generativelanguage.googleapis.com'),
        findsWidgets,
      );
      expect(find.textContaining('Free tiers may keep'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(container.read(aiSettingsProvider).automatic, isFalse);
      expect(PreferencesService.getString('ai_auto_consent_host'), '');
    });

    testWidgets('agreeing records consent and switching off revokes it', (
      tester,
    ) async {
      final container = await pump(tester);
      await tester.tap(automaticSwitch());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree and turn on'));
      await tester.pumpAndSettle();
      expect(container.read(aiSettingsProvider).automatic, isTrue);
      expect(
        PreferencesService.getString('ai_auto_consent_host'),
        'generativelanguage.googleapis.com',
      );

      await tester.tap(automaticSwitch());
      await tester.pumpAndSettle();
      expect(find.text('Agree and turn on'), findsNothing);
      expect(container.read(aiSettingsProvider).automatic, isFalse);
      expect(PreferencesService.getString('ai_auto_consent_host'), '');
    });
  });
}
