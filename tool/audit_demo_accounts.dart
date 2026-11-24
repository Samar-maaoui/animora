import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Read-only development audit of named SQLite files, never opens a device DB
/// implicitly and never reads credentials or the native vault.
Future<void> main(List<String> files) async {
  sqfliteFfiInit();
  for (final file in files) {
    final db = await databaseFactoryFfi.openDatabase(
      File(file).absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    try {
      final rows = await db.rawQuery(
        "SELECT id,email,profile,status FROM users WHERE lower(trim(email)) IN ('citizen@animora.test','veterinarian@animora.test','pet-sitter@animora.test','foster@animora.test','pending@animora.test','blocked@animora.test','admin@animora.test','mohamed@animora.test') ORDER BY id",
      );
      final hasAuth = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='auth_accounts'",
      )).isNotEmpty;
      final credentialIds = hasAuth
          ? await db.rawQuery(
              'SELECT a.userId FROM auth_accounts a JOIN users u ON u.id=a.userId WHERE u.email LIKE ?',
              ['%@animora.test'],
            )
          : [];
      stdout.writeln(
        jsonEncode({
          'file': file,
          'version': await db.getVersion(),
          'demoProfiles': rows,
          'hasAuthAccountsTable': hasAuth,
          'authenticatedDemoIds': credentialIds,
        }),
      );
    } finally {
      await db.close();
    }
  }
}
