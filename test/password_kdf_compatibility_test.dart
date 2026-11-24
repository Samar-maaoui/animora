import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/dart.dart';
import 'package:animora/features/auth/services/password_hasher.dart';
import 'package:animora/features/auth/services/password_kdf.dart';

void main() {
  test(
    'Explicit Dart fallback computes the same existing password digest',
    () async {
      const hasher = PasswordHasher(iterations: 10000);
      final digest = await hasher.hash('SameSecret2026!');
      final key =
          await DartPbkdf2(
            macAlgorithm: DartHmac.sha256(),
            iterations: digest.iterations,
            bits: 256,
          ).deriveKeyFromPassword(
            password: 'SameSecret2026!',
            nonce: base64Decode(digest.salt),
          );
      expect(base64Encode(await key.extractBytes()), digest.hash);
      expect(await hasher.verify('SameSecret2026!', digest), true);
      expect(await hasher.verify('different', digest), false);
    },
  );
  test('Production PBKDF2 cost and output size remain unchanged', () {
    final kdf = createPasswordKdf(const PasswordHasher().iterations);
    expect(kdf.iterations, 120000);
    expect(kdf.bits, 256);
  });
}
