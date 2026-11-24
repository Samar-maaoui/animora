import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import '../models/auth_requests.dart';

/// Same SharedPreferences Web encoding. Targeted fallback avoids enumerating
/// unrelated browser keys if the plugin's storage enumeration fails.
class PreferencesAuthBackend {
  PreferencesAuthBackend({this.readPreference});
  final Future<String?> Function(String)? readPreference;
  final SharedPreferencesAsync preferences = SharedPreferencesAsync();
  String? _selectedKey;
  String? _target(String key) {
    final raw = web.window.localStorage.getItem(key);
    if (raw == null) return null;
    final value = jsonDecode(raw);
    if (value is! String) {
      throw const FormatException('Invalid preference envelope');
    }
    return value;
  }

  Future<String?> read(String key) async {
    String? current;
    try {
      current = await (readPreference?.call(key) ?? preferences.getString(key));
    } catch (_) {
      current = _target(key);
    }
    if (current != null) {
      _selectedKey = key;
      return current;
    }
    final legacyKey = 'flutter.$key';
    final legacy = _target(legacyKey);
    _selectedKey = legacy == null ? key : legacyKey;
    return legacy;
  }

  Future<void> write(String key, String value, {String? expectedValue}) async {
    // Read access must succeed first, so a denied read never becomes an overwrite.
    await read(key);
    final selected = _selectedKey ?? key;
    // Same SharedPreferences Web JSON envelope, no await between the final
    // comparison and the one-key write. Never replace an observed newer value.
    if (_target(selected) != expectedValue) {
      throw const AuthFailure(
        AuthFailureCode.storage,
        'Les comptes ont changé. Réessayez sans effacer les données.',
        diagnostic: 'AUTH_PREFERENCES_CONCURRENT',
      );
    }
    web.window.localStorage.setItem(selected, jsonEncode(value));
  }
}
