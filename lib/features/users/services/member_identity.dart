import '../models/user.dart';

/// 32-bit FNV-1a, written so it gives the same result on mobile and Web
/// (every intermediate value stays below 2^53).
int _fnv1a(String input, int seed) {
  var h = seed;
  for (final unit in input.codeUnits) {
    h ^= unit & 0xFF;
    h ^= (unit >> 8) & 0xFF;
    // h * 16777619 mod 2^32 == h * 403 + (h mod 2^8) * 2^24  (mod 2^32)
    h = (h * 403 + (h & 0xFF) * 16777216) % 4294967296;
  }
  return h;
}

/// Public member number « ANI-XXXXXXXX ». It is a one-way fingerprint of
/// the account: the internal id cannot be recovered from it, so it can be
/// printed on the card and in the QR code.
String memberNumber(User user) {
  final h = _fnv1a('animora-member:${user.id}', 0x811C9DC5);
  return 'ANI-${h.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

/// DiceBear seed: the public member number (never the internal id).
String publicAvatarSeed(User user) => memberNumber(user);
