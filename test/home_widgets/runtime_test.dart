import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/home_widgets/home_widget_runtime.dart';
import 'package:flourish/presentation/providers/database_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native snapshots remove previously public totals on privacy changes',
    (tester) async {
      SharedPreferences.setMockInitialValues({'default_currency': 'EGP'});
      await PreferencesService.init();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final published = <Map<String, dynamic>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(homeWidgetChannel, (call) async {
            if (call.method == 'publish') {
              published.add(
                jsonDecode(call.arguments as String) as Map<String, dynamic>,
              );
            }
            return null;
          });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const HomeWidgetRuntime(child: SizedBox()),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
      }

      await settle();
      expect(published.last['hidden'], false);
      expect(published.last.containsKey('income'), true);
      await PreferencesService.setBool('app_lock_enabled', true);
      await settle();
      expect(published.last['hidden'], true);
      expect(published.last.containsKey('income'), false);
      expect(published.last.containsKey('spending'), false);
      await PreferencesService.setBool('hide_amounts', true);
      await PreferencesService.setBool('app_lock_enabled', false);
      await settle();
      expect(published.last['hidden'], true);
      expect(published.last.containsKey('income'), false);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(homeWidgetChannel, null);
    },
  );
}
