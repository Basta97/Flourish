import 'package:flutter/services.dart';
import 'parsed_payment.dart';

/// A message captured natively (Android notification listener, iOS
/// Shortcuts or share extension) and waiting in the device queue.
class QueuedMessage {
  final String id;
  final RawMessage message;
  const QueuedMessage(this.id, this.message);

  factory QueuedMessage.fromMap(Map<Object?, Object?> m) => QueuedMessage(
    '${m['id']}',
    RawMessage(
      text: '${m['text'] ?? ''}',
      sender: m['sender'] as String?,
      packageName: m['packageName'] as String?,
      receivedAt:
          DateTime.tryParse('${m['receivedAt']}')?.toLocal() ?? DateTime.now(),
      source: '${m['source'] ?? 'android_notification'}',
    ),
  );
}

/// Apps that posted bank-like notifications, offered when choosing sources.
class SourceCandidate {
  final String packageName, label;
  final int count;
  const SourceCandidate(this.packageName, this.label, this.count);
}

/// The native side of payment detection.
abstract class DetectionBridge {
  /// Messages captured since the last [ack], oldest first. Delivery is
  /// at-least-once; the detection service ignores repeats.
  Future<List<QueuedMessage>> peek();
  Future<void> ack(List<String> ids);

  /// Android: whether Flourish may read notifications.
  Future<bool> isAccessGranted();
  Future<void> openAccessSettings();
  Future<void> configure({
    required bool enabled,
    required List<String> packages,
    required bool notify,
  });
  Future<List<SourceCandidate>> candidates();

  /// Route requested by tapping a detection notification, if any.
  Future<String?> consumePendingRoute();

  /// Fires when new messages are queued while the app runs.
  Stream<void> get events;
}

class MethodChannelDetectionBridge implements DetectionBridge {
  static const _channel = MethodChannel('flourish/detection');
  static const _events = EventChannel('flourish/detection/events');

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<List<QueuedMessage>> peek() async {
    final rows = await _call<List<Object?>>('peek') ?? const [];
    return [
      for (final r in rows)
        if (r is Map) QueuedMessage.fromMap(r),
    ];
  }

  @override
  Future<void> ack(List<String> ids) => _call('ack', ids);

  @override
  Future<bool> isAccessGranted() async =>
      await _call<bool>('isAccessGranted') ?? false;

  @override
  Future<void> openAccessSettings() => _call('openAccessSettings');

  @override
  Future<void> configure({
    required bool enabled,
    required List<String> packages,
    required bool notify,
  }) => _call('configure', {
    'enabled': enabled,
    'packages': packages,
    'notify': notify,
  });

  @override
  Future<List<SourceCandidate>> candidates() async {
    final rows = await _call<List<Object?>>('candidates') ?? const [];
    return [
      for (final r in rows)
        if (r is Map)
          SourceCandidate(
            '${r['packageName']}',
            '${r['label'] ?? r['packageName']}',
            (r['count'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  @override
  Future<String?> consumePendingRoute() => _call<String>('consumePendingRoute');

  @override
  Stream<void> get events =>
      _events.receiveBroadcastStream().map((_) {}).handleError((Object _) {});
}
