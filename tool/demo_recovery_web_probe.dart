// Isolated browser validation entry point, never imported by the application.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:web/web.dart' as web;
import 'package:animora/core/enums/account_status.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/auth/data/demo_recovery.dart';
import 'package:animora/features/auth/models/auth_requests.dart';
import 'package:animora/features/auth/repositories/local_auth_repository.dart';
import 'package:animora/features/auth/services/auth_backend.dart';
import 'package:animora/features/auth/services/auth_diagnostics.dart';
import 'package:animora/features/auth/services/auth_environment.dart';
import 'package:animora/features/auth/services/local_auth_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferencesAsyncWeb.registerWith(null);
  final passed = <String>[];
  String? failure;
  final storage = PreferencesAuthStorage();
  final backend = createAuthBackend();
  LocalAuthRepository? reopened, forced;
  void check(bool ok, String name) {
    if (!ok) throw StateError('probe assertion');
    passed.add(name);
  }

  try {
    if (await storage.read() != null) {
      throw StateError('isolated empty profile required');
    }
    final repo = backend.repository as LocalAuthRepository;
    await repo.initialize();
    if (kDebugMode) {
      check(DemoRecovery.enabled, 'explicit debug flag enabled');
      check(
        repo.demoRecoveryResult!.created.length == 8,
        'eight accounts created',
      );
      for (final template in DemoRecovery.users) {
        final user = await repo.login(template.email, DemoAccounts.password);
        check(
          user.id == template.id &&
              user.profile == template.profile &&
              user.status == template.status,
          'role status and login verified',
        );
        if (user.status != AccountStatus.active) {
          try {
            await repo.listServiceProviders();
            throw StateError('restricted account admitted');
          } on AuthFailure catch (e) {
            check(
              e.code == AuthFailureCode.forbidden,
              'restricted account denied',
            );
          }
        }
      }
      final before = await storage.read();
      await repo.initialize();
      check(
        await storage.read() == before,
        'repeat seed preserves exact document and session',
      );
      reopened = createAuthBackend().repository as LocalAuthRepository;
      await reopened.initialize();
      check(
        await storage.read() == before,
        'new backend preserves existing credentials',
      );
      check((await reopened.getCurrentUser()) != null, 'session restored');
      final saved = await storage.read();
      final changed = jsonDecode(saved!) as Map<String, dynamic>;
      final extra = jsonDecode(
        jsonEncode((changed['accounts'] as List).first),
      ) as Map<String, dynamic>;
      (extra['user'] as Map)['id'] = 'probe-existing-user';
      (extra['user'] as Map)['email'] = 'existing-user@example.test';
      (changed['accounts'] as List).add(extra);
      final newer = jsonEncode(changed);
      web.window.localStorage.setItem(
        PreferencesAuthStorage.key,
        jsonEncode(newer),
      );
      try {
        await storage.write(saved);
        throw StateError('newer account overwritten');
      } on AuthFailure catch (e) {
        check(
          e.diagnostic == 'AUTH_PREFERENCES_CONCURRENT',
          'concurrent document rejected',
        );
      }
      check(await storage.read() == newer, 'newer existing account preserved');
    } else {
      check(
        !DemoRecovery.enabled,
        'release seed disabled despite requested flag',
      );
      check(await storage.read() == null, 'production factory never seeds');
      forced = LocalAuthRepository(
        storage: storage,
        seedDemoAccounts: true,
        recoverDemoAccounts: true,
      );
      await forced.initialize();
      check(
        await storage.read() == null,
        'explicit repository seed also refused in release',
      );
      try {
        await repo.login('admin@animora.test', DemoAccounts.password);
        throw StateError('production demo admin exists');
      } on AuthFailure catch (e) {
        check(
          e.code == AuthFailureCode.invalidCredentials,
          'no production demo administrator',
        );
      }
    }
  } catch (error) {
    final safe = error is AuthFailure ? error : unknownAuthFailure(error);
    failure = safe.diagnostic ?? safe.code.name;
  } finally {
    backend.repository.dispose();
    reopened?.dispose();
    forced?.dispose();
  }
  final output = web.document.createElement('pre')..id = 'auth-probe';
  output.textContent = jsonEncode({
    'passed': passed,
    'failure': failure,
    'environment': authEnvironmentDiagnostic(),
  });
  web.document.body!.append(output);
}
