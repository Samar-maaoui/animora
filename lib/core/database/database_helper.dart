import 'dart:async';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqlite_api.dart';

import 'database_constants.dart';
import 'database_migrations.dart';

class DatabaseFailure implements Exception {
  const DatabaseFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The factory is the mobile sqflite plugin in production, real SQLite FFI in tests.
class DatabaseHelper {
  DatabaseHelper({required this.factory, this.pathOverride});
  final DatabaseFactory factory;
  final String? pathOverride;
  Database? _database;
  Future<Database>? _opening;
  Future<Database> get database async {
    if (_database?.isOpen == true) return _database!;
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    try {
      final file =
          pathOverride ??
          path.join(await factory.getDatabasesPath(), DatabaseConstants.name);
      final db = await factory.openDatabase(
        file,
        options: OpenDatabaseOptions(
          singleInstance: file != ':memory:',
          version: DatabaseConstants.version,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, version) => DatabaseMigrations.upgrade(db, 0, version),
          onUpgrade: (db, oldVersion, newVersion) =>
              DatabaseMigrations.upgrade(db, oldVersion, newVersion),
          onDowngrade: (db, oldVersion, newVersion) async {
            throw const DatabaseFailure(
              'Cette base est plus récente que l’application. Aucune donnée n’a été effacée.',
            );
          },
        ),
      );
      final foreignKeys = await db.rawQuery('PRAGMA foreign_keys');
      if (foreignKeys.single.values.single != 1) {
        await db.close();
        throw const DatabaseFailure(
          'Les clés étrangères SQLite ne sont pas actives.',
        );
      }
      _database = db;
      return db;
    } catch (e) {
      _opening = null;
      rethrow;
    }
  }

  static final _transactionKey = Object();
  Transaction? get currentTransaction {
    final entry = Zone.current[_transactionKey];
    return entry is (DatabaseHelper, Transaction) && identical(entry.$1, this)
        ? entry.$2
        : null;
  }

  Future<T> transaction<T>(Future<T> Function(Transaction) action) async {
    final existing = currentTransaction;
    if (existing != null) return action(existing);
    return (await database).transaction(
      (tx) =>
          runZoned(() => action(tx), zoneValues: {_transactionKey: (this, tx)}),
    );
  }

  Future<void> close() async {
    final pending = _opening;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    await _database?.close();
    _database = null;
    _opening = null;
  }
}
