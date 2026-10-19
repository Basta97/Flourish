import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flourish/core/detection/detection_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'iPhone does not subscribe to the Android-only notification event channel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(await MethodChannelDetectionBridge().events.isEmpty, true);
    },
  );
}
