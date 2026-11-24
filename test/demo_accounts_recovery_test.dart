import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:animora/core/enums/account_status.dart';
import 'package:animora/core/enums/user_profile.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/auth/data/demo_recovery.dart';
import 'package:animora/features/auth/models/auth_requests.dart';
import 'package:animora/features/auth/repositories/local_auth_repository.dart';
import 'package:animora/features/auth/repositories/sqlite_auth_repository.dart';
import 'package:animora/features/auth/services/auth_snapshot.dart';
import 'package:animora/features/auth/services/password_hasher.dart';
import 'package:animora/features/adoption/database/sqlite_catalog_dao.dart';
import 'package:animora/features/users/models/user.dart';

import 'support/auth_test_support.dart';
import 'sqlite_auth_test.dart' show NativeAuthHarness;
import 'auth_repository_test.dart' show registration;

void main() {
  setUpAll(sqfliteFfiInit);
  const hasher = PasswordHasher(iterations: 10000);
  LocalAuthRepository recover(MemoryAuthStorage storage) {
    final repo = LocalAuthRepository(
      storage: storage,
      hasher: hasher,
      recoverDemoAccounts: true,
    );
    addTearDown(repo.dispose);
    return repo;
  }

  test('Explicit recovery is idempotent and preserves all digest bytes and session', () async {
    final storage = MemoryAuthStorage();
    final repo = recover(storage);
    await repo.initialize();
    expect(repo.demoRecoveryResult!.created.length, 8);
    final first = AuthSnapshot.decode(storage.value!);
    expect(
      first.accounts.keys.toSet(),
      DemoRecovery.users.map((u) => u.id).toSet(),
    );
    await repo.login('citizen@animora.test', DemoAccounts.password);
    final before = storage.value;
    await repo.initialize();
    expect(storage.value, before);
    expect(repo.demoRecoveryResult!.created, isEmpty);
    expect(repo.demoRecoveryResult!.preserved.length, 8);
    expect((await repo.getCurrentUser())!.id, 'demo-citizen');
    final reopened = recover(storage);
    await reopened.initialize();
    expect(storage.value, before);
    expect((await reopened.getCurrentUser())!.id, 'demo-citizen');
  });

  for (final template in DemoRecovery.users) {
    test(
      'Recovered ${template.id} preserves role status and access restrictions',
      () async {
        final repo = recover(MemoryAuthStorage());
        await repo.initialize();
        final user = await repo.login(template.email, DemoAccounts.password);
        expect(user.id, template.id);
        expect(user.profile, template.profile);
        expect(user.status, template.status);
        if (user.status != AccountStatus.active) {
          await expectLater(
            repo.listServiceProviders(),
            throwsA(
              isA<AuthFailure>().having(
                (e) => e.code,
                'access',
                AuthFailureCode.forbidden,
              ),
            ),
          );
        } else if (user.profile == UserProfile.admin) {
          expect((await repo.listUsers()).length, 8);
        } else {
          await expectLater(
            repo.listUsers(),
            throwsA(
              isA<AuthFailure>().having(
                (e) => e.code,
                'admin access',
                AuthFailureCode.forbidden,
              ),
            ),
          );
        }
      },
    );
  }

  test('Existing identity personal data status and custom password are never reset', () async {
    final original = DemoAccounts.users.first;
    final user = User(
      id: 'legacy-citizen-id',
      firstName: 'Existing',
      lastName: 'Owner',
      email: ' CITIZEN@ANIMORA.TEST ',
      city: 'Existing city',
      profile: UserProfile.citizen,
      status: AccountStatus.blocked,
      createdAt: original.createdAt,
    );
    final digest = await hasher.hash('Different2026!');
    final storage = MemoryAuthStorage(
      AuthSnapshot({user.id: AuthAccount(user, digest)}, user.id).encode(),
    );
    final repo = recover(storage);
    await repo.initialize();
    final snapshot = AuthSnapshot.decode(storage.value!);
    expect(
      snapshot.accounts[user.id]!.toJson(),
      AuthAccount(user, digest).toJson(),
    );
    expect(snapshot.sessionId, user.id);
    expect(snapshot.accounts.containsKey('demo-citizen'), false);
    expect(repo.demoRecoveryResult!.passwordMismatches, [user.id]);
    expect(
      (await repo.login('citizen@animora.test', 'Different2026!')).id,
      user.id,
    );
    await expectLater(
      repo.login('citizen@animora.test', DemoAccounts.password),
      throwsA(isA<AuthFailure>()),
    );
  });

  test(
    'Real account and occupied demo ID are kept without creating a duplicate',
    () async {
      final storage = MemoryAuthStorage();
      final regular = LocalAuthRepository(
        storage: storage,
        hasher: hasher,
        generateId: () => 'demo-citizen',
      );
      addTearDown(regular.dispose);
      await regular.register(registration(email: 'real@example.test'));
      final old = AuthSnapshot.decode(storage.value!).accounts['demo-citizen']!
          .toJson();
      final repo = recover(storage);
      await repo.initialize();
      expect(repo.demoRecoveryResult!.conflicts, ['demo-citizen']);
      expect(
        AuthSnapshot.decode(storage.value!).accounts['demo-citizen']!.toJson(),
        old,
      );
    },
  );

  test(
    'Recovery write failure publishes no partial seed and can retry',
    () async {
      final storage = MemoryAuthStorage()..failWrites = true;
      final repo = recover(storage);
      await expectLater(repo.initialize(), throwsA(isA<AuthFailure>()));
      expect(storage.value, isNull);
      storage.failWrites = false;
      await repo.initialize();
      expect(AuthSnapshot.decode(storage.value!).accounts.length, 8);
    },
  );

  test('Default startup does not seed and release or profile policy always refuses', () async {
    final storage = MemoryAuthStorage();
    final repo = LocalAuthRepository(storage: storage);
    addTearDown(repo.dispose);
    await repo.initialize();
    expect(storage.value, isNull);
    expect(repo.demoRecoveryResult, isNull);
    expect(DemoRecovery.permitted(requested: true, debugBuild: false), false);
    expect(DemoRecovery.permitted(requested: false, debugBuild: true), false);
    expect(DemoRecovery.enabled, false);
  });

  test('SQLite recovery attaches credentials to existing profile without changing ID or FK', () async {
    final h = NativeAuthHarness(MemoryAuthStorage());
    addTearDown(h.close);
    await h.storage.read();
    final db = await h.helper.database;
    final old = DemoAccounts.users.first;
    final profile = User(
      id: 'previous-citizen',
      firstName: 'Original',
      lastName: old.lastName,
      email: old.email,
      city: 'Original city',
      profile: old.profile,
      status: AccountStatus.blocked,
      createdAt: old.createdAt,
    );
    await SqliteCatalogDao().upsert(db, 'users', profile.toJson());
    await db.insert('reports', {
      'id': 1,
      'userId': profile.id,
      'type': 'OTHER',
      'description': 'Existing report',
      'urgencyLevel': 1,
      'status': 'NEW',
      'createdAt': old.createdAt.toIso8601String(),
    });
    final repo = SqliteAuthRepository(
      storage: h.storage,
      hasher: hasher,
      recoverDemoAccounts: true,
    );
    addTearDown(repo.dispose);
    await repo.initialize();
    expect(
      (await repo.login(profile.email, DemoAccounts.password)).id,
      profile.id,
    );
    expect((await repo.getCurrentUser())!.toJson(), profile.toJson());
    expect((await db.query('reports')).single['userId'], profile.id);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    final rows = jsonEncode(await db.query('auth_accounts'));
    await repo.initialize();
    expect(jsonEncode(await db.query('auth_accounts')), rows);
    expect((await db.query('auth_accounts')).length, 8);
    expect(h.legacy.value, isNull);
  });

  test(
    'SQLite seed SQL failure rolls back credentials and profiles and retries',
    () async {
      final h = NativeAuthHarness(MemoryAuthStorage());
      addTearDown(h.close);
      await h.storage.read();
      final db = await h.helper.database;
      await db.execute(
        "CREATE TRIGGER reject_seed BEFORE INSERT ON auth_accounts BEGIN SELECT RAISE(ABORT,'forced'); END",
      );
      final repo = SqliteAuthRepository(
        storage: h.storage,
        hasher: hasher,
        recoverDemoAccounts: true,
      );
      addTearDown(repo.dispose);
      await expectLater(repo.initialize(), throwsA(isA<AuthFailure>()));
      expect(await db.query('auth_accounts'), isEmpty);
      expect(await db.query('users'), isEmpty);
      await db.execute('DROP TRIGGER reject_seed');
      await repo.initialize();
      expect((await db.query('auth_accounts')).length, 8);
    },
  );
}
