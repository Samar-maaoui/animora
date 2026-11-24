import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:animora/features/auth/repositories/local_auth_repository.dart';
import 'package:animora/features/auth/services/local_auth_storage.dart';
import 'package:animora/features/auth/services/auth_snapshot.dart';
import 'package:animora/features/auth/services/password_hasher.dart';
import 'package:animora/features/auth/models/auth_requests.dart';
import 'package:animora/features/auth/state/auth_session.dart';

import 'support/auth_test_support.dart';
import 'auth_repository_test.dart' show registration;

class FaultyAuthStorage implements AuthStorage {
  String? value;
  bool failRead = true;
  int writes = 0;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('not logged secret sentinel');
    return value;
  }

  @override
  Future<void> write(String value) async {
    writes++;
    this.value = value;
  }
}

void main() {
  setUpAll(seedDatabase);
  test(
    'New installation starts without seeded accounts hashing or storage writes',
    () async {
      final storage = FaultyAuthStorage()..failRead = false;
      final repo = LocalAuthRepository(storage: storage);
      final session = AuthSession(repo);
      addTearDown(() {
        session.dispose();
        repo.dispose();
      });
      await session.initialize();
      expect(session.ready, true);
      expect(session.currentUser, isNull);
      expect(storage.writes, 0);
      expect(storage.value, isNull);
    },
  );
  test(
    'Read denied is not treated as an empty account list and can retry',
    () async {
      final storage = FaultyAuthStorage()..value = await seedDatabase();
      final repo = LocalAuthRepository(storage: storage);
      final session = AuthSession(repo);
      addTearDown(() {
        session.dispose();
        repo.dispose();
      });
      final raw = storage.value;
      await session.initialize();
      expect(session.ready, false);
      expect(session.initializationDiagnostic, contains('AUTH_READ'));
      expect(session.initializationDiagnostic, isNot(contains('sentinel')));
      expect(storage.writes, 0);
      expect(storage.value, raw);
      storage.failRead = false;
      await session.retryInitialization();
      expect(session.ready, true);
      expect(storage.value, raw);
    },
  );
  test('Existing valid session and original account document remain unchanged at startup', () async {
    final data = jsonDecode(await seedDatabase()) as Map<String, dynamic>;
    data['sessionId'] = 'demo-citizen';
    final storage = MemoryAuthStorage(jsonEncode(data));
    final raw = storage.value;
    final repo = LocalAuthRepository(storage: storage);
    addTearDown(repo.dispose);
    await repo.initialize();
    expect((await repo.getCurrentUser())!.id, 'demo-citizen');
    expect(storage.value, raw);
  });
  for (final raw in ['{invalid', 'null', '{"version":2,"accounts":[]}']) {
    test(
      'Corruption remains intact with a non-sensitive diagnostic $raw',
      () async {
        final storage = MemoryAuthStorage(raw);
        final repo = LocalAuthRepository(storage: storage);
        addTearDown(repo.dispose);
        await expectLater(
          repo.initialize(),
          throwsA(
            isA<AuthFailure>().having(
              (e) => e.diagnostic,
              'stage',
              contains('AUTH_DECODE_VALIDATE'),
            ),
          ),
        );
        expect(storage.value, raw);
      },
    );
  }
  test(
    'Empty valid document accepts registration with no auto admin',
    () async {
      final storage = MemoryAuthStorage(const AuthSnapshot({}, null).encode());
      final repo = LocalAuthRepository(
        storage: storage,
        hasher: const PasswordHasher(iterations: 10000),
      );
      addTearDown(repo.dispose);
      await repo.initialize();
      await repo.register(registration());
      expect(AuthSnapshot.decode(storage.value!).accounts.length, 1);
      expect(
        AuthSnapshot.decode(storage.value!).accounts.values.single.user.email,
        'new@example.test',
      );
    },
  );
}
