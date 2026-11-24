import 'dart:convert';

import '../../users/models/user.dart';
import '../../../core/utils/form_validators.dart';
import 'password_hasher.dart';

class AuthAccount {
  const AuthAccount(this.user, this.password);
  final User user;
  final PasswordDigest password;
  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'credential': password.toJson(),
  };
}

class AuthSnapshot {
  const AuthSnapshot(this.accounts, this.sessionId);
  final Map<String, AuthAccount> accounts;
  final String? sessionId;
  String encode() => jsonEncode({
    'version': 1,
    'accounts': accounts.values.map((a) => a.toJson()).toList(),
    'sessionId': sessionId,
  });
  factory AuthSnapshot.decode(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['version'] != 1 || j['accounts'] is! List) {
        throw const FormatException('schema');
      }
      final accounts = <String, AuthAccount>{};
      final emails = <String>{};
      for (final row in j['accounts'] as List) {
        if (row is! Map) throw const FormatException('record');
        final u = User.fromJson(Map<String, dynamic>.from(row['user'] as Map));
        final digest = PasswordDigest.fromJson(
          Map<String, dynamic>.from(row['credential'] as Map),
        );
        if (u.id.trim().isEmpty ||
            accounts.containsKey(u.id) ||
            !emails.add(u.email.trim().toLowerCase()) ||
            FormValidators.email(u.email) != null) {
          throw const FormatException('identity');
        }
        if (base64Decode(digest.salt).length != 16 ||
            base64Decode(digest.hash).length != 32) {
          throw const FormatException('credential');
        }
        accounts[u.id] = AuthAccount(u, digest);
      }
      final id = j['sessionId'];
      if (id != null && id is! String) throw const FormatException('session');
      return AuthSnapshot(
        accounts,
        accounts.containsKey(id) ? id as String? : null,
      );
    } catch (_) {
      throw const FormatException('Invalid local account document');
    }
  }
}
