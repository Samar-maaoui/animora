import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('isSecureContext')
external JSBoolean? get _secure;
@JS('crypto.subtle')
external JSAny? get _subtle;
@JS('crypto.getRandomValues')
external JSAny? get _random;
String _flag(bool Function() read) {
  try {
    return '${read()}';
  } catch (_) {
    return 'unavailable';
  }
}

String authEnvironmentDiagnostic() {
  var storage = 'blocked';
  try {
    web.window.localStorage.length;
    storage = 'readable';
  } catch (_) {}
  return 'platform=web; secure_context=${_flag(() => _secure?.toDart ?? false)}; webcrypto=${_flag(() => _subtle.isDefinedAndNotNull)}; secure_random=${_flag(() => _random.isDefinedAndNotNull)}; local_storage=$storage';
}
