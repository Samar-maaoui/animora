import 'package:sqflite/sqlite_api.dart';

import '../../../core/database/database_helper.dart';
import '../models/auth_event.dart';
import 'auth_security_store.dart';

/// Android/iOS: table `auth_events` (schema v8) and `database_metadata`
/// in the shared animora.db.
class SqliteAuthSecurityStore implements AuthSecurityStore {
  SqliteAuthSecurityStore(this.helper);
  final DatabaseHelper helper;
  static const _settingPrefix = 'auth_setting_';

  @override
  Future<void> record(AuthEvent event) async {
    final db = await helper.database;
    await db.insert('auth_events', {
      'type': event.type.name,
      'email': event.email,
      'userId': event.userId,
      'actorId': event.actorId,
      'details': event.details,
      'createdAt': event.createdAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<AuthEvent>> events({
    int limit = 100,
    String? email,
    DateTime? since,
  }) async {
    final db = await helper.database;
    final where = <String>[], args = <Object?>[];
    if (email != null) {
      where.add('email = ?');
      args.add(email);
    }
    if (since != null) {
      where.add('createdAt > ?');
      args.add(since.toUtc().toIso8601String());
    }
    final rows = await db.query(
      'auth_events',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'createdAt DESC, id DESC',
      limit: limit,
    );
    return [for (final r in rows) _fromRow(r)];
  }

  AuthEvent _fromRow(Map<String, Object?> r) => AuthEvent(
    id: r['id']! as int,
    type: AuthEventType.values.byName(r['type']! as String),
    createdAt: DateTime.parse(r['createdAt']! as String),
    email: r['email'] as String?,
    userId: r['userId'] as String?,
    actorId: r['actorId'] as String?,
    details: r['details'] as String?,
  );

  @override
  Future<String?> readSetting(String key) async {
    final rows = await (await helper.database).query(
      'database_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['$_settingPrefix$key'],
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  @override
  Future<void> writeSetting(String key, String? value) async {
    final db = await helper.database;
    if (value == null) {
      await db.delete(
        'database_metadata',
        where: 'key = ?',
        whereArgs: ['$_settingPrefix$key'],
      );
    } else {
      await db.insert('database_metadata', {
        'key': '$_settingPrefix$key',
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}
