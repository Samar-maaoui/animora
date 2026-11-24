import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_vault.dart';

class NativeAuthVault implements AuthVault {
  const NativeAuthVault();
  static const storage = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
}
