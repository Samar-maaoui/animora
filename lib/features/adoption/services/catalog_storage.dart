import 'package:shared_preferences/shared_preferences.dart';

abstract interface class CatalogStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class PreferencesCatalogStorage implements CatalogStorage {
  static const key = 'animora.adoption.v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  @override
  Future<String?> read() => _preferences.getString(key);
  @override
  Future<void> write(String value) => _preferences.setString(key, value);
}
