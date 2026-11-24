import 'package:animora/core/database/database_helper.dart';
import 'package:animora/core/enums/account_status.dart';
import 'package:animora/features/admin/screens/admin_security_log_screen.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/auth/models/auth_event.dart';
import 'package:animora/features/auth/models/auth_requests.dart';
import 'package:animora/features/auth/repositories/sqlite_auth_repository.dart';
import 'package:animora/features/auth/services/auth_vault.dart';
import 'package:animora/features/auth/services/password_hasher.dart';
import 'package:animora/features/auth/services/sqlite_auth_security_store.dart';
import 'package:animora/features/auth/services/sqlite_auth_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/auth_test_support.dart';

typedef _Harness = ({
  SqliteAuthRepository repo,
  DatabaseHelper helper,
  MemoryAuthVault vault,
});

Future<_Harness> _harness() async {
  final helper = DatabaseHelper(
    factory: databaseFactoryFfi,
    pathOverride: inMemoryDatabasePath,
  );
  final vault = MemoryAuthVault();
  final storage = SqliteAuthStorage(
    helper: helper,
    legacy: MemoryAuthStorage(await seedDatabase()),
    vault: vault,
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
  await repo.login('admin@animora.test', DemoAccounts.password);
  return (repo: repo, helper: helper, vault: vault);
}

Matcher _failure(String part) => throwsA(
  isA<AuthFailure>().having((e) => e.message, 'message', contains(part)),
);

void main() {
  setUpAll(sqfliteFfiInit);
  setUpAll(seedDatabase);

  test('Refusing a pending registration deletes the account', () async {
    final h = await _harness();
    final db = await h.helper.database;
    final credentialRef =
        (await db.query(
              'auth_accounts',
              where: 'userId=?',
              whereArgs: ['demo-pending'],
            )).single['credentialRef']
            as String;

    await h.repo.deleteUser('demo-pending', rejection: true);

    expect(
      (await h.repo.listUsers()).any((u) => u.id == 'demo-pending'),
      isFalse,
    );
    expect(
      await db.query('users', where: 'id=?', whereArgs: ['demo-pending']),
      isEmpty,
    );
    expect(
      await db.query(
        'auth_accounts',
        where: 'userId=?',
        whereArgs: ['demo-pending'],
      ),
      isEmpty,
    );
    // The password hash is wiped from the secure vault.
    expect(h.vault.values[credentialRef], isEmpty);
    // The person can no longer sign in.
    await h.repo.logout();
    await expectLater(
      h.repo.login('pending@animora.test', DemoAccounts.password),
      throwsA(isA<AuthFailure>()),
    );
    // Journal: who, what, by whom.
    await h.repo.login('admin@animora.test', DemoAccounts.password);
    final event = (await h.repo.listAuthEvents()).firstWhere(
      (e) => e.type == AuthEventType.accountRejected,
    );
    expect(event.email, 'pending@animora.test');
    expect(event.actorId, 'demo-admin');
    expect(event.details, contains('pending'));
    expect(SecurityLogFilter.admin.accepts(event.type), isTrue);
  });

  test('Only a pending account can be « refused »', () async {
    final h = await _harness();
    await expectLater(
      h.repo.deleteUser('demo-citizen', rejection: true),
      _failure('en attente'),
    );
  });

  test('An existing account without history can be deleted', () async {
    final h = await _harness();
    await h.repo.deleteUser('demo-blocked');
    expect(
      (await h.repo.listUsers()).map((u) => u.id),
      isNot(contains('demo-blocked')),
    );
    final events = await h.repo.listAuthEvents();
    expect(events.first.type, AuthEventType.accountDeleted);
    expect(events.first.details, contains('blocked'));
  });

  test('An account with history is NOT deleted (block it instead)', () async {
    final h = await _harness();
    final db = await h.helper.database;
    await db.insert('animals', {
      'id': 9001,
      'name': 'Luna',
      'species': 'Chat',
      'breed': 'Européen',
      'sex': 'Femelle',
      'age': 2,
      'weight': 3.5,
      'color': 'Noir',
      'sterilized': 1,
      'health': 'Bonne',
      'character': 'Calme',
      'microchipNumber': '250000000000001',
      'animalPhoto': 'assets/images/animals/cat.jpg',
      'status': 'AVAILABLE',
      'arrivalDate': '2026-01-01',
      'city': 'Tunis',
    });
    await db.insert('adoptions', {
      'id': 9001,
      'userId': 'demo-citizen',
      'animalId': 9001,
      'applicationDate': '2026-02-01',
      'motivation': 'Test',
      'compatibilityScore': 80,
      'status': 'PENDING',
      'applicantSnapshot': '{}',
    });
    await expectLater(
      h.repo.deleteUser('demo-citizen'),
      _failure('historique'),
    );
    // Rolled back: the account still exists and still works.
    expect(
      (await h.repo.listUsers()).any((u) => u.id == 'demo-citizen'),
      isTrue,
    );
    await h.repo.updateUserStatus('demo-citizen', AccountStatus.blocked);
  });

  test('Admins and one’s own account cannot be deleted', () async {
    final h = await _harness();
    await expectLater(h.repo.deleteUser('demo-admin'), _failure('propre'));
  });
}
