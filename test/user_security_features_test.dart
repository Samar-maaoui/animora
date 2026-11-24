import 'package:animora/core/database/database_helper.dart';
import 'package:animora/core/enums/account_status.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/auth/models/auth_event.dart';
import 'package:animora/features/auth/models/auth_requests.dart';
import 'package:animora/features/auth/repositories/local_auth_repository.dart';
import 'package:animora/features/auth/repositories/sqlite_auth_repository.dart';
import 'package:animora/features/auth/services/auth_security_store.dart';
import 'package:animora/features/auth/services/auth_vault.dart';
import 'package:animora/features/auth/services/biometric_service.dart';
import 'package:animora/features/auth/services/password_hasher.dart';
import 'package:animora/features/auth/services/profile_photo_rules.dart';
import 'package:animora/features/auth/services/sqlite_auth_security_store.dart';
import 'package:animora/features/auth/services/sqlite_auth_storage.dart';
import 'package:animora/features/auth/state/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/auth_test_support.dart';

const _password = DemoAccounts.password;
const _citizen = 'citizen@animora.test';

/// 1×1 transparent PNG.
const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

Matcher _failure(AuthFailureCode code) =>
    throwsA(isA<AuthFailure>().having((f) => f.code, 'code', code));

class FakeBiometrics implements BiometricService {
  FakeBiometrics({this.available = true, this.accept = true});
  bool available, accept;
  int prompts = 0;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return accept;
  }
}

