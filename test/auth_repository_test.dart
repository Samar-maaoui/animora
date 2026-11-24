import 'package:animora/features/auth/repositories/local_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animora/core/enums/account_status.dart';
import 'package:animora/core/enums/user_profile.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/auth/models/auth_requests.dart';
import 'package:animora/features/auth/services/account_policy.dart';
import 'package:animora/features/auth/services/password_hasher.dart';
import 'package:animora/features/auth/state/auth_session.dart';
import 'package:animora/features/users/models/user.dart';

import 'support/auth_test_support.dart';

RegisterRequest registration({
  String email = 'new@example.test',
  UserProfile profile = UserProfile.citizen,
  String phone = '+216 20 333 444',
  String password = 'Secret2026!',
  String? professionalCardNumber,
}) => RegisterRequest(
  firstName: 'Test',
  lastName: 'Utilisateur',
  email: email,
  phone: phone,
  city: 'Tunis',
  password: password,
  profile: profile,
  professionalCardNumber:
      professionalCardNumber ??
      (profile == UserProfile.veterinarian ? 'VET-2026-0042' : null),
);

void main() {
  setUpAll(seedDatabase);
  test(
    'All five profiles use one serializable User model without credentials',
    () {
      for (final user in DemoAccounts.users) {
        final json = user.toJson();
        expect(json.containsKey('password'), isFalse);
        final copy = User.fromJson(json);
        expect(copy.profile, user.profile);
        expect(copy.status, user.status);
        expect(copy.fullName, user.fullName);
      }
    },
  );
  test('Password derivation is salted and verifies exact passwords', () async {
    const hasher = PasswordHasher(iterations: 10000);
    final first = await hasher.hash('Secret2026!');
    final second = await hasher.hash('Secret2026!');
    expect(first.salt, isNot(second.salt));
    expect(first.hash, isNot(second.hash));
    expect(await hasher.verify('Secret2026!', first), isTrue);
    expect(await hasher.verify('incorrect', first), isFalse);
  });
  test(
    'Valid login normalizes email, invalid credentials leave no session',
    () async {
      final repo = await testRepository();
      addTearDown(repo.dispose);
      await expectLater(
        repo.login('citizen@animora.test', 'wrong'),
        throwsA(isA<AuthFailure>()),
      );
      await expectLater(
        repo.login('absent@animora.test', DemoAccounts.password),
        throwsA(isA<AuthFailure>()),
      );
      expect(await repo.getCurrentUser(), isNull);
      final user = await repo.login(
        ' CITIZEN@ANIMORA.TEST ',
        DemoAccounts.password,
      );
      expect(user.status, AccountStatus.active);
      expect((await repo.getCurrentUser())?.id, user.id);
      await repo.logout();
      expect(await repo.getCurrentUser(), isNull);
    },
  );
  test('Professional public registrations are pending, citizen is active; no auto-login', () async {
    final repo = await testRepository();
    addTearDown(repo.dispose);
    for (final profile in AccountPolicy.publicProfiles) {
      final user = await repo.register(
        registration(email: '${profile.name}@example.test', profile: profile),
      );
      expect(
        user.status,
        profile == UserProfile.citizen
            ? AccountStatus.active
            : AccountStatus.pending,
      );
    }
    expect(await repo.getCurrentUser(), isNull);
    await expectLater(
      repo.register(registration(profile: UserProfile.admin)),
      throwsA(isA<AuthFailure>()),
    );
  });
  test('Duplicate emails including case and whitespace are rejected', () async {
    final repo = await testRepository();
    addTearDown(repo.dispose);
    await repo.register(registration());
    await expectLater(
      repo.register(registration(email: ' NEW@EXAMPLE.TEST ')),
      throwsA(
        isA<AuthFailure>().having(
          (e) => e.code,
          'code',
          AuthFailureCode.duplicateEmail,
        ),
      ),
    );
  });
  test('Repository also rejects malformed input outside the UI', () async {
    final repo = await testRepository();
    addTearDown(repo.dispose);
    for (final request in [
      registration(email: 'bad'),
      registration(phone: '12x'),
      registration(password: 'short'),
    ]) {
      await expectLater(repo.register(request), throwsA(isA<AuthFailure>()));
    }
  });
  test('Session, registration, profile updates and salted credentials survive reload', () async {
    final storage = MemoryAuthStorage(await seedDatabase());
    final repo = await testRepository(storage: storage);
    final user = await repo.register(registration());
    await repo.login(user.email, 'Secret2026!');
    await repo.updateProfile(
      const ProfileUpdate(
        firstName: 'Nouveau',
        lastName: 'Nom',
        phone: '+216 22 333 444',
        city: 'Sousse',
      ),
    );
    expect(storage.value, isNot(contains('Secret2026!')));
    expect(storage.value, isNot(contains(DemoAccounts.password)));
    repo.dispose();
    final restored = await testRepository(storage: storage);
    addTearDown(restored.dispose);
    final current = (await restored.getCurrentUser())!;
    expect(current.firstName, 'Nouveau');
    expect(current.city, 'Sousse');
    expect(current.email, user.email);
    expect(current.profile, UserProfile.citizen);
    expect(current.createdAt, user.createdAt);
    await restored.logout();
    final afterLogout = await testRepository(storage: storage);
    addTearDown(afterLogout.dispose);
    expect(await afterLogout.getCurrentUser(), isNull);
    expect((await afterLogout.login(user.email, 'Secret2026!')).city, 'Sousse');
  });
  test(
    'Admin validates, blocks and reactivates; changes affect subsequent login',
    () async {
      final repo = await testRepository();
      addTearDown(repo.dispose);
      await repo.login('admin@animora.test', DemoAccounts.password);
      expect((await repo.listUsers()).length, 7);
      await repo.updateUserStatus('demo-pending', AccountStatus.active);
      await repo.logout();
      expect(
        (await repo.login(
          'pending@animora.test',
          DemoAccounts.password,
        )).status,
        AccountStatus.active,
      );
      await repo.logout();
      await repo.login('admin@animora.test', DemoAccounts.password);
      await repo.updateUserStatus('demo-citizen', AccountStatus.blocked);
      await repo.logout();
      expect(
        (await repo.login(
          'citizen@animora.test',
          DemoAccounts.password,
        )).status,
        AccountStatus.blocked,
      );
      await expectLater(
        repo.updateProfile(
          const ProfileUpdate(
            firstName: 'A',
            lastName: 'B',
            phone: '20123456',
            city: 'Tunis',
          ),
        ),
        throwsA(isA<AuthFailure>()),
      );
      await repo.logout();
      await repo.login('admin@animora.test', DemoAccounts.password);
      await repo.updateUserStatus('demo-citizen', AccountStatus.active);
      await repo.logout();
      expect(
        (await repo.login(
          'citizen@animora.test',
          DemoAccounts.password,
        )).status,
        AccountStatus.active,
      );
    },
  );
  test(
    'Admin actions require an active admin and cannot block the current admin',
    () async {
      final repo = await testRepository();
      addTearDown(repo.dispose);
      await expectLater(repo.listUsers(), throwsA(isA<AuthFailure>()));
      await repo.login('citizen@animora.test', DemoAccounts.password);
      await expectLater(repo.listUsers(), throwsA(isA<AuthFailure>()));
      await expectLater(
        repo.updateUserStatus('demo-pending', AccountStatus.active),
        throwsA(isA<AuthFailure>()),
      );
      await repo.logout();
      await repo.login('admin@animora.test', DemoAccounts.password);
      await expectLater(
        repo.updateUserStatus('demo-admin', AccountStatus.blocked),
        throwsA(isA<AuthFailure>()),
      );
      await expectLater(
        repo.updateUserStatus('demo-pending', AccountStatus.blocked),
        throwsA(isA<AuthFailure>()),
      );
    },
  );
  test(
    'Failed persistence leaves the previous session and profile intact',
    () async {
      final storage = MemoryAuthStorage(await seedDatabase());
      final repo = await testRepository(storage: storage);
      addTearDown(repo.dispose);
      await repo.login('citizen@animora.test', DemoAccounts.password);
      final before = storage.value;
      storage.failWrites = true;
      await expectLater(
        repo.updateProfile(
          const ProfileUpdate(
            firstName: 'Changed',
            lastName: 'B',
            phone: '20123456',
            city: 'Tunis',
          ),
        ),
        throwsA(isA<AuthFailure>()),
      );
      await expectLater(repo.logout(), throwsA(isA<AuthFailure>()));
      expect((await repo.getCurrentUser())?.firstName, 'Amine');
      expect(storage.value, before);
    },
  );
  test(
    'Corrupt storage is reported without overwriting the database',
    () async {
      final storage = MemoryAuthStorage('{broken');
      await expectLater(
        testRepository(storage: storage),
        throwsA(isA<AuthFailure>()),
      );
      expect(storage.value, '{broken');
    },
  );
  test(
    'Session initialization failure can be retried after storage repair',
    () async {
      final storage = MemoryAuthStorage('{broken');
      final repo = LocalAuthRepository(storage: storage);
      final session = AuthSession(repo);
      addTearDown(() {
        session.dispose();
        repo.dispose();
      });
      await session.initialize();
      expect(session.ready, isFalse);
      expect(session.initializationError, isNotNull);
      expect(storage.value, '{broken');
      storage.value = await seedDatabase();
      await session.retryInitialization();
      expect(session.ready, isTrue);
    },
  );
  test('Public professional directory excludes inactive profiles and private contacts', () async {
    final repo = await testRepository();
    addTearDown(repo.dispose);
    await repo.login('citizen@animora.test', DemoAccounts.password);
    var users = await repo.listServiceProviders();
    expect(users.map((u) => u.id).toSet(), {
      'demo-veterinarian',
      'demo-pet-sitter',
    });
    expect(users.every((u) => u.email.isEmpty && u.phone == null), isTrue);
    await expectLater(repo.listUsers(), throwsA(isA<AuthFailure>()));
    await repo.login('admin@animora.test', DemoAccounts.password);
    await repo.updateUserStatus('demo-veterinarian', AccountStatus.blocked);
    await repo.login('citizen@animora.test', DemoAccounts.password);
    users = await repo.listServiceProviders();
    expect(users.map((u) => u.id), ['demo-pet-sitter']);
    await repo.logout();
    await expectLater(repo.listServiceProviders(), throwsA(isA<AuthFailure>()));
  });
}
