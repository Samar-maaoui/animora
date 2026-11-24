import 'package:shared_preferences/shared_preferences.dart';

class PreferencesAuthBackend {
  final SharedPreferencesAsync preferences = SharedPreferencesAsync();
  Future<String?> read(String key) => preferences.getString(key);
  Future<void> write(String key, String value, {String? expectedValue}) =>
      preferences.setString(key, value);
}
