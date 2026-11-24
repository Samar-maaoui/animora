import 'package:cryptography/cryptography.dart';

Pbkdf2 createPasswordKdf(int iterations) =>
    Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);
