import 'package:animora/core/database/database_helper.dart';
import 'package:animora/core/enums/account_status.dart';
import 'package:animora/core/enums/user_profile.dart';
import 'package:animora/core/utils/form_validators.dart';
import 'package:animora/features/admin/screens/admin_security_log_screen.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/auth/models/auth_event.dart';
import 'package:animora/features/auth/models/auth_requests.dart';
import 'package:animora/features/auth/repositories/sqlite_auth_repository.dart';
import 'package:animora/features/auth/services/auth_vault.dart';
import 'package:animora/features/auth/services/password_hasher.dart';
import 'package:animora/features/auth/services/sqlite_auth_security_store.dart';
import 'package:animora/features/auth/services/sqlite_auth_storage.dart';
import 'package:animora/features/users/screens/member_card_screen.dart';
import 'package:animora/features/users/services/member_card_payload.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/auth_test_support.dart';

const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

void main() {
  setUpAll(sqfliteFfiInit);
  setUpAll(seedDatabase);

  test('Password policy: 8+ chars, uppercase, digit and symbol', () {
    expect(FormValidators.password('Animora2026!'), isNull);
    for (final weak in [
      'Ab1!',
      'animora2026!',
      'ANIMORAsans!',
      'Animora2026',
    ]) {
      expect(FormValidators.password(weak), isNotNull, reason: weak);
    }
  });

  test('Every journal event type has exactly one specific filter', () {
    for (final type in AuthEventType.values) {
      final filters = SecurityLogFilter.values
          .where((f) => f != SecurityLogFilter.all && f.accepts(type))
          .toList();
      expect(filters, hasLength(1), reason: type.name);
      expect(SecurityLogFilter.all.accepts(type), isTrue);
    }
    expect(
      SecurityLogFilter.accounts.accepts(AuthEventType.emailVerified),
      isTrue,
    );
    expect(
      SecurityLogFilter.accounts.accepts(AuthEventType.passwordResetRequested),
      isTrue,
    );
  });

  test('Member card fallback: QR Server, no id, no e-mail', () {
    final user = DemoAccounts.users.first;
    expect(memberNumber(user), matches(RegExp(r'^ANI-[0-9A-F]{8}$')));
    final content = memberQrContent(user, baseUrl: '');
    expect(content, 'ANIMORA|MEMBRE|${memberNumber(user)}');
    final url = qrServerUrl(content);
    expect(url.host, 'api.qrserver.com');
    expect(url.toString().contains(user.id), isFalse);
    expect(url.toString().contains(user.email), isFalse);
  });

  test('Defence scenario: journal + SQLite rows, no secret in clear', () async {
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
    const pw = DemoAccounts.password;
    final secrets = <String>[pw];

    // 1. Veterinarian sign-up with e-mail verification + card number.
    const vetPassword = 'VetoSecure#2026';
    secrets.add(vetPassword);
    final vetRequest = RegisterRequest(
      firstName: 'Ines',
      lastName: 'Vet',
      email: 'ines.vet@example.test',
      phone: '+216 20 777 888',
      city: 'Sousse',
      password: vetPassword,
      profile: UserProfile.veterinarian,
      professionalCardNumber: 'CNOV-4521',
    );
    final verify = await repo.createEmailVerificationCode(vetRequest);
    secrets.add(verify.code);
    final vet = await repo.registerWithEmailCode(vetRequest, verify.code);
    expect(vet.status, AccountStatus.pending);

    // 2. Pet-sitter: 5 failures → lock.
    for (var i = 0; i < 5; i++) {
      await expectLater(
        repo.login('pet-sitter@animora.test', 'Mauvais#${i}xx'),
        throwsA(isA<AuthFailure>()),
      );
    }

    // 3. Citizen: password + biometric logins, photo, password change.
    await repo.login('citizen@animora.test', pw);
    await repo.updateProfilePhoto(_png);
    const changed = 'Changé#2026x';
    secrets.add(changed);
    await repo.changePassword(pw, changed);
    await repo.enableBiometricLogin();
    await repo.logout();
    await repo.loginWithBiometrics();
    await repo.logout();

    // 4. Forgotten password.
    final reset = (await repo.createPasswordResetCode('citizen@animora.test'))!;
    secrets.add(reset.code);
    const resetPw = 'Reinit#2026x';
    secrets.add(resetPw);
    await repo.resetPasswordWithCode(
      'citizen@animora.test',
      reset.code,
      resetPw,
    );

    // 5. Admin decisions.
    await repo.login('admin@animora.test', pw);
    await repo.updateUserStatus(vet.id, AccountStatus.active);
    await repo.updateUserStatus('demo-citizen', AccountStatus.blocked);
    await repo.updateUserStatus('demo-citizen', AccountStatus.active);

    final events = await repo.listAuthEvents(limit: 500);
    // Newest first.
    for (var i = 1; i < events.length; i++) {
      expect(!events[i - 1].createdAt.isBefore(events[i].createdAt), isTrue);
    }
    final types = events.map((e) => e.type).toSet();
    for (final t in [
      AuthEventType.emailCodeSent,
      AuthEventType.emailVerified,
      AuthEventType.register,
      AuthEventType.loginSuccess,
      AuthEventType.loginBiometric,
      AuthEventType.logout,
      AuthEventType.loginFailure,
      AuthEventType.loginLocked,
      AuthEventType.passwordResetRequested,
      AuthEventType.passwordReset,
      AuthEventType.photoUpdate,
      AuthEventType.passwordChange,
      AuthEventType.statusChange,
    ]) {
      expect(types, contains(t), reason: t.name);
    }
    final lock = events.firstWhere((e) => e.type == AuthEventType.loginLocked);
    expect(lock.email, 'pet-sitter@animora.test');
    final changes = events
        .where((e) => e.type == AuthEventType.statusChange)
        .toList();
    expect(changes.map((e) => e.details), [
      'blocked → active',
      'active → blocked',
      'pending → active',
    ]);
    expect(changes.every((e) => e.actorId == 'demo-admin'), isTrue);
    expect(changes.last.userId, vet.id);

    // SQLite rows as seen in the Database Inspector.
    final db = await helper.database;
    final row = (await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [vet.id],
    )).single;
    expect(row['status'], 'active');
    expect(row['professionalCardNumber'], 'CNOV-4521');
    final dbEvents = await db.query('auth_events');
    expect(dbEvents.length, events.length);
    final dump =
        '${await db.query('auth_events')}${await db.query('users')}'
        '${await db.query('auth_accounts')}';
    for (final secret in secrets) {
      expect(dump.contains(secret), isFalse, reason: 'secret in clear');
    }
  });
}
