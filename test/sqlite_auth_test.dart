import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:animora/core/database/database_helper.dart';
import 'package:animora/core/database/database_migrations.dart';
import 'package:animora/features/adoption/database/sqlite_catalog_dao.dart';
import 'package:animora/features/auth/services/sqlite_auth_storage.dart';
import 'package:animora/features/auth/services/auth_vault.dart';
import 'package:animora/features/auth/services/password_hasher.dart';
import 'package:animora/features/auth/repositories/sqlite_auth_repository.dart';
import 'package:animora/features/auth/models/auth_requests.dart';
import 'package:animora/core/enums/account_status.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';

import 'support/auth_test_support.dart';
import 'auth_repository_test.dart' show registration;

class NativeAuthHarness {
  NativeAuthHarness(this.legacy, {MemoryAuthVault? vault, String? file})
    : vault = vault ?? MemoryAuthVault(),
      helper = DatabaseHelper(
        factory: databaseFactoryFfi,
        pathOverride: file ?? inMemoryDatabasePath,
      ) {
    storage = SqliteAuthStorage(
      helper: helper,
      legacy: legacy,
      vault: this.vault,
    );
    repo = SqliteAuthRepository(
      storage: storage,
      hasher: const PasswordHasher(iterations: 10000),
    );
  }
  final MemoryAuthStorage legacy;
  final MemoryAuthVault vault;
  final DatabaseHelper helper;
  late final SqliteAuthStorage storage;
  late final SqliteAuthRepository repo;
  Future<void> close() async {
    repo.dispose();
    await storage.drain();
    await helper.close();
  }
}

