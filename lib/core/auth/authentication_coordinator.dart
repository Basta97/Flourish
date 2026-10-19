import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// One native prompt at a time, shared by the lock screen and lock settings.
class AuthenticationCoordinator extends ChangeNotifier {
  AuthenticationCoordinator({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();
  static final instance = AuthenticationCoordinator();
  final LocalAuthentication _authentication;
  bool _active = false;
  bool get active => _active;
  Future<bool> isDeviceSupported() => _authentication.isDeviceSupported();
  Future<bool> authenticate(String reason) async {
    if (_active) return false;
    _active = true;
    notifyListeners();
    try {
      if (!await _authentication.isDeviceSupported()) return false;
      return await _authentication.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } finally {
      _active = false;
      notifyListeners();
    }
  }
}
