import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static SharedPreferences? _prefs;
  static final changes = StreamController<String>.broadcast(sync: true);

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError(
        'PreferencesService not initialized. Call init() first.',
      );
    }
    return _prefs!;
  }

  static String getString(String key, {String defaultValue = ''}) {
    return prefs.getString(key) ?? defaultValue;
  }

  static Future<bool> setString(String key, String value) {
    final result = prefs.setString(key, value);
    changes.add(key);
    return result;
  }

  static bool getBool(String key, {bool defaultValue = false}) {
    return prefs.getBool(key) ?? defaultValue;
  }

  static Future<bool> setBool(String key, bool value) {
    final result = prefs.setBool(key, value);
    changes.add(key);
    return result;
  }

  static double getDouble(String key, {double defaultValue = 0.0}) {
    return prefs.getDouble(key) ?? defaultValue;
  }

  static Future<bool> setDouble(String key, double value) {
    final result = prefs.setDouble(key, value);
    changes.add(key);
    return result;
  }

  static int getInt(String key, {int defaultValue = 0}) {
    return prefs.getInt(key) ?? defaultValue;
  }

  static Future<bool> setInt(String key, int value) {
    final result = prefs.setInt(key, value);
    changes.add(key);
    return result;
  }

  static Future<bool> remove(String key) {
    final result = prefs.remove(key);
    changes.add(key);
    return result;
  }
}
