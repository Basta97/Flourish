import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/shared_import_draft.dart';
import '../../core/router/app_router.dart';
import '../../core/services/preferences_service.dart';
import '../../core/services/shared_import_service.dart';
import '../providers/finance_providers.dart';
import '../wealth/finance_runtime.dart' show remindersProvider;

/// Moves captured messages from the device queue into the detection inbox
/// (on launch, on resume and whenever the native side signals new ones),
/// opens shared text or images for review, and follows notification taps.
class DetectionRuntime extends ConsumerStatefulWidget {
  final Widget child;
  const DetectionRuntime({super.key, required this.child});
  @override
  ConsumerState<DetectionRuntime> createState() => _DetectionRuntimeState();
}

class _DetectionRuntimeState extends ConsumerState<DetectionRuntime>
    with WidgetsBindingObserver {
  bool draining = false;
  StreamSubscription<void>? events;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    events = ref.read(detectionBridgeProvider).events.listen((_) => _drain());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifications = ref.read(remindersProvider)
        ..onRoute = (route) => appRouter.push(route);
      try {
        await notifications.init();
      } catch (e) {
        debugPrint('Notifications unavailable: $e');
      }
      await _wake();
    });
  }

  @override
  void dispose() {
    events?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _wake();
  }

  Future<void> _wake() async {
    await _drain();
    await _sharedImport();
    final route = await ref.read(detectionBridgeProvider).consumePendingRoute();
    if (mounted && route != null && route.startsWith('/')) {
      appRouter.push(route);
    }
  }

  Future<void> _drain() async {
    if (draining || !mounted) return;
    draining = true;
    try {
      final bridge = ref.read(detectionBridgeProvider);
      final service = ref.read(detectionServiceProvider);
      final auto = PreferencesService.getBool('detection_auto_confirm');
      for (var round = 0; round < 10; round++) {
        final batch = await bridge.peek();
        if (batch.isEmpty) break;
        for (final item in batch) {
          try {
            await service.ingest(item.message, autoConfirm: auto);
          } catch (e) {
            debugPrint('Detection ingest failed: $e');
          }
        }
        await bridge.ack([for (final item in batch) item.id]);
      }
      try {
        // Unclear messages get a second reading when AI is set up.
        await service.assistPending();
      } catch (e) {
        debugPrint('AI detection unavailable: $e');
      }
      final days = PreferencesService.getInt(
        'detection_raw_text_days',
        defaultValue: 30,
      );
      if (days == 0) {
        await service.purgeText(days: 0);
      } else {
        await service.purgeText(days: days);
      }
    } catch (e) {
      debugPrint('Detection queue unavailable: $e');
    } finally {
      draining = false;
    }
  }

  Future<void> _sharedImport() async {
    try {
      final SharedImportDraft? draft =
          await SharedImportService.consumePendingImport();
      if (mounted &&
          draft != null &&
          (draft.bestText.isNotEmpty || draft.imagePath != null)) {
        appRouter.push('/smart-import', extra: draft);
      }
    } catch (e) {
      debugPrint('Shared import unavailable: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
