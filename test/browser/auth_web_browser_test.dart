@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:cryptography/cryptography.dart';
import 'package:web/web.dart' as web;
import 'package:animora/features/auth/services/preferences_auth_web.dart';
import 'package:animora/features/auth/services/local_auth_storage.dart';
import 'package:animora/features/auth/services/auth_backend.dart';
import 'package:animora/features/auth/services/password_hasher.dart';
import 'package:animora/features/auth/repositories/local_auth_repository.dart';
import 'package:animora/features/auth/models/auth_requests.dart';

import '../support/auth_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = PreferencesAuthStorage.key;
  const legacyKey = 'flutter.$key';
  String? initial, initialLegacy;
  setUpAll(() async {
    SharedPreferencesAsyncWeb.registerWith(null);
    await seedDatabase();
  });
  setUp(() {
    initial = web.window.localStorage.getItem(key);
    initialLegacy = web.window.localStorage.getItem(legacyKey);
    web.window.localStorage.removeItem(key);
    web.window.localStorage.removeItem(legacyKey);
  });
  tearDown(() {
    for (final pair in [(key, initial), (legacyKey, initialLegacy)]) {
      if (pair.$2 == null) {
        web.window.localStorage.removeItem(pair.$1);
      } else {
        web.window.localStorage.setItem(pair.$1, pair.$2!);
      }
    }
  });
  test(
    'Browser fresh startup does not require WebCrypto or a preference write',
    () async {
      final backend = createAuthBackend();
      await backend.repository.initialize();
      expect(await backend.repository.getCurrentUser(), isNull);
      expect(backend.context, isNull);
      expect(web.window.localStorage.getItem(key), isNull);
      backend.repository.dispose();
    },
  );
  test('SharedPreferences account session survives new adapters and reload simulation', () async {
    final source = jsonDecode(await seedDatabase()) as Map<String, dynamic>;
    source['sessionId'] = 'demo-citizen';
    final raw = jsonEncode(source);
    web.window.localStorage.setItem(key, jsonEncode(raw));
    final first = LocalAuthRepository(storage: PreferencesAuthStorage());
    await first.initialize();
    expect((await first.getCurrentUser())!.id, 'demo-citizen');
    first.dispose();
    final next = LocalAuthRepository(storage: PreferencesAuthStorage());
    await next.initialize();
    expect((await next.getCurrentUser())!.id, 'demo-citizen');
    expect(web.window.localStorage.getItem(key), jsonEncode(raw));
    next.dispose();
  });
  test('Targeted fallback reads only the requested preference when enumeration fails', () async {
    final raw = await seedDatabase();
    web.window.localStorage.setItem(key, jsonEncode(raw));
    web.window.localStorage.setItem('animora.test.unrelated', 'not-json');
    try {
      final storage = PreferencesAuthBackend(
        readPreference: (_) async =>
            throw StateError('enumeration unavailable'),
      );
      expect(await storage.read(key), raw);
      expect(
        web.window.localStorage.getItem('animora.test.unrelated'),
        'not-json',
      );
    } finally {
      web.window.localStorage.removeItem('animora.test.unrelated');
    }
  });
  test(
    'Legacy prefixed preference is retained in place across writes',
    () async {
      final raw = await seedDatabase();
      web.window.localStorage.setItem(legacyKey, jsonEncode(raw));
      final storage = PreferencesAuthStorage();
      expect(await storage.read(), raw);
      await storage.write(raw);
      expect(web.window.localStorage.getItem(key), isNull);
      expect(web.window.localStorage.getItem(legacyKey), jsonEncode(raw));
    },
  );
  test('Corrupt preference envelope and JSON never get overwritten', () async {
    web.window.localStorage.setItem(key, 'not json');
    final repo = LocalAuthRepository(storage: PreferencesAuthStorage());
    await expectLater(repo.initialize(), throwsA(isA<AuthFailure>()));
    expect(web.window.localStorage.getItem(key), 'not json');
    repo.dispose();
    web.window.localStorage.setItem(key, jsonEncode('{broken'));
    final again = LocalAuthRepository(storage: PreferencesAuthStorage());
    await expectLater(again.initialize(), throwsA(isA<AuthFailure>()));
    expect(web.window.localStorage.getItem(key), jsonEncode('{broken'));
    again.dispose();
  });
  test(
    'PBKDF2 pure Dart fallback verifies the same existing password digest',
    () async {
      final previous = BrowserCryptography.isDisabledForTesting;
      BrowserCryptography.isDisabledForTesting = true;
      try {
        const hasher = PasswordHasher(iterations: 10000);
        final digest = await hasher.hash('BrowserSecret2026!');
        expect(await hasher.verify('BrowserSecret2026!', digest), true);
        expect(await hasher.verify('wrong', digest), false);
      } finally {
        BrowserCryptography.isDisabledForTesting = previous;
      }
    },
  );
}
