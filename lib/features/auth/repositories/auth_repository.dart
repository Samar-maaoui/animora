import 'package:flutter/foundation.dart';

import '../../../core/enums/account_status.dart';
import '../../users/models/user.dart';
import '../models/auth_event.dart';
import '../models/auth_requests.dart';

/// Replace with a REST implementation without changing the screens.
/// Notifications tell the shared session to refresh after account mutations.
abstract class AuthRepository extends ChangeNotifier {
  Future<void> initialize();
  Future<User?> getCurrentUser();
  Future<User> login(String email, String password);
  Future<User> register(RegisterRequest request);
  Future<void> logout();
  Future<User> updateProfile(ProfileUpdate update);

  /// Requires the current password; the new one must differ from it.
  Future<void> changePassword(String currentPassword, String newPassword);

  /// Creates a 6-digit one-time code for [email] (valid a few minutes).
  Future<PasswordResetTicket?> createPasswordResetCode(String email) async =>
      throw _resetUnsupported;

  /// Replaces the password when [code] matches the latest valid code.
  Future<void> resetPasswordWithCode(
    String email,
    String code,
    String newPassword,
  ) async => throw _resetUnsupported;

  /// Sign-up step 1: validates [request] (fields, free e-mail) and creates
  /// a code proving the user owns the e-mail address.
  Future<EmailCodeTicket> createEmailVerificationCode(
    RegisterRequest request,
  ) async => throw _resetUnsupported;

  /// Sign-up step 2: creates the account only if [code] is valid.
  Future<User> registerWithEmailCode(
    RegisterRequest request,
    String code,
  ) async => throw _resetUnsupported;

  static const _resetUnsupported = AuthFailure(
    AuthFailureCode.forbidden,
    'La réinitialisation du mot de passe n’est pas disponible.',
  );

  /// [photo] is a `data:image/...;base64,` URI, or null to remove it.
  Future<User> updateProfilePhoto(String? photo);

  Future<String?> biometricAccountEmail() async => null;

  Future<void> enableBiometricLogin() async => throw _unsupported;
  Future<void> disableBiometricLogin() async {}

  Future<User> loginWithBiometrics() async => throw _unsupported;

  Future<List<AuthEvent>> listAuthEvents({int limit = 100}) async => const [];

  static const _unsupported = AuthFailure(
    AuthFailureCode.forbidden,
    'La connexion biométrique n’est pas disponible sur cette plateforme.',
  );
  Future<List<User>> listUsers();

  Future<bool> isUserActive(String id);

  Future<List<User>> listServiceProviders();
  Future<void> updateUserStatus(String id, AccountStatus status);

  /// Admin: deletes an account. With [rejection], only a PENDING account
  /// can be deleted (refused registration).
  Future<void> deleteUser(String id, {bool rejection = false}) async =>
      throw const AuthFailure(
        AuthFailureCode.forbidden,
        'La suppression de comptes n’est pas disponible.',
      );
}
