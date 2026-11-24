abstract interface class AuthVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class MemoryAuthVault implements AuthVault {
  final values = <String, String>{};
  bool failWrites = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('Secure storage unavailable');
    values[key] = value;
  }
}
