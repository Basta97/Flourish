import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flourish/core/auth/authentication_coordinator.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/presentation/wealth/finance_runtime.dart';

class _Authentication extends LocalAuthentication {
  int calls = 0;
  Completer<bool> result = Completer<bool>();
  bool? biometricOnlyValue;
  @override
  Future<bool> isDeviceSupported() async => true;
  @override
  Future<bool> authenticate({
    required String localizedReason,
    dynamic authMessages,
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) {
    calls++;
    biometricOnlyValue = biometricOnly;
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'app_lock_enabled': true});
    await PreferencesService.init();
  });
  test(
    'coordinator prevents overlapping requests and permits passcode fallback',
    () async {
      final native = _Authentication();
      final coordinator = AuthenticationCoordinator(authentication: native);
      final first = coordinator.authenticate('Unlock');
      await Future<void>.delayed(Duration.zero);
      expect(await coordinator.authenticate('Change settings'), false);
      expect(native.calls, 1);
      expect(native.biometricOnlyValue, false);
      native.result.complete(true);
      expect(await first, true);
      expect(coordinator.active, false);
    },
  );
  testWidgets(
    'prompt lifecycle does not relock or repeat, cancel requires explicit retry',
    (tester) async {
      final native = _Authentication();
      final coordinator = AuthenticationCoordinator(authentication: native);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: FinanceAppLock(
            authentication: coordinator,
            child: const Scaffold(body: Text('Private draft')),
          ),
        ),
      );
      await tester.pump();
      expect(native.calls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(native.calls, 1);
      native.result.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Private draft'), findsOneWidget); // Mounted underneath.
      expect(find.text('Unlock'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(native.calls, 1);
      native.result = Completer<bool>();
      await tester.tap(find.text('Unlock'));
      await tester.pump();
      expect(native.calls, 2);
      native.result.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Unlock'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      native.result = Completer<bool>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(native.calls, 3);
      native.result.complete(true);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
