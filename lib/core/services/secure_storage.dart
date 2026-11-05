import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keychain items are readable only after the first unlock since boot and
/// never leave this device (no iCloud Keychain, no backup restore onto
/// another phone).
const _iosOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
);

/// The app's one secure store. Use this rather than a bare
/// `FlutterSecureStorage()`, which would read and write with the default,
/// less strict accessibility.
const appSecureStorage = FlutterSecureStorage(iOptions: _iosOptions);

/// Moves items saved before the stricter accessibility to it. Keychain
/// lookups match on accessibility, so without this the AI key and lock
/// setting saved by older versions would no longer be found.
Future<void> migrateSecureStorage() async {
  if (!Platform.isIOS) return;
  const legacy = FlutterSecureStorage();
  final Map<String, String> old;
  try {
    old = await legacy.readAll();
  } catch (_) {
    return;
  }
  for (final MapEntry(:key, :value) in old.entries) {
    // Delete first: account + service identify an item regardless of
    // accessibility, so writing first would collide with the old one.
    await legacy.delete(key: key);
    await appSecureStorage.write(key: key, value: value);
  }
}
