import 'dart:convert';
import 'dart:math';

import 'password_kdf.dart';

class PasswordDigest {
  const PasswordDigest({
    required this.salt,
    required this.hash,
    required this.iterations,
  });
  final String salt, hash;
  final int iterations;
  Map<String, dynamic> toJson() => {
    'salt': salt,
    'hash': hash,
    'iterations': iterations,
  };
  factory PasswordDigest.fromJson(Map<String, dynamic> json) {
    final iterations = json['iterations'] as int;
    if (iterations < 10000 || iterations > 2000000) {
      throw const FormatException('Invalid KDF cost');
    }
    return PasswordDigest(
      salt: json['salt'] as String,
      hash: json['hash'] as String,
      iterations: iterations,
    );
  }
}

class PasswordHasher {
  const PasswordHasher({this.iterations = 120000});
  final int iterations;
  Future<PasswordDigest> hash(String password) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    return PasswordDigest(
      salt: base64Encode(salt),
      hash: await _derive(password, salt, iterations),
      iterations: iterations,
    );
  }

  Future<bool> verify(String password, PasswordDigest digest) async {
    final actual = base64Decode(
      await _derive(password, base64Decode(digest.salt), digest.iterations),
    );
    final expected = base64Decode(digest.hash);
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }

  Future<String> _derive(String password, List<int> salt, int cost) async {
    final key = await createPasswordKdf(cost)
        .deriveKeyFromPassword(password: password, nonce: salt);
    return base64Encode(await key.extractBytes());
  }
}
