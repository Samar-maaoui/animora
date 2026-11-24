import 'preferences_auth_backend.dart';
import 'auth_snapshot.dart';
import 'auth_diagnostics.dart';
import '../models/auth_requests.dart';
import '../../users/models/user.dart';

abstract interface class AuthStorage {
  Future<String?> read();
  Future<void> write(String value);
}

abstract interface class RefreshableAuthStorage implements AuthStorage {}

/// Includes relational profiles that may predate an authentication account.
abstract interface class AuthRecoveryProfileSource {
  Future<List<User>> readRecoveryProfiles();
}

class PreferencesAuthStorage implements RefreshableAuthStorage {
  static const key = 'animora.local_auth.v1';
  final PreferencesAuthBackend _preferences = PreferencesAuthBackend();
  String? _loadedValue;
  bool _hasRead = false;
  @override
  Future<String?> read() async {
    final value = await _read();
    _loadedValue = value;
    _hasRead = true;
    return value;
  }

  Future<String?> _read() async {
    try {
      return await _preferences.read(key);
    } catch (error) {
      throw AuthFailure(
        error is FormatException
            ? AuthFailureCode.serialization
            : AuthFailureCode.storage,
        error is FormatException
            ? 'Les données des comptes sont incompatibles. Elles sont conservées ; relevez le diagnostic.'
            : 'Le navigateur ne permet pas de lire les comptes. Les données n’ont pas été effacées.',
        diagnostic: authDiagnostic(
          error is FormatException
              ? 'AUTH_JSON_ENVELOPE'
              : 'AUTH_PREFERENCES_READ',
          error,
        ),
      );
    }
  }

  @override
  Future<void> write(String value) async {
    if (!_hasRead) await read();
    final existing = await _read();
    if (existing != _loadedValue) {
      throw const AuthFailure(
        AuthFailureCode.storage,
        'Les comptes ont changé dans un autre onglet. Réessayez pour relire les données actuelles.',
        diagnostic: 'AUTH_PREFERENCES_CONCURRENT',
      );
    }
    try {
      if (existing != null) AuthSnapshot.decode(existing);
      AuthSnapshot.decode(value);
    } catch (error) {
      throw AuthFailure(
        AuthFailureCode.serialization,
        'Le document des comptes est invalide. Aucun compte existant n’a été remplacé.',
        diagnostic: authDiagnostic('AUTH_JSON_VALIDATE_WRITE', error),
      );
    }
    try {
      await _preferences.write(key, value, expectedValue: existing);
      _loadedValue = value;
    } on AuthFailure {
      rethrow;
    } catch (error) {
      throw AuthFailure(
        AuthFailureCode.storage,
        'Le navigateur n’a pas pu enregistrer le compte. Vérifiez que le stockage du site est autorisé, puis réessayez.',
        diagnostic: authDiagnostic('AUTH_PREFERENCES_WRITE', error),
      );
    }
  }
}
