import '../repositories/local_auth_repository.dart';
import 'auth_backend_model.dart';
import 'auth_security_store.dart';
import 'local_auth_storage.dart';
import '../data/demo_recovery.dart';

AuthBackend createAuthBackend() => AuthBackend(
  LocalAuthRepository(
    storage: PreferencesAuthStorage(),
    recoverDemoAccounts: DemoRecovery.enabled,
    securityStore: PreferencesAuthSecurityStore(),
  ),
);
