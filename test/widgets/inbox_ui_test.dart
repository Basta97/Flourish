import 'dart:async';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/detection/detection_bridge.dart';
import 'package:flourish/core/detection/parsed_payment.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/core/theme/app_theme.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/detection/detection_runtime.dart';
import 'package:flourish/presentation/detection/inbox_screen.dart';
import 'package:flourish/presentation/providers/database_provider.dart';
import 'package:flourish/presentation/providers/finance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBridge implements DetectionBridge {
  final queue = <QueuedMessage>[];
  final acked = <String>[];
  final _events = StreamController<void>.broadcast();
  @override
  Future<List<QueuedMessage>> peek() async => List.of(queue);
  @override
  Future<void> ack(List<String> ids) async {
    acked.addAll(ids);
    queue.removeWhere((m) => ids.contains(m.id));
  }

  @override
  Future<bool> isAccessGranted() async => true;
  @override
  Future<void> openAccessSettings() async {}
  @override
  Future<void> configure({
    required bool enabled,
    required List<String> packages,
    required bool notify,
  }) async {}
  @override
  Future<List<SourceCandidate>> candidates() async => const [];
  @override
  Future<String?> consumePendingRoute() async => null;
  @override
  Stream<void> get events => _events.stream;
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'default_currency': 'EGP'});
    await PreferencesService.init();
  });

  testWidgets('a queued bank SMS becomes a payment with one tap', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final bridge = FakeBridge()
      ..queue.add(
        QueuedMessage(
          'q1',
          RawMessage(
            text: 'تم خصم 250 جنيه من بطاقتك رقم 1234 لدى طلبات',
            sender: 'CIB',
            receivedAt: DateTime(2026, 10, 15, 12),
            source: 'android_notification',
          ),
        ),
      );
    late int card;
    await tester.runAsync(() async {
      final bank = (await db.getAllAccounts()).firstWhere(
        (a) => a.type == 'bank',
      );
      card = await db.savePaymentInstrument(
        PaymentInstrumentsCompanion.insert(
          accountId: bank.id,
          name: 'CIB',
          kind: 'debit_card',
          last4: const Value('1234'),
          issuer: const Value('cib'),
        ),
      );
    });

    Future<void> settle([int rounds = 8]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<T> drive<T>(Future<T> work) async {
      var done = false;
      late T result;
      work.then((v) {
        result = v;
        done = true;
      });
      for (var i = 0; i < 400 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
      }
      return result;
    }

    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          detectionBridgeProvider.overrideWithValue(bridge),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const DetectionRuntime(child: InboxScreen()),
        ),
      ),
    );
    await settle(12);

    expect(bridge.acked, ['q1']);
    expect(find.text('طلبات'), findsOneWidget);
    expect(find.textContaining('Food & Drinks'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(12);

    final rows = await drive(db.select(db.detectedPayments).get());
    expect(rows.single.status, 'confirmed');
    final tx = await drive(db.getTransactionById(rows.single.transactionId!));
    expect(tx!.paymentInstrumentId, card);
    expect(tx.amount, 250);
    expect(tx.merchant, 'طلبات');

    await tester.pumpWidget(const SizedBox());
    await drive(db.close());
  });
}
