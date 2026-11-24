import 'dart:js_interop';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

// Nullable interop is essential: on insecure HTTP, subtle is undefined.
// cryptography 2.9.0 uses a non-nullable getter, which can throw in debug builds
// before its intended fallback is selected. Keep the workaround in this app.
@JS('globalThis.isSecureContext')
external JSBoolean? get _secureContext;
@JS('globalThis.crypto.subtle')
external JSObject? get _subtleCrypto;

bool get supportsPasswordWebCrypto {
  try {
    return (_secureContext?.toDart ?? false) && _subtleCrypto != null;
  } catch (_) {
    return false;
  }
}

Pbkdf2 createPasswordKdf(int iterations) => supportsPasswordWebCrypto
    ? Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256)
    : DartPbkdf2(
        macAlgorithm: const DartHmac(DartSha256()),
        iterations: iterations,
        bits: 256,
      );
