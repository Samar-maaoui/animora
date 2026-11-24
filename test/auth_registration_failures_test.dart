import 'package:flutter_test/flutter_test.dart';
import 'package:animora/features/auth/models/auth_requests.dart';
import 'package:animora/features/auth/repositories/local_auth_repository.dart';
import 'package:animora/features/auth/services/auth_snapshot.dart';
import 'package:animora/features/auth/services/password_hasher.dart';

import 'auth_repository_test.dart' show registration;
import 'support/auth_test_support.dart';

class FailingHasher extends PasswordHasher {
  FailingHasher(this.failure) : super(iterations: 10000);
  Object? failure;
  @override
  Future<PasswordDigest> hash(String password) async {
    if (failure != null) throw failure!;
    return super.hash(password);
  }
}

TypeMatcher<AuthFailure> diagnostic(String code) => isA<AuthFailure>().having(
  (e) => e.diagnostic,
  'safe diagnostic',
  contains(code),
);

void main() {
  LocalAuthRepository repository(
    MemoryAuthStorage storage, {
    PasswordHasher? hasher,
    String Function()? id,
  }) {
    final repo = LocalAuthRepository(
      storage: storage,
      hasher: hasher ?? const PasswordHasher(iterations: 10000),
      generateId: id ?? secureUserId,
    );
    addTearDown(repo.dispose);
    return repo;
  }

  test(
    'Valid registration persists restart and login without automatic session',
    () async {
      final storage = MemoryAuthStorage();
      final first = repository(storage);
      final user = await first.register(registration());
      expect(await first.getCurrentUser(), isNull);
      final after = repository(storage);
      await after.initialize();
      expect(
        (await after.login('new@example.test', 'Secret2026!')).id,
        user.id,
      );
      final reopened = repository(storage);
      expect((await reopened.getCurrentUser())!.id, user.id);
      expect(storage.value, isNot(contains('Secret2026!')));
    },
  );

  test(
    'Duplicate normalized email is diagnosed without modifying saved account',
    () async {
      final storage = MemoryAuthStorage();
      final repo = repository(storage);
      await repo.register(registration());
      final before = storage.value;
      await expectLater(
        repo.register(registration(email: ' NEW@EXAMPLE.TEST ')),
        throwsA(diagnostic('AUTH_DUPLICATE_EMAIL')),
      );
      expect(storage.value, before);
    },
  );

  test('Invalid fields stop before entropy hashing or writing', () async {
    final storage = MemoryAuthStorage();
    final repo = repository(
      storage,
      id: () => throw StateError('must not run'),
    );
    await expectLater(
      repo.register(registration(email: 'invalid')),
      throwsA(diagnostic('AUTH_VALIDATION')),
    );
    expect(storage.value, isNull);
  });

  test('Secure random unavailable has explicit code and retry keeps strong entropy', () async {
    final storage = MemoryAuthStorage();
    var unavailable = true;
    final repo = repository(
      storage,
      id: () {
        if (unavailable) throw UnsupportedError('secret must not be displayed');
        return secureUserId();
      },
    );
    await expectLater(
      repo.register(registration()),
      throwsA(diagnostic('AUTH_RANDOM_UNAVAILABLE')),
    );
    expect(storage.value, isNull);
    unavailable = false;
    await repo.register(registration());
    expect(AuthSnapshot.decode(storage.value!).accounts.length, 1);
  });

  for (final unavailable in [false, true]) {
    test(
      'Hash failure unavailable=$unavailable is classified and retry succeeds',
      () async {
        final storage = MemoryAuthStorage();
        final hasher = FailingHasher(
          unavailable
              ? UnsupportedError('private sentinel')
              : StateError('private sentinel'),
        );
        final repo = repository(storage, hasher: hasher);
        await expectLater(
          repo.register(registration()),
          throwsA(
            diagnostic(unavailable ? 'AUTH_CRYPTO_UNAVAILABLE' : 'AUTH_KDF')
                .having(
                  (e) => e.diagnostic,
                  'no error payload',
                  isNot(contains('private sentinel')),
                ),
          ),
        );
        expect(storage.value, isNull);
        hasher.failure = null;
        await repo.register(registration());
        await repo.login('new@example.test', 'Secret2026!');
      },
    );
  }

  test(
    'Failed storage write keeps existing accounts and allows same-email retry',
    () async {
      final storage = MemoryAuthStorage();
      final repo = repository(storage);
      await repo.register(registration(email: 'existing@example.test'));
      final before = storage.value;
      storage.failWrites = true;
      await expectLater(
        repo.register(registration()),
        throwsA(diagnostic('AUTH_WRITE')),
      );
      expect(storage.value, before);
      storage.failWrites = false;
      await repo.register(registration());
      expect(AuthSnapshot.decode(storage.value!).accounts.length, 2);
    },
  );
}
