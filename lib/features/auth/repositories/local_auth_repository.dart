import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/enums/account_status.dart';
import '../../../core/enums/user_profile.dart';
import '../../../core/utils/form_validators.dart';
import '../../users/models/user.dart';
import '../data/demo_accounts.dart';
import '../data/demo_recovery.dart';
import '../models/auth_event.dart';
import '../services/auth_security_store.dart';
import '../services/auth_snapshot.dart';
import '../services/profile_photo_rules.dart';
import '../services/auth_diagnostics.dart';
import '../models/auth_requests.dart';
import '../services/account_policy.dart';
import '../services/local_auth_storage.dart';
import '../services/password_hasher.dart';
import 'auth_repository.dart';

/// Temporary device-local demo database; NOT a server security boundary.
/// Mutations are serialized and published only after successful persistence.
class LocalAuthRepository extends AuthRepository {
  LocalAuthRepository({
    required this.storage,
    this.hasher = const PasswordHasher(),
    this.seedDemoAccounts = false,
    this.generateId = secureUserId,
    this.recoverDemoAccounts = false,
    AuthSecurityStore? securityStore,
    DateTime Function()? clock,
    this.maxFailedAttempts = 5,
    this.lockDuration = const Duration(minutes: 15),
  }) : securityStore = securityStore ?? MemoryAuthSecurityStore(),
       _clock = clock ?? DateTime.now;

  /// Security journal + device settings (SQLite on mobile, browser on Web).
  final AuthSecurityStore securityStore;
  final DateTime Function() _clock;

  /// Brute-force protection: this many failures lock the e-mail.
  final int maxFailedAttempts;
  final Duration lockDuration;
  static const _biometricKey = 'biometric_user';

  /// Password reset: validity of a code and wrong tries allowed per code.
  static const resetCodeValidity = Duration(minutes: 10);
  static const maxResetAttempts = 5;
  final _resetCodes = <String, _ResetCode>{};

  final AuthStorage storage;
  final bool seedDemoAccounts;
  final PasswordHasher hasher;
  final String Function() generateId;
  final bool recoverDemoAccounts;
  DemoRecoveryResult? demoRecoveryResult;
  Map<String, AuthAccount> _accounts = {};
  String? _sessionId;
  bool _loaded = false;
  bool _disposed = false;
  Future<void> _tail = Future.value();

