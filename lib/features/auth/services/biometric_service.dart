import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Device fingerprint / face check. The repository only stores *which*
/// account is enrolled; this service proves the device owner is present.
abstract interface class BiometricService {
  Future<bool> isAvailable();

  /// Shows the system prompt. Returns false if cancelled or failed.
  Future<bool> authenticate(String reason);
}

class DeviceBiometricService implements BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // Only localizedReason is passed so the call works with local_auth 2.x
      // and 3.x. The system may offer the device PIN as a fallback.
      return await _auth.authenticate(localizedReason: reason);
    } catch (_) {
      return false;
    }
  }
}

/// Web, desktop and tests.
class UnavailableBiometricService implements BiometricService {
  const UnavailableBiometricService();
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<bool> authenticate(String reason) async => false;
}
