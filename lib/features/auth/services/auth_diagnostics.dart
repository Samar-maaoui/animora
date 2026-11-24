import '../models/auth_requests.dart';
import 'auth_environment.dart';

// Diagnostics must never depend on successful access to browser APIs.
String authDiagnostic(String stage, Object error) {
  var environment = 'environment=unavailable';
  try {
    environment = authEnvironmentDiagnostic();
  } catch (_) {}
  return '$stage; exception=${error.runtimeType}; $environment';
}

AuthFailure unknownAuthFailure(Object error) => AuthFailure(
  AuthFailureCode.unknown,
  'Cette opération n’a pas pu aboutir. Réessayez et relevez le code de diagnostic si le problème persiste.',
  diagnostic: authDiagnostic('AUTH_UNKNOWN', error),
);