  Future<T> _run<T>(Future<T> Function() action) {
    final result = _tail.then((_) async {
      await _load();
      try {
        return await action();
      } on AuthFailure {
        rethrow;
      } catch (error) {
        throw unknownAuthFailure(error);
      }
    });
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<void> _load() async {
    if (_loaded && storage is! RefreshableAuthStorage) return;
    var stage = 'read';
    try {
      final raw = await storage.read();
      if (raw == null) {
        final accounts = <String, AuthAccount>{};
        stage = 'development_seed';
        for (final user
            in seedDemoAccounts && kDebugMode ? DemoAccounts.users : <User>[]) {
          accounts[user.id] = AuthAccount(
            user,
            await _crypto(() => hasher.hash(DemoAccounts.password)),
          );
        }
        stage = 'initial_write';
        // An absent document is a valid fresh installation; no automatic write.
        if (seedDemoAccounts && kDebugMode) {
          await _commit(accounts, null, notify: false);
        } else {
          _accounts = accounts;
          _sessionId = null;
        }
      } else {
        stage = 'decode_validate';
        final snapshot = AuthSnapshot.decode(raw);
        _accounts = snapshot.accounts;
        _sessionId = snapshot.sessionId;
      }
      _loaded = true;
    } catch (error) {
      if (error is AuthFailure) rethrow;
      final message = stage == 'read' && error is! FormatException
          ? 'Accès aux comptes locaux refusé ou indisponible. Les données n’ont pas été effacées.'
          : (stage == 'decode_validate' || error is FormatException)
          ? 'Données de comptes locales invalides ou incompatibles. Elles sont conservées ; utilisez le diagnostic.'
          : 'Initialisation des comptes impossible. Les données existantes sont conservées.';
      throw AuthFailure(
        AuthFailureCode.storage,
        message,
        diagnostic: authDiagnostic('AUTH_${stage.toUpperCase()}', error),
      );
    }
  }

  Future<void> _commit(
    Map<String, AuthAccount> accounts,
    String? sessionId, {
    bool notify = true,
  }) async {
    final String encoded;
    try {
      encoded = AuthSnapshot(accounts, sessionId).encode();
    } catch (error) {
      throw AuthFailure(
        AuthFailureCode.serialization,
        'Les données du compte ne peuvent pas être préparées. Aucune écriture n’a été effectuée.',
        diagnostic: authDiagnostic('AUTH_JSON_ENCODE', error),
      );
    }
    try {
      await storage.write(encoded);
    } on AuthFailure {
      rethrow;
    } catch (error) {
      throw AuthFailure(
        AuthFailureCode.storage,
        'Enregistrement local impossible. Vos modifications n’ont pas été appliquées.',
        diagnostic: authDiagnostic('AUTH_WRITE', error),
      );
    }
    _accounts = accounts;
    _sessionId = sessionId;
    if (notify && !_disposed) notifyListeners();
  }

  User? get _current => _accounts[_sessionId]?.user;
  User _requireActive() {
    final user = _current;
    if (user == null || user.status != AccountStatus.active) {
      throw const AuthFailure(
        AuthFailureCode.forbidden,
        'Un compte actif est nécessaire.',
      );
    }
    return user;
  }

  void _requireAdmin() {
    if (_requireActive().profile != UserProfile.admin) {
      throw const AuthFailure(
        AuthFailureCode.forbidden,
        'Accès réservé aux administrateurs.',
      );
    }
  }

  /// The journal must never block the main action: a failed write is reported
  /// in the debug console only.
  Future<void> _log(
    AuthEventType type, {
    String? email,
    String? userId,
    String? actorId,
    String? details,
  }) async {
    try {
      await securityStore.record(
        AuthEvent(
          id: 0,
          type: type,
          createdAt: _clock().toUtc(),
          email: email,
          userId: userId,
          actorId: actorId,
          details: details,
        ),
      );
    } catch (error) {
      debugPrint('AUTH_SECURITY_LOG ${type.name}: $error');
    }
  }

  /// Failures for [email] within [lockDuration], since its last success.
  /// Events come newest first, so the scan stops at the latest success.
  Future<List<DateTime>> _recentFailures(String email) async {
    final List<AuthEvent> recent;
    try {
      recent = await securityStore.events(
        limit: 50,
        email: email,
        since: _clock().toUtc().subtract(lockDuration),
      );
    } catch (error) {
      debugPrint('AUTH_SECURITY_READ $error');
      return const [];
    }
    final failures = <DateTime>[];
    for (final event in recent) {
      if (event.type == AuthEventType.loginSuccess ||
          event.type == AuthEventType.loginBiometric) {
        break;
      }
      if (event.type == AuthEventType.loginFailure) {
        failures.add(event.createdAt);
      }
    }
    return failures;
  }

  Future<DateTime?> _lockedUntil(String email) async {
    final failures = await _recentFailures(email);
    if (failures.length < maxFailedAttempts) return null;
    return failures.first.add(lockDuration);
  }

  AuthFailure _lockedFailure(DateTime until) {
    final seconds = until.difference(_clock().toUtc()).inSeconds;
    final minutes = seconds <= 60 ? 1 : (seconds + 59) ~/ 60;
    return AuthFailure(
      AuthFailureCode.locked,
      'Trop de tentatives échouées. Réessayez dans $minutes min.',
      diagnostic: 'AUTH_LOCKED',
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Future<void> initialize() => _run(() async {
    if (DemoRecovery.permitted(
      requested: recoverDemoAccounts,
      debugBuild: kDebugMode,
    )) {
      await _recoverMissingDemoAccounts();
    }
  });

  Future<void> _recoverMissingDemoAccounts() async {
    final profiles = storage is AuthRecoveryProfileSource
        ? await (storage as AuthRecoveryProfileSource).readRecoveryProfiles()
        : _accounts.values.map((a) => a.user).toList();
    final draft = Map<String, AuthAccount>.of(_accounts);
    final created = <String>[],
        preserved = <String>[],
        conflicts = <String>[],
        mismatches = <String>[];
    String normalize(String email) => email.trim().toLowerCase();
    for (final template in DemoRecovery.users) {
      final matches = _accounts.values.where(
        (a) => normalize(a.user.email) == normalize(template.email),
      );
      if (matches.isNotEmpty) {
        final account = matches.single;
        preserved.add(account.user.id);
        if (!await _crypto(
          () => hasher.verify(DemoAccounts.password, account.password),
        )) {
          mismatches.add(account.user.id); // Never reset an existing password.
        }
        continue;
      }
      final existingProfiles = profiles
          .where((u) => normalize(u.email) == normalize(template.email))
          .toList();
      if (existingProfiles.length > 1) {
        conflicts.add(template.id);
        continue;
      }
      final user = existingProfiles.isEmpty
          ? template
          : existingProfiles.single;
      if (draft.containsKey(user.id) ||
          profiles.any(
            (u) =>
                u.id == user.id && normalize(u.email) != normalize(user.email),
          )) {
        conflicts.add(template.id);
        continue;
      }
      draft[user.id] = AuthAccount(
        user,
        await _crypto(() => hasher.hash(DemoAccounts.password)),
      );
      created.add(user.id);
    }
    // One commit: no partial seed if hashing or persistence fails. Keep session.
    if (created.isNotEmpty) await _commit(draft, _sessionId);
    demoRecoveryResult = DemoRecoveryResult(
      created: created,
      preserved: preserved,
      conflicts: conflicts,
      passwordMismatches: mismatches,
    );
    debugPrint(
      'AUTH_DEMO_RECOVERY created=${created.length}; preserved=${preserved.length}; conflicts=${conflicts.length}; password_mismatches=${mismatches.length}',
    );
  }

  @override
  Future<User?> getCurrentUser() => _run(() async => _current);
  @override
  Future<User> login(String email, String password) => _run(() async {
    final normalized = email.trim().toLowerCase();
    final lockedUntil = await _lockedUntil(normalized);
    if (lockedUntil != null) {
      await _log(
        AuthEventType.loginLocked,
        email: normalized,
        details: 'tentative refusée pendant le verrouillage',
      );
      throw _lockedFailure(lockedUntil);
    }
    final matches = _accounts.values.where(
      (a) => a.user.email.trim().toLowerCase() == normalized,
    );
    final account = matches.firstOrNull;
    if (account == null ||
        !await _crypto(() => hasher.verify(password, account.password))) {
      await _log(
        AuthEventType.loginFailure,
        email: normalized,
        userId: account?.user.id,
      );
      final nowLocked = await _lockedUntil(normalized);
      if (nowLocked != null) {
        // The lock starts now: journal it immediately, not at the next try.
        await _log(
          AuthEventType.loginLocked,
          email: normalized,
          userId: account?.user.id,
          details:
              '$maxFailedAttempts échecs · verrouillé ${lockDuration.inMinutes} min',
        );
        throw _lockedFailure(nowLocked);
      }
      final remaining =
          maxFailedAttempts - (await _recentFailures(normalized)).length;
      throw AuthFailure(
        AuthFailureCode.invalidCredentials,
        remaining <= 2
            ? 'E-mail ou mot de passe incorrect. '
                  '$remaining tentative(s) avant verrouillage temporaire.'
            : 'E-mail ou mot de passe incorrect.',
        diagnostic: 'AUTH_CREDENTIALS',
      );
    }
    // Retain pending/blocked identities only to show their dedicated access screen.
    await _commit(Map.of(_accounts), account.user.id);
    await _log(
      AuthEventType.loginSuccess,
      email: normalized,
      userId: account.user.id,
      details: 'mot de passe',
    );
    return account.user;
  });

  @override
  Future<User> register(RegisterRequest request) =>
      _run(() => _createAccount(request));

  /// Field rules, allowed profile and unique e-mail (throws AuthFailure).
  void _checkRegistration(RegisterRequest request) {
    if (!AccountPolicy.publicProfiles.contains(request.profile)) {
      throw const AuthFailure(
        AuthFailureCode.forbidden,
        'Ce profil ne peut pas être créé publiquement.',
        field: 'profile',
      );
    }
    final validations = <String, String?>{
      'firstName': FormValidators.requiredText(request.firstName),
      'lastName': FormValidators.requiredText(request.lastName),
      'email': FormValidators.email(request.email),
      'phone': FormValidators.phone(request.phone),
      'city': FormValidators.requiredText(request.city),
      'password': FormValidators.password(request.password),
      'professionalCard': request.profile == UserProfile.veterinarian
          ? FormValidators.professionalCard(request.professionalCardNumber)
          : null,
    };
    _validate(validations);
    final email = request.email.trim().toLowerCase();
    if (_accounts.values.any(
      (a) => a.user.email.trim().toLowerCase() == email,
    )) {
      throw const AuthFailure(
        AuthFailureCode.duplicateEmail,
        'Cette adresse e-mail est déjà utilisée.',
        field: 'email',
        diagnostic: 'AUTH_DUPLICATE_EMAIL',
      );
    }
  }

  Future<User> _createAccount(RegisterRequest request) async {
    _checkRegistration(request);
    final email = request.email.trim().toLowerCase();
    final String id;
    try {
      id = generateId();
    } catch (error) {
      throw AuthFailure(
        AuthFailureCode.cryptographyUnavailable,
        'La génération sécurisée du compte est indisponible dans ce navigateur. Utilisez une connexion HTTPS de confiance et réessayez. Aucun compte n’a été écrit.',
        diagnostic: authDiagnostic('AUTH_RANDOM_UNAVAILABLE', error),
      );
    }
    final user = User(
      id: id,
      firstName: request.firstName.trim(),
      lastName: request.lastName.trim(),
      email: email,
      phone: request.phone.trim(),
      city: request.city.trim(),
      profile: request.profile,
      status: AccountPolicy.initialStatus(request.profile),
      createdAt: DateTime.now().toUtc(),
      professionalCardNumber: request.profile == UserProfile.veterinarian
          ? request.professionalCardNumber!.trim().toUpperCase()
          : null,
    );
    final account = AuthAccount(
      user,
      await _crypto(() => hasher.hash(request.password)),
    );
    await _commit({..._accounts, id: account}, _sessionId);
    await _log(AuthEventType.register, email: email, userId: id);
    return user; // Registration deliberately does not sign in.
  }

  Future<T> _crypto<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw AuthFailure(
        error is UnsupportedError
            ? AuthFailureCode.cryptographyUnavailable
            : AuthFailureCode.hashing,
        'Le calcul sécurisé du mot de passe est indisponible. Les comptes sont conservés. Consultez le diagnostic et privilégiez une origine HTTPS pour les essais Web.',
        diagnostic: authDiagnostic(
          error is UnsupportedError ? 'AUTH_CRYPTO_UNAVAILABLE' : 'AUTH_KDF',
          error,
        ),
      );
    }
  }

  void _validate(Map<String, String?> validations) {
    for (final entry in validations.entries) {
      if (entry.value != null) {
        throw AuthFailure(
          AuthFailureCode.invalidInput,
          entry.value!,
          field: entry.key,
          diagnostic: 'AUTH_VALIDATION',
        );
      }
    }
  }

  @override
  Future<void> logout() => _run(() async {
    final user = _current;
    await _commit(Map.of(_accounts), null);
    if (user != null) {
      await _log(AuthEventType.logout, email: user.email, userId: user.id);
    }
  });
  @override
  Future<User> updateProfile(ProfileUpdate update) => _run(() async {
    final current = _requireActive();
    _validate({
      'firstName': FormValidators.requiredText(update.firstName),
      'lastName': FormValidators.requiredText(update.lastName),
      'phone': FormValidators.phone(update.phone),
      'city': FormValidators.requiredText(update.city),
    });
    final updated = current.copyWith(
      firstName: update.firstName.trim(),
      lastName: update.lastName.trim(),
      phone: update.phone.trim(),
      city: update.city.trim(),
    );
    await _commit({
      ..._accounts,
      current.id: AuthAccount(updated, _accounts[current.id]!.password),
    }, _sessionId);
    await _log(
      AuthEventType.profileUpdate,
      email: current.email,
      userId: current.id,
    );
    return updated;
  });

  @override
  Future<void> changePassword(String currentPassword, String newPassword) =>
      _run(() async {
        final current = _requireActive();
        final account = _accounts[current.id]!;
        if (!await _crypto(
          () => hasher.verify(currentPassword, account.password),
        )) {
          throw const AuthFailure(
            AuthFailureCode.invalidCredentials,
            'Mot de passe actuel incorrect.',
            field: 'currentPassword',
            diagnostic: 'AUTH_CURRENT_PASSWORD',
          );
        }
        _validate({
          'newPassword': FormValidators.newPassword(
            newPassword,
            currentPassword,
          ),
        });
        // A new salt and hash; the SQLite adapter stages a new vault entry.
        final digest = await _crypto(() => hasher.hash(newPassword));
        await _commit({
          ..._accounts,
          current.id: AuthAccount(current, digest),
        }, _sessionId);
        await _log(
          AuthEventType.passwordChange,
          email: current.email,
          userId: current.id,
        );
      });

  @override
  Future<User> updateProfilePhoto(String? photo) => _run(() async {
    final current = _requireActive();
    _validate({'photo': ProfilePhotoRules.check(photo)});
    final updated = current.withPhoto(photo);
    await _commit({
      ..._accounts,
      current.id: AuthAccount(updated, _accounts[current.id]!.password),
    }, _sessionId);
    await _log(
      AuthEventType.photoUpdate,
      email: current.email,
      userId: current.id,
      details: photo == null ? 'supprimée' : 'remplacée',
    );
    return updated;
  });

  /// Issues a fresh code for [key] (purpose + e-mail); only its hash is kept
  /// and a new request replaces the previous code.
  Future<(String, DateTime)> _issueCode(String key) async {
    final random = Random.secure();
    final code = List.generate(6, (_) => random.nextInt(10)).join();
    final expiresAt = _clock().toUtc().add(resetCodeValidity);
    _resetCodes[key] = _ResetCode(
      await _crypto(() => hasher.hash(code)),
      expiresAt,
    );
    return (code, expiresAt);
  }

  /// Checks [code] for [key]; consumes it on success.
  Future<void> _consumeCode(String key, String code) async {
    final pending = _resetCodes[key];
    if (pending == null || _clock().toUtc().isAfter(pending.expiresAt)) {
      _resetCodes.remove(key);
      throw const AuthFailure(
        AuthFailureCode.invalidCredentials,
        'Code expiré ou inexistant. Demandez un nouveau code.',
        field: 'code',
        diagnostic: 'AUTH_CODE_EXPIRED',
      );
    }
    if (!await _crypto(() => hasher.verify(code.trim(), pending.digest))) {
      pending.attempts++;
      if (pending.attempts >= maxResetAttempts) {
        _resetCodes.remove(key);
        throw const AuthFailure(
          AuthFailureCode.locked,
          'Trop de codes erronés. Demandez un nouveau code.',
          field: 'code',
          diagnostic: 'AUTH_CODE_LOCKED',
        );
      }
      throw AuthFailure(
        AuthFailureCode.invalidCredentials,
        'Code incorrect. ${maxResetAttempts - pending.attempts} essai(s) restant(s).',
        field: 'code',
        diagnostic: 'AUTH_CODE_WRONG',
      );
    }
    _resetCodes.remove(key);
  }

  @override
  Future<PasswordResetTicket?> createPasswordResetCode(String email) =>
      _run(() async {
        final normalized = email.trim().toLowerCase();
        _validate({'email': FormValidators.email(normalized)});
        final account = _accounts.values
            .where((a) => a.user.email.trim().toLowerCase() == normalized)
            .firstOrNull;
        await _log(
          AuthEventType.passwordResetRequested,
          email: normalized,
          userId: account?.user.id,
          details: account == null ? 'adresse inconnue · aucun envoi' : null,
        );
        if (account == null) return null;
        final (code, expiresAt) = await _issueCode('reset:$normalized');
        return EmailCodeTicket(
          email: normalized,
          firstName: account.user.firstName,
          code: code,
          expiresAt: expiresAt,
        );
      });

  @override
  Future<void> resetPasswordWithCode(
    String email,
    String code,
    String newPassword,
  ) => _run(() async {
    final normalized = email.trim().toLowerCase();
    _validate({'password': FormValidators.password(newPassword)});
    await _consumeCode('reset:$normalized', code);
    final account = _accounts.values
        .where((a) => a.user.email.trim().toLowerCase() == normalized)
        .firstOrNull;
    if (account == null) {
      throw const AuthFailure(
        AuthFailureCode.invalidInput,
        'Compte introuvable.',
        diagnostic: 'AUTH_RESET_ACCOUNT',
      );
    }
    final digest = await _crypto(() => hasher.hash(newPassword));
    await _commit({
      ..._accounts,
      account.user.id: AuthAccount(account.user, digest),
    }, _sessionId);
    await _log(
      AuthEventType.passwordReset,
      email: normalized,
      userId: account.user.id,
    );
  });

  @override
  Future<EmailCodeTicket> createEmailVerificationCode(
    RegisterRequest request,
  ) => _run(() async {
    _checkRegistration(request);
    final email = request.email.trim().toLowerCase();
    final (code, expiresAt) = await _issueCode('verify:$email');
    await _log(
      AuthEventType.emailCodeSent,
      email: email,
      details: 'inscription · ${request.profile.name}',
    );
    return EmailCodeTicket(
      email: email,
      firstName: request.firstName.trim(),
      code: code,
      expiresAt: expiresAt,
      purpose: EmailCodePurpose.verifyEmail,
    );
  });

  @override
  Future<User> registerWithEmailCode(RegisterRequest request, String code) =>
      _run(() async {
        _checkRegistration(request);
        final email = request.email.trim().toLowerCase();
        await _consumeCode('verify:$email', code);
        await _log(AuthEventType.emailVerified, email: email);
        return _createAccount(request);
      });

  // Biometrics: the store only remembers WHICH account is enrolled on this
  // device; the fingerprint/face check itself is done by the OS (local_auth).
  @override
  Future<String?> biometricAccountEmail() => _run(() async {
    final id = await securityStore.readSetting(_biometricKey);
    return id == null ? null : _accounts[id]?.user.email;
  });

  @override
  Future<void> enableBiometricLogin() => _run(() async {
    final current = _requireActive();
    await securityStore.writeSetting(_biometricKey, current.id);
    await _log(
      AuthEventType.biometricEnabled,
      email: current.email,
      userId: current.id,
    );
    if (!_disposed) notifyListeners();
  });

  @override
  Future<void> disableBiometricLogin() => _run(() async {
    final current = _current;
    await securityStore.writeSetting(_biometricKey, null);
    await _log(
      AuthEventType.biometricDisabled,
      email: current?.email,
      userId: current?.id,
    );
    if (!_disposed) notifyListeners();
  });

  @override
  Future<User> loginWithBiometrics() => _run(() async {
    final id = await securityStore.readSetting(_biometricKey);
    final account = id == null ? null : _accounts[id];
    if (account == null) {
      throw const AuthFailure(
        AuthFailureCode.forbidden,
        'Aucun compte n’est associé à la biométrie sur cet appareil.',
        diagnostic: 'AUTH_BIOMETRIC_NOT_ENROLLED',
      );
    }
    await _commit(Map.of(_accounts), account.user.id);
    await _log(
      AuthEventType.loginBiometric,
      email: account.user.email,
      userId: account.user.id,
      details: 'empreinte / visage',
    );
    return account.user;
  });

  @override
  Future<List<AuthEvent>> listAuthEvents({int limit = 100}) => _run(() async {
    _requireAdmin();
    return securityStore.events(limit: limit);
  });

  @override
  Future<List<User>> listServiceProviders() => _run(() async {
    _requireActive();
    return _accounts.values
        .map((a) => a.user)
        .where(
          (u) =>
              u.status == AccountStatus.active &&
              [
                UserProfile.veterinarian,
                UserProfile.petSitter,
              ].contains(u.profile),
        )
        .map(
          (u) => User(
            id: u.id,
            firstName: u.firstName,
            lastName: u.lastName,
            email: '',
            city: u.city,
            photo: u.photo,
            profile: u.profile,
            status: u.status,
            createdAt: u.createdAt,
          ),
        )
        .toList();
  });
  @override
  Future<bool> isUserActive(String id) => _run(() async {
    _requireActive();
    return _accounts[id]?.user.status == AccountStatus.active;
  });

  @override
  Future<List<User>> listUsers() => _run(() async {
    _requireAdmin();
    return List.unmodifiable(
      _accounts.values.map((a) => a.user).toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName)),
    );
  });
  @override
  Future<void> deleteUser(
    String id, {
    bool rejection = false,
  }) => _run(() async {
    _requireAdmin();
    final account = _accounts[id];
    if (account == null) {
      throw const AuthFailure(
        AuthFailureCode.invalidInput,
        'Utilisateur introuvable.',
      );
    }
    if (id == _sessionId) {
      throw const AuthFailure(
        AuthFailureCode.forbidden,
        'Vous ne pouvez pas supprimer votre propre compte.',
      );
    }
    final user = account.user;
    if (user.profile == UserProfile.admin) {
      throw const AuthFailure(
        AuthFailureCode.forbidden,
        'Un compte administrateur ne peut pas être supprimé ici.',
      );
    }
    if (rejection && user.status != AccountStatus.pending) {
      throw const AuthFailure(
        AuthFailureCode.invalidInput,
        'Seule une inscription en attente peut être refusée.',
      );
    }
    final remaining = Map.of(_accounts)..remove(id);
    await _commit(remaining, _sessionId);
    // Forget everything still attached to this account on the device.
    final email = user.email.trim().toLowerCase();
    _resetCodes.remove('reset:$email');
    _resetCodes.remove('verify:$email');
    try {
      if (await securityStore.readSetting(_biometricKey) == id) {
        await securityStore.writeSetting(_biometricKey, null);
      }
    } catch (_) {}
    await _log(
      rejection ? AuthEventType.accountRejected : AuthEventType.accountDeleted,
      email: email,
      userId: id,
      actorId: _sessionId,
      details: '${user.fullName} · ${user.profile.name} · ${user.status.name}',
    );
  });

  @override
  Future<void> updateUserStatus(String id, AccountStatus status) =>
      _run(() async {
        _requireAdmin();
        final account = _accounts[id];
        if (account == null) {
          throw const AuthFailure(
            AuthFailureCode.invalidInput,
            'Utilisateur introuvable.',
          );
        }
        if (id == _sessionId) {
          throw const AuthFailure(
            AuthFailureCode.forbidden,
            'Vous ne pouvez pas modifier votre propre statut.',
          );
        }
        if (!AccountPolicy.canTransition(account.user.status, status)) {
          throw const AuthFailure(
            AuthFailureCode.invalidInput,
            'Ce changement de statut n’est pas autorisé.',
          );
        }
        final updated = AuthAccount(
          account.user.copyWith(status: status),
          account.password,
        );
        await _commit({..._accounts, id: updated}, _sessionId);
        await _log(
          AuthEventType.statusChange,
          email: account.user.email,
          userId: id,
          actorId: _sessionId,
          details: '${account.user.status.name} → ${status.name}',
        );
      });
}

class _ResetCode {
  _ResetCode(this.digest, this.expiresAt);
  final PasswordDigest digest;
  final DateTime expiresAt;
  int attempts = 0;
}

String secureUserId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
