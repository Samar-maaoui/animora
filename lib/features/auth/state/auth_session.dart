import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/enums/account_status.dart';
import '../../users/models/user.dart';
import '../models/auth_event.dart';
import '../models/auth_requests.dart';
import '../repositories/auth_repository.dart';
import '../services/biometric_service.dart';
import '../services/password_reset_mailer.dart';

String authErrorMessage(Object error) => error is AuthFailure
    ? error.message
    : 'Une erreur est survenue. Veuillez réessayer.';

class AuthSession extends ChangeNotifier {
  AuthSession(
    this._repository, {
    BiometricService? biometrics,
    PasswordResetMailer? mailer,
  }) : biometrics = biometrics ?? const UnavailableBiometricService(),
       mailer = mailer ?? EmailJsPasswordResetMailer() {
    _repository.addListener(_repositoryChanged);
  }
  final AuthRepository _repository;

  /// Device fingerprint/face check (unavailable on Web and in tests).
  final BiometricService biometrics;

  /// Delivers password reset codes by e-mail.
  final PasswordResetMailer mailer;
  User? _currentUser;
  User? get currentUser => _currentUser;
  bool _ready = false, _busy = false, _disposed = false;
  bool get ready => _ready;
  bool get busy => _busy;
  String? initializationError;
  String? initializationDiagnostic;
  Future<void>? _initialization;
  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    initializationError = null;
    initializationDiagnostic = null;
    _notify();
    try {
      await _repository.initialize();
      _currentUser = await _repository.getCurrentUser();
      _ready = true;
    } catch (error) {
      initializationError = authErrorMessage(error);
      initializationDiagnostic = error is AuthFailure ? error.diagnostic : null;
    }
    _notify();
  }

  Future<void> retryInitialization() {
    _initialization = null;
    return initialize();
  }

  void _repositoryChanged() {
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final user = await _repository.getCurrentUser();
      if (!_disposed) {
        _currentUser = user;
        _notify();
      }
    } catch (error) {
      if (!_disposed) {
        initializationError = authErrorMessage(error);
        _notify();
      }
    }
  }

  Future<T> _perform<T>(Future<T> Function() action) async {
    if (_busy) {
      throw const AuthFailure(
        AuthFailureCode.busy,
        'Une opération est déjà en cours.',
      );
    }
    _busy = true;
    _notify();
    try {
      final result = await action();
      _currentUser = await _repository.getCurrentUser();
      return result;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> login(String email, String password) => _perform(() async {
    await _repository.login(email, password);
  });
  Future<User> register(RegisterRequest request) =>
      _perform(() => _repository.register(request));
  Future<void> logout() => _perform(_repository.logout);
  Future<void> updateProfile(ProfileUpdate update) => _perform(() async {
    await _repository.updateProfile(update);
  });
  Future<void> changePassword(String currentPassword, String newPassword) =>
      _perform(() => _repository.changePassword(currentPassword, newPassword));

  /// Sends a reset code by e-mail. Returns the code itself only in debug
  /// builds without e-mail configuration (so the flow stays testable).
  /// The answer never reveals whether an account exists.
  Future<String?> requestPasswordReset(String email) => _perform(() async {
    final ticket = await _repository.createPasswordResetCode(email);
    if (ticket == null) return null;
    return _deliver(ticket);
  });

  /// Sign-up step 1: validates the form and e-mails a verification code.
  /// Returns the code only in debug builds without e-mail configuration.
  Future<String?> sendRegistrationCode(RegisterRequest request) =>
      _perform(() async {
        final ticket = await _repository.createEmailVerificationCode(request);
        return _deliver(ticket);
      });

  /// Sign-up step 2: the account is created once the e-mail is verified.
  Future<User> registerWithEmailCode(RegisterRequest request, String code) =>
      _perform(() => _repository.registerWithEmailCode(request, code));

  Future<String?> _deliver(EmailCodeTicket ticket) async {
    if (!mailer.configured) {
      if (kDebugMode) return ticket.code;
      throw const AuthFailure(
        AuthFailureCode.forbidden,
        'Clés EmailJS absentes : aucun e-mail ne peut être envoyé. '
        'Lancez l’app avec --dart-define-from-file=config/api-keys.json.',
        diagnostic: 'MAIL_NOT_CONFIGURED',
      );
    }
    await mailer.send(ticket);
    return null;
  }

  Future<void> resetPassword(String email, String code, String newPassword) =>
      _perform(
        () => _repository.resetPasswordWithCode(email, code, newPassword),
      );

  Future<void> updateProfilePhoto(String? photo) => _perform(() async {
    await _repository.updateProfilePhoto(photo);
  });

  /// E-mail shown on the login screen, or null when biometric login cannot
  /// be offered (no hardware, nothing enrolled, Web).
  Future<String?> biometricAccount() async {
    if (!await biometrics.isAvailable()) return null;
    return _repository.biometricAccountEmail();
  }

  /// True when the signed-in user is the account enrolled on this device.
  Future<bool> biometricEnabledForCurrentUser() async {
    final user = _currentUser;
    if (user == null) return false;
    return await _repository.biometricAccountEmail() == user.email;
  }

  Future<void> enableBiometrics() => _perform(() async {
    final confirmed = await biometrics.authenticate(
      'Confirmez votre identité pour activer la connexion biométrique',
    );
    if (!confirmed) {
      throw const AuthFailure(
        AuthFailureCode.invalidCredentials,
        'Vérification biométrique annulée ou échouée.',
      );
    }
    await _repository.enableBiometricLogin();
  });

  Future<void> disableBiometrics() =>
      _perform(_repository.disableBiometricLogin);

  /// Returns false when the user cancelled the system prompt.
  Future<bool> loginWithBiometrics() => _perform(() async {
    final confirmed = await biometrics.authenticate('Connectez-vous à Animora');
    if (!confirmed) return false;
    await _repository.loginWithBiometrics();
    return true;
  });

  Future<List<AuthEvent>> listAuthEvents({int limit = 100}) =>
      _repository.listAuthEvents(limit: limit);

  Future<List<User>> listServiceProviders() =>
      _repository.listServiceProviders();
  Future<bool> isUserActive(String id) => _repository.isUserActive(id);
  Future<List<User>> listUsers() => _repository.listUsers();

  /// Admin: refuses a pending registration (the account is deleted).
  Future<void> rejectUser(String id) =>
      _perform(() => _repository.deleteUser(id, rejection: true));

  /// Admin: deletes an account (refused if it has history in the app).
  Future<void> deleteUser(String id) =>
      _perform(() => _repository.deleteUser(id));

  Future<void> updateUserStatus(String id, AccountStatus status) =>
      _perform(() => _repository.updateUserStatus(id, status));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _repository.removeListener(_repositoryChanged);
    super.dispose();
  }
}
