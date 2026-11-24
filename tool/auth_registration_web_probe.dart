// Standalone validation entry point; not imported by the production app.
// Run only with an isolated browser profile and an empty auth preference.
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:web/web.dart' as web;
import 'package:animora/core/enums/user_profile.dart';
import 'package:animora/features/auth/models/auth_requests.dart';
import 'package:animora/features/auth/repositories/local_auth_repository.dart';
import 'package:animora/features/auth/services/auth_diagnostics.dart';
import 'package:animora/features/auth/services/auth_environment.dart';
import 'package:animora/features/auth/services/local_auth_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferencesAsyncWeb.registerWith(null);
  final passed = <String>[];
  String? failure;
  final storage = PreferencesAuthStorage();
  LocalAuthRepository? repo, reopened;
  void check(bool condition, String name) {
    if (!condition) throw StateError(name);
    passed.add(name);
  }

  try {
    // Refuse to run rather than clear, merge, or overwrite existing accounts.
    if (await storage.read() != null) {
      throw StateError('Probe requires an empty isolated browser profile');
    }
    repo = LocalAuthRepository(storage: storage);
    await repo.initialize();
    check(await repo.getCurrentUser() == null, 'fresh startup');
    const request = RegisterRequest(
      firstName: 'Probe',
      lastName: 'Test',
      email: 'probe@example.test',
      phone: '+21620333444',
      city: 'Tunis',
      password: 'ProbeSecret2026!',
      profile: UserProfile.citizen,
    );
    final user = await repo.register(request);
    check(user.id.length == 32, 'secure random identifier');
    check(await repo.getCurrentUser() == null, 'no automatic sign in');
    final saved = await storage.read();
    check(
      saved != null && !saved.contains(request.password),
      'password not stored in clear',
    );
    try {
      await repo.register(request);
      throw StateError('duplicate accepted');
    } on AuthFailure catch (error) {
      check(error.code == AuthFailureCode.duplicateEmail, 'duplicate rejected');
    }
    check(await storage.read() == saved, 'duplicate preserves document');
    reopened = LocalAuthRepository(storage: PreferencesAuthStorage());
    await reopened.initialize();
    final login = await reopened.login(request.email, request.password);
    check(
      login.id == user.id,
      'registration survives repository restart and login',
    );
    try {
      await reopened.login(request.email, 'incorrect');
      throw StateError('incorrect password accepted');
    } on AuthFailure catch (error) {
      check(
        error.code == AuthFailureCode.invalidCredentials,
        'incorrect password rejected',
      );
    }
  } catch (error) {
    final safe = error is AuthFailure ? error : unknownAuthFailure(error);
    failure = safe.diagnostic ?? safe.code.name;
  } finally {
    repo?.dispose();
    reopened?.dispose();
  }
  // Only test labels, capability flags and non-sensitive diagnostic codes.
  final output = web.document.createElement('pre')..id = 'auth-probe';
  output.textContent = jsonEncode({
    'passed': passed,
    'failure': failure,
    'environment': authEnvironmentDiagnostic(),
  });
  web.document.body!.append(output);
}