void main() {
  test('Profile failure rolls back user and account revision', () async {
    final h = NativeAuthHarness(MemoryAuthStorage(await seedDatabase()));
    addTearDown(h.close);
    await h.repo.login('citizen@animora.test', DemoAccounts.password);
    final db = await h.helper.database;
    final before = (await db.query(
      'auth_accounts',
      where: 'userId=?',
      whereArgs: ['demo-citizen'],
    )).single;
    await db.execute(
      "CREATE TRIGGER fail_profile BEFORE UPDATE ON users BEGIN SELECT RAISE(ABORT,'forced'); END",
    );
    await expectLater(
      h.repo.updateProfile(
        const ProfileUpdate(
          firstName: 'Changed',
          lastName: 'Nom',
          phone: '+21620123456',
          city: 'Sfax',
        ),
      ),
      throwsA(isA<AuthFailure>()),
    );
    expect((await h.repo.getCurrentUser())!.firstName, 'Amine');
    expect(
      (await db.query(
        'auth_accounts',
        where: 'userId=?',
        whereArgs: ['demo-citizen'],
      )).single,
      before,
    );
    await db.execute('DROP TRIGGER fail_profile');
  });
  test(
    'Concurrent stale account document cannot overwrite a newer SQL commit',
    () async {
      final h = NativeAuthHarness(MemoryAuthStorage(await seedDatabase()));
      addTearDown(h.close);
      final old = await h.storage.read();
      final second = SqliteAuthStorage(
        helper: h.helper,
        legacy: h.legacy,
        vault: h.vault,
      );
      await second.read();
      await h.repo.login('citizen@animora.test', DemoAccounts.password);
      await expectLater(
        second.write(old!),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.diagnostic,
            'concurrent',
            'AUTH_SQL_CONCURRENT',
          ),
        ),
      );
      expect((await h.repo.getCurrentUser())!.id, 'demo-citizen');
    },
  );

  setUpAll(() async {
    sqfliteFfiInit();
    await seedDatabase();
  });
  test('Native fresh install is empty registration uses users and secure credentials', () async {
    final h = NativeAuthHarness(MemoryAuthStorage());
    addTearDown(h.close);
    await h.repo.initialize();
    expect(await h.repo.getCurrentUser(), isNull);
    final sql = await h.helper.database;
    expect(await sql.query('users'), isEmpty);
    final u = await h.repo.register(registration());
    expect((await sql.query('users')).single['id'], u.id);
    expect((await sql.query('auth_accounts')).single['userId'], u.id);
    expect(h.legacy.value, isNull);
    final tables = await sql.rawQuery('PRAGMA table_info(auth_accounts)');
    expect(tables.map((r) => r['name']), isNot(contains('password')));
    expect(tables.map((r) => r['name']), isNot(contains('sessionId')));
    await h.repo.login(u.email, 'Secret2026!');
    expect((await h.repo.getCurrentUser())!.id, u.id);
    expect(await sql.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
  test(
    'SharedPreferences import preserves IDs hashes session and source once',
    () async {
      final source = jsonDecode(await seedDatabase()) as Map<String, dynamic>;
      source['sessionId'] = 'demo-citizen';
      final legacy = MemoryAuthStorage(jsonEncode(source));
      final h = NativeAuthHarness(legacy);
      addTearDown(h.close);
      final raw = legacy.value;
      await h.repo.initialize();
      expect((await h.repo.getCurrentUser())!.id, 'demo-citizen');
      expect(
        (await (await h.helper.database).query('auth_accounts')).length,
        7,
      );
      expect(legacy.value, raw);
      await h.repo.initialize();
      expect((await (await h.helper.database).query('users')).length, 7);
      await h.repo.login('citizen@animora.test', DemoAccounts.password);
      expect(h.vault.values.values.any((v) => v.contains('"hash"')), true);
      expect(
        h.vault.values.values.any((v) => v.contains(DemoAccounts.password)),
        false,
      );
    },
  );
  test(
    'Native profile status role checks and invalid login preserve rules',
    () async {
      final h = NativeAuthHarness(MemoryAuthStorage(await seedDatabase()));
      addTearDown(h.close);
      await h.repo.initialize();
      await expectLater(
        h.repo.login('citizen@animora.test', 'wrong'),
        throwsA(isA<AuthFailure>()),
      );
      await h.repo.login('citizen@animora.test', DemoAccounts.password);
      await expectLater(h.repo.listUsers(), throwsA(isA<AuthFailure>()));
      await h.repo.updateProfile(
        const ProfileUpdate(
          firstName: 'Nouveau',
          lastName: 'Nom',
          phone: '+21620123456',
          city: 'Sfax',
        ),
      );
      expect(
        (await (await h.helper.database).query(
          'users',
          where: 'id=?',
          whereArgs: ['demo-citizen'],
        )).single['firstName'],
        'Nouveau',
      );
      await h.repo.login('admin@animora.test', DemoAccounts.password);
      await h.repo.updateUserStatus('demo-veterinarian', AccountStatus.blocked);
      await h.repo.login('veterinarian@animora.test', DemoAccounts.password);
      expect((await h.repo.getCurrentUser())!.status, AccountStatus.blocked);
      await expectLater(
        h.repo.listServiceProviders(),
        throwsA(isA<AuthFailure>()),
      );
    },
  );
  test('Normalized SQL email uniqueness and foreign key rejection', () async {
    final h = NativeAuthHarness(MemoryAuthStorage(await seedDatabase()));
    addTearDown(h.close);
    await h.repo.initialize();
    final db = await h.helper.database;
    final row = (await db.query('users')).first;
    await expectLater(
      db.insert('users', {
        ...row,
        'id': 'different',
        'email': ' ${(row['email'] as String).toUpperCase()} ',
      }),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.insert('auth_accounts', {
        'userId': 'missing',
        'credentialRef': 'nonsecret-reference',
        'revision': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
  test('SQL migration failure rolls back all accounts and resumes without duplicates', () async {
    final legacy = MemoryAuthStorage(await seedDatabase());
    final raw = legacy.value;
    final h = NativeAuthHarness(legacy);
    addTearDown(h.close);
    final db = await h.helper.database;
    await db.execute(
      "CREATE TRIGGER fail_auth BEFORE INSERT ON auth_accounts WHEN NEW.userId='demo-admin' BEGIN SELECT RAISE(ABORT,'forced'); END",
    );
    await expectLater(h.repo.initialize(), throwsA(isA<AuthFailure>()));
    expect(await db.query('users'), isEmpty);
    expect(await db.query('auth_accounts'), isEmpty);
    expect(
      await SqliteCatalogDao().metadata(db, SqliteAuthStorage.marker),
      isNull,
    );
    expect(legacy.value, raw);
    await db.execute('DROP TRIGGER fail_auth');
    await h.repo.initialize();
    await h.repo.initialize();
    expect((await db.query('auth_accounts')).length, 7);
    expect(legacy.value, raw);
  });
  test(
    'Secure storage failure never validates migration and can retry',
    () async {
      final vault = MemoryAuthVault()..failWrites = true;
      final legacy = MemoryAuthStorage(await seedDatabase());
      final h = NativeAuthHarness(legacy, vault: vault);
      addTearDown(h.close);
      final raw = legacy.value;
      await expectLater(h.repo.initialize(), throwsA(isA<AuthFailure>()));
      expect(await (await h.helper.database).query('auth_accounts'), isEmpty);
      vault.failWrites = false;
      await h.repo.initialize();
      expect(legacy.value, raw);
    },
  );
  test('Migration from v6 keeps existing user rows and references', () async {
    final dir = await Directory.systemTemp.createTemp('animora-auth-v6-');
    final file = dir.uri.resolve('animora.db').toFilePath();
    final legacy = MemoryAuthStorage(await seedDatabase());
    final source = jsonDecode(legacy.value!) as Map<String, dynamic>;
    final old = await databaseFactoryFfi.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 6,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, v) => DatabaseMigrations.upgrade(db, 0, 6),
      ),
    );
    for (final a in source['accounts'] as List) {
      await old.insert('users', Map<String, Object?>.from(a['user'] as Map));
    }
    await old.execute(
      "INSERT INTO reports (id,userId,type,description,urgencyLevel,status,createdAt,photo,latitude,longitude) VALUES (1,'demo-citizen','STRAY_ANIMAL','Observation préservée',1,'NEW','2026-11-10',NULL,NULL,NULL)",
    );
    await old.close();
    final h = NativeAuthHarness(legacy, file: file);
    addTearDown(h.close);
    await h.repo.initialize();
    final db = await h.helper.database;
    expect((await db.rawQuery('PRAGMA user_version')).single.values.single, 9);
    expect((await db.query('reports')).single['userId'], 'demo-citizen');
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect((await db.query('users')).length, 7);
  });
  test(
    'Conflicting business profile is preserved and migration fails closed',
    () async {
      final h = NativeAuthHarness(MemoryAuthStorage(await seedDatabase()));
      addTearDown(h.close);
      final db = await h.helper.database;
      final row =
          (jsonDecode(h.legacy.value!)['accounts'] as List).first['user']
              as Map;
      await db.insert('users', {
        ...Map<String, Object?>.from(row),
        'firstName': 'Version SQL conservée',
      });
      await expectLater(
        h.repo.initialize(),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.diagnostic,
            'conflict',
            'AUTH_SQL_PROFILE_CONFLICT',
          ),
        ),
      );
      expect(
        (await db.query('users')).single['firstName'],
        'Version SQL conservée',
      );
      expect(await db.query('auth_accounts'), isEmpty);
    },
  );
  test(
    'Database reopen restores valid vault session without rereading old source',
    () async {
      final dir = await Directory.systemTemp.createTemp('animora-auth-reopen-');
      final file = dir.uri.resolve('animora.db').toFilePath();
      final vault = MemoryAuthVault();
      final h = NativeAuthHarness(
        MemoryAuthStorage(await seedDatabase()),
        vault: vault,
        file: file,
      );
      await h.repo.login('citizen@animora.test', DemoAccounts.password);
      await h.close();
      final reopened = NativeAuthHarness(
        MemoryAuthStorage('invalid old source must not be read'),
        vault: vault,
        file: file,
      );
      addTearDown(reopened.close);
      await reopened.repo.initialize();
      expect((await reopened.repo.getCurrentUser())!.id, 'demo-citizen');
      expect(
        (await (await reopened.helper.database).query('auth_accounts')).length,
        7,
      );
    },
  );
  test('Failed login SQL commit preserves published secure session', () async {
    final h = NativeAuthHarness(MemoryAuthStorage(await seedDatabase()));
    addTearDown(h.close);
    await h.repo.initialize();
    final db = await h.helper.database;
    final dao = SqliteCatalogDao();
    final state = await dao.metadata(db, SqliteAuthStorage.stateKey);
    await db.execute(
      "CREATE TRIGGER fail_state BEFORE UPDATE ON database_metadata WHEN NEW.key='auth_state_v1' BEGIN SELECT RAISE(ABORT,'forced'); END",
    );
    await expectLater(
      h.repo.login('citizen@animora.test', DemoAccounts.password),
      throwsA(isA<AuthFailure>()),
    );
    expect(await dao.metadata(db, SqliteAuthStorage.stateKey), state);
    expect(await h.repo.getCurrentUser(), isNull);
    await db.execute('DROP TRIGGER fail_state');
    await h.repo.login('citizen@animora.test', DemoAccounts.password);
    expect((await h.repo.getCurrentUser())!.id, 'demo-citizen');
  });
  test('Legacy module synchronization cannot overwrite authoritative auth profiles', () async {
    final h = NativeAuthHarness(MemoryAuthStorage(await seedDatabase()));
    addTearDown(h.close);
    await h.repo.login('citizen@animora.test', DemoAccounts.password);
    await h.repo.updateProfile(
      const ProfileUpdate(
        firstName: 'SQL actuel',
        lastName: 'Nom',
        phone: '+21620123456',
        city: 'Sfax',
      ),
    );
    await SqliteCatalogDao().syncUsers(
      await h.helper.database,
      DemoAccounts.users,
    );
    expect((await h.repo.getCurrentUser())!.firstName, 'SQL actuel');
  });
  for (final kind in ['duplicateId', 'duplicateEmail', 'digest']) {
    test('Invalid migration $kind preserves raw source', () async {
      final source = jsonDecode(await seedDatabase()) as Map<String, dynamic>;
      final rows = source['accounts'] as List;
      if (kind == 'duplicateId') {
        rows.add(rows.first);
      } else if (kind == 'duplicateEmail') {
        rows[1]['user']['email'] = rows[0]['user']['email'];
      } else {
        rows[0]['credential']['hash'] = 'invalid';
      }
      final legacy = MemoryAuthStorage(jsonEncode(source));
      final raw = legacy.value;
      final h = NativeAuthHarness(legacy);
      addTearDown(h.close);
      await expectLater(h.repo.initialize(), throwsA(isA<AuthFailure>()));
      expect(legacy.value, raw);
      expect(await (await h.helper.database).query('auth_accounts'), isEmpty);
    });
  }
}
