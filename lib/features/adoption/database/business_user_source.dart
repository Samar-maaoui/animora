import 'dart:convert';

import '../../auth/services/local_auth_storage.dart';
import '../../users/models/user.dart';
import '../repositories/animal_repository.dart';

/// Reads business profiles only. Never serializes credentials or session IDs to SQL.
class BusinessUserSource {
  BusinessUserSource(this.storage);
  final AuthStorage storage;
  Future<List<User>> read() async {
    final raw = await storage.read();
    if (raw == null) return [];
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != 1) throw const FormatException();
      final users = <User>[];
      final ids = <String>{}, emails = <String>{};
      for (final account in json['accounts'] as List) {
        final user = User.fromJson(
          Map<String, dynamic>.from((account as Map)['user'] as Map),
        );
        if (user.id.trim().isEmpty ||
            !ids.add(user.id) ||
            !emails.add(user.email.toLowerCase())) {
          throw const FormatException();
        }
        users.add(user);
      }
      return users;
    } catch (_) {
      throw const CatalogFailure(
        'Les profils utilisateurs locaux sont invalides. La migration SQLite n’a pas été appliquée.',
      );
    }
  }
}
