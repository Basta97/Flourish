import 'package:flourish/core/detection/detection_bridge.dart';
import 'package:flourish/core/models/shared_import_draft.dart';
import 'package:flourish/presentation/providers/finance_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flourish/detection');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void answer(Map<String, Object?> results) {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (!results.containsKey(call.method)) {
        throw MissingPluginException();
      }
      return results[call.method];
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('SharedImportDraft.fromMap', () {
    test('reads a share-sheet item', () {
      final draft = SharedImportDraft.fromMap({
        'source': 'android-share',
        'rawText': ' Paid EGP 120 ',
        'imagePath': '',
        'createdAt': '2026-10-17T09:30:00Z',
      });
      expect(draft.source, 'android-share');
      expect(draft.bestText, 'Paid EGP 120');
      expect(draft.imagePath, isNull);
      expect(draft.createdAt, DateTime.utc(2026, 10, 17, 9, 30));
      expect(draft.id, isNull);
    });

    test('reads a detection queue row', () {
      final draft = SharedImportDraft.fromMap({
        'id': 'a1',
        'text': 'Purchase EGP 250.00 at CARREFOUR card **1234',
        'sender': 'CIB',
        'packageName': 'com.google.android.apps.messaging',
        'receivedAt': '2026-10-17T10:00:00Z',
        'source': 'android_notification',
      });
      expect(draft.id, 'a1');
      expect(draft.rawText, startsWith('Purchase EGP 250.00'));
      expect(draft.sender, 'CIB');
      expect(draft.packageName, 'com.google.android.apps.messaging');
      expect(draft.createdAt, DateTime.utc(2026, 10, 17, 10));
      expect(draft.source, 'android_notification');
    });
  });

  group('pendingDetectedImportsProvider', () {
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          detectionBridgeProvider.overrideWithValue(
            MethodChannelDetectionBridge(),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('lists queued messages as drafts without acknowledging', () async {
      answer({
        'peek': [
          {
            'id': 'a1',
            'text': 'Purchase EGP 250.00 at CARREFOUR',
            'sender': 'CIB',
            'packageName': 'com.google.android.apps.messaging',
            'receivedAt': '2026-10-17T10:00:00Z',
            'source': 'android_notification',
          },
          'not a row',
          {
            'id': 'b2',
            'text': 'You paid USD 9.99 to NETFLIX',
            'sender': null,
            'packageName': 'com.example.wallet',
            'receivedAt': '2026-10-17T11:15:00Z',
            'source': 'android_notification',
          },
        ],
      });
      final drafts = await container().read(
        pendingDetectedImportsProvider.future,
      );
      expect([for (final d in drafts) d.id], ['a1', 'b2']);
      expect(drafts.first.rawText, 'Purchase EGP 250.00 at CARREFOUR');
      expect(drafts.first.sender, 'CIB');
      expect(drafts.last.sender, isNull);
      expect(drafts.last.packageName, 'com.example.wallet');
      expect(
        drafts.last.createdAt,
        DateTime.utc(2026, 10, 17, 11, 15).toLocal(),
      );
      expect([for (final c in calls) c.method], ['peek']);
    });

    test('is empty where the platform has no detection queue', () async {
      answer({});
      final drafts = await container().read(
        pendingDetectedImportsProvider.future,
      );
      expect(drafts, isEmpty);
    });
  });

  group('MethodChannelDetectionBridge.installedApps', () {
    test('returns label and package, skipping malformed rows', () async {
      answer({
        'installedApps': [
          {'packageName': 'com.cib.mobile', 'label': 'CIB Smart Wallet'},
          {'label': 'No package'},
          {'packageName': 'com.example.bank'},
        ],
      });
      final apps = await MethodChannelDetectionBridge().installedApps();
      expect([for (final a in apps) a.packageName], [
        'com.cib.mobile',
        'com.example.bank',
      ]);
      expect(apps.first.label, 'CIB Smart Wallet');
      expect(apps.last.label, 'com.example.bank');
    });

    test('is empty on iOS, where the method does not exist', () async {
      answer({});
      expect(await MethodChannelDetectionBridge().installedApps(), isEmpty);
    });
  });
}
