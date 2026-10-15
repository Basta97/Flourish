import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static SharedPreferences? _prefs;

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
    return prefs.setString(key, value);
  }

  static bool getBool(String key, {bool defaultValue = false}) {
    return prefs.getBool(key) ?? defaultValue;
  }

  static Future<bool> setBool(String key, bool value) {
    return prefs.setBool(key, value);
  }

  static double getDouble(String key, {double defaultValue = 0.0}) {
    return prefs.getDouble(key) ?? defaultValue;
  }

  static Future<bool> setDouble(String key, double value) {
    return prefs.setDouble(key, value);
  }

  static int getInt(String key, {int defaultValue = 0}) {
    return prefs.getInt(key) ?? defaultValue;
  }

  static Future<bool> setInt(String key, int value) {
    return prefs.setInt(key, value);
  }

  static Future<bool> remove(String key) {
    return prefs.remove(key);
  }
}