void main() {
  late DateTime now;
  late MemoryAuthSecurityStore store;

  setUp(() {
    now = DateTime.utc(2026, 11, 10, 9);
    store = MemoryAuthSecurityStore();
  });

  Future<LocalAuthRepository> open() async {
    final repository = LocalAuthRepository(
      storage: MemoryAuthStorage(await seedDatabase()),
      hasher: const PasswordHasher(iterations: 10000),
      securityStore: store,
      clock: () => now,
    );
    await repository.initialize();
    addTearDown(repository.dispose);
    return repository;
  }

  group('Brute-force lockout', () {
    test('Five failures lock the e-mail for 15 minutes', () async {
      final repo = await open();
      for (var i = 0; i < 4; i++) {
        await expectLater(
          repo.login(_citizen, 'wrong-password'),
          _failure(AuthFailureCode.invalidCredentials),
        );
        now = now.add(const Duration(seconds: 1));
      }
      await expectLater(
        repo.login(_citizen, 'wrong-password'),
        _failure(AuthFailureCode.locked),
      );
      // Even the right password is refused while locked.
      await expectLater(
        repo.login(_citizen, _password),
        _failure(AuthFailureCode.locked),
      );
      // Other accounts are not affected.
      await repo.login('foster@animora.test', _password);

      now = now.add(const Duration(minutes: 16));
      expect((await repo.login(_citizen, _password)).email, _citizen);
    });

    test(
      'A success resets the counter; first failures keep the old message',
      () async {
        final repo = await open();
        await expectLater(
          repo.login(_citizen, 'nope'),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.message,
              'message',
              'E-mail ou mot de passe incorrect.',
            ),
          ),
        );
        for (var i = 0; i < 3; i++) {
          await expectLater(repo.login(_citizen, 'nope'), throwsA(anything));
        }
        await repo.login(_citizen, _password);
        await repo.logout();
        await expectLater(
          repo.login(_citizen, 'nope'),
          _failure(AuthFailureCode.invalidCredentials),
        );
      },
    );
  });

  group('Password change', () {
    test('Checks the current password and replaces it', () async {
      final repo = await open();
      await repo.login(_citizen, _password);
      await expectLater(
        repo.changePassword('bad-current', 'NewSecret2026!'),
        _failure(AuthFailureCode.invalidCredentials),
      );
      await expectLater(
        repo.changePassword(_password, _password),
        _failure(AuthFailureCode.invalidInput),
      );
      await expectLater(
        repo.changePassword(_password, 'short'),
        _failure(AuthFailureCode.invalidInput),
      );
      await repo.changePassword(_password, 'NewSecret2026!');
      await repo.logout();
      await expectLater(
        repo.login(_citizen, _password),
        _failure(AuthFailureCode.invalidCredentials),
      );
      await repo.login(_citizen, 'NewSecret2026!');
    });
  });

  group('Profile photo', () {
    test('Rules accept image data URIs only', () {
      expect(ProfilePhotoRules.check(null), isNull);
      expect(ProfilePhotoRules.check(_png), isNull);
      expect(ProfilePhotoRules.check('https://example.com/a.png'), isNotNull);
    });

    test('Photo is saved and can be removed', () async {
      final repo = await open();
      await repo.login(_citizen, _password);
      expect((await repo.updateProfilePhoto(_png)).photo, _png);
      expect((await repo.getCurrentUser())!.photo, _png);
      await repo.updateProfilePhoto(null);
      expect((await repo.getCurrentUser())!.photo, isNull);
      await expectLater(
        repo.updateProfilePhoto('not-an-image'),
        _failure(AuthFailureCode.invalidInput),
      );
    });
  });

  group('Biometric login', () {
    test('Enroll, log out, then log in with biometrics', () async {
      final repo = await open();
      final biometrics = FakeBiometrics();
      final session = AuthSession(repo, biometrics: biometrics);
      addTearDown(session.dispose);
      await session.initialize();

      expect(await session.biometricAccount(), isNull);
      await session.login(_citizen, _password);
      await session.enableBiometrics();
      expect(await session.biometricEnabledForCurrentUser(), isTrue);
      await session.logout();

      expect(await session.biometricAccount(), _citizen);
      expect(await session.loginWithBiometrics(), isTrue);
      expect(session.currentUser?.email, _citizen);
      expect(biometrics.prompts, 2);
    });

    test('A cancelled prompt neither enrolls nor signs in', () async {
      final repo = await open();
      final biometrics = FakeBiometrics(accept: false);
      final session = AuthSession(repo, biometrics: biometrics);
      addTearDown(session.dispose);
      await session.initialize();
      await session.login(_citizen, _password);
      await expectLater(
        session.enableBiometrics(),
        throwsA(isA<AuthFailure>()),
      );
      expect(await repo.biometricAccountEmail(), isNull);

      biometrics.accept = true;
      await session.enableBiometrics();
      await session.logout();
      biometrics.accept = false;
      expect(await session.loginWithBiometrics(), isFalse);
      expect(session.currentUser, isNull);
    });

    test('Not offered without hardware, nor after disabling', () async {
      final repo = await open();
      final biometrics = FakeBiometrics();
      final session = AuthSession(repo, biometrics: biometrics);
      addTearDown(session.dispose);
      await session.initialize();
      await session.login(_citizen, _password);
      await session.enableBiometrics();
      biometrics.available = false;
      expect(await session.biometricAccount(), isNull);
      biometrics.available = true;
      await session.disableBiometrics();
      expect(await session.biometricAccount(), isNull);
      await expectLater(
        repo.loginWithBiometrics(),
        _failure(AuthFailureCode.forbidden),
      );
    });
  });

  group('Security journal', () {
    test('Status changes are journaled; journal is admin-only', () async {
      final repo = await open();
      await repo.login('admin@animora.test', _password);
      await repo.updateUserStatus('demo-pending', AccountStatus.active);
      final events = await repo.listAuthEvents();
      expect(events.first.type, AuthEventType.statusChange);
      expect(events.first.actorId, 'demo-admin');
      expect(events.first.details, 'pending → active');
      await repo.logout();

      await repo.login(_citizen, _password);
      await expectLater(
        repo.listAuthEvents(),
        _failure(AuthFailureCode.forbidden),
      );
    });
  });

  group('SQLite (shared animora.db, schema v8)', () {
    setUpAll(sqfliteFfiInit);

    test('auth_events table, journal, settings and password change', () async {
      final helper = DatabaseHelper(
        factory: databaseFactoryFfi,
        pathOverride: inMemoryDatabasePath,
      );
      final storage = SqliteAuthStorage(
        helper: helper,
        legacy: MemoryAuthStorage(await seedDatabase()),
        vault: MemoryAuthVault(),
      );
      final repo = SqliteAuthRepository(
        storage: storage,
        hasher: const PasswordHasher(iterations: 10000),
        securityStore: SqliteAuthSecurityStore(helper),
      );
      addTearDown(() async {
        repo.dispose();
        await storage.drain();
        await helper.close();
      });
      await repo.initialize();
      final db = await helper.database;
      expect(
        (await db.rawQuery('PRAGMA user_version')).single.values.single,
        9,
      );

      await expectLater(
        repo.login(_citizen, 'wrong-password'),
        _failure(AuthFailureCode.invalidCredentials),
      );
      await repo.login(_citizen, _password);
      await repo.changePassword(_password, 'NewSecret2026!');
      await repo.enableBiometricLogin();
      expect(await repo.biometricAccountEmail(), _citizen);

      final types = [
        for (final row in await db.query('auth_events', orderBy: 'id'))
          row['type'],
      ];
      expect(types, [
        'loginFailure',
        'loginSuccess',
        'passwordChange',
        'biometricEnabled',
      ]);
      // The journal never stores secrets.
      final dump = (await db.query('auth_events')).toString();
      expect(dump.contains(_password), isFalse);
      expect(dump.contains('NewSecret2026!'), isFalse);

      await repo.logout();
      await repo.login(_citizen, 'NewSecret2026!');
    });
  });
}
