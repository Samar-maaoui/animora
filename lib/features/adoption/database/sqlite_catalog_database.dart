import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqlite_api.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../users/models/user.dart';
import '../repositories/animal_repository.dart';
import '../repositories/local_catalog_database.dart';
import 'legacy_catalog_codec.dart';
import 'sqlite_catalog_dao.dart';

/// Shares existing repository rules, but persists normalized rows, never a JSON catalog.
class SqliteCatalogDatabase extends LocalCatalogDatabase {
  SqliteCatalogDatabase(
    super.legacy, {
    required this.helper,
    required this.loadBusinessUsers,
    this.ownsHelper = true,
  });
  final DatabaseHelper helper;
  final bool ownsHelper;
  final Future<List<User>> Function() loadBusinessUsers;
  final dao = SqliteCatalogDao();
  Future<void> _tail = Future.value();
  bool _initialized = false, _closed = false;
  Future<T> _run<T>(Future<T> Function() f) {
    final result = _tail.then((_) async {
      if (_closed) {
        throw const CatalogFailure('La base du catalogue est fermée.');
      }
      try {
        return await f();
      } on CatalogFailure {
        rethrow;
      } catch (_) {
        throw const CatalogFailure(
          'Opération SQLite impossible. Les anciennes données sont conservées. Réessayez.',
        );
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return result;
  }

  Future<void> initialize() => _run(_initialize);
  Future<void> _initialize() async {
    if (_initialized) return;
    final db = await helper.database;
    if (await dao.metadata(db, DatabaseConstants.catalogMigration) != null) {
      _initialized = true;
      return;
    }
    final raw = await storage.read();
    final legacy = LegacyCatalogCodec.decode(raw);
    final users = {for (final u in await loadBusinessUsers()) u.id: u};
    // Old snapshots retain genuine profiles even if no current business row is available.
    for (final u in legacy.workflow.applicants.values) {
      users.putIfAbsent(u.id, () => u);
    }
    LegacyCatalogCodec.validate(legacy, users);
    await db.transaction((tx) async {
      if (await dao.metadata(tx, DatabaseConstants.catalogMigration) != null) {
        return;
      }
      for (final table in DatabaseConstants.tables) {
        final count =
            (await tx.rawQuery('SELECT COUNT(*) AS n FROM $table')).single['n']
                as int;
        if (count != 0) {
          throw const CatalogFailure(
            'La base SQLite contient déjà des données sans marqueur de migration. Aucun écrasement automatique.',
          );
        }
      }
      await dao.syncUsers(tx, users.values);
      await dao.persistChanges(
        tx,
        CatalogData(animals: {}, favorites: [], nextId: 1),
        legacy,
      );
      await dao.verifyIntegrity(tx);
      final expected = LegacyCatalogCodec.counts(legacy, users);
      for (final e in expected.entries) {
        final actual = (await tx.rawQuery('SELECT COUNT(*) AS n FROM ${e.key}'))
            .single['n'];
        if (actual != e.value) {
          throw const CatalogFailure(
            'Le nombre de lignes transférées est incorrect. Migration annulée.',
          );
        }
      }
      final imported = await dao.readCatalog(tx);
      LegacyCatalogCodec.validate(imported, await dao.readUsers(tx));
      // Last write in the same transaction: a crash cannot publish a half migration.
      await dao.putMetadata(
        tx,
        DatabaseConstants.catalogMigration,
        jsonEncode({
          'source': raw == null ? 'initial_seed' : 'preferences',
          'counts': expected,
        }),
      );
    });
    _initialized = true;
  }

  Future<T> readSql<T>(
    Future<T> Function(DatabaseExecutor, SqliteCatalogDao) action,
  ) {
    final transaction = helper.currentTransaction;
    if (transaction != null) {
      if (!_initialized) {
        throw const CatalogFailure(
          'Le catalogue doit être initialisé avant une lecture imbriquée.',
        );
      }
      return action(transaction, dao);
    }
    return _run(() async {
      await _initialize();
      final profiles = await loadBusinessUsers();
      return helper.transaction((tx) async {
        await dao.syncUsers(tx, profiles);
        return action(tx, dao);
      });
    });
  }

  @override
  Future<T> read<T>(T Function(CatalogData) action) =>
      readSql((tx, dao) async => action(await dao.readCatalog(tx)));
  @override
  Future<T> mutate<T>(T Function(CatalogData) action) => _run(() async {
    await _initialize();
    final profiles = await loadBusinessUsers();
    final result = await helper.transaction((tx) async {
      await dao.syncUsers(tx, profiles);
      final before = await dao.readCatalog(tx), draft = before.clone();
      final result = action(draft);
      LegacyCatalogCodec.validate(draft, await dao.readUsers(tx));
      await dao.persistChanges(tx, before, draft);
      if ((await tx.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
        throw const CatalogFailure('Relation SQLite invalide.');
      }
      return result;
    });
    if (!_closed) notifyListeners();
    return result;
  });
  Future<void> close() async {
    await _tail;
    if (ownsHelper) await helper.close();
  }

  @override
  void dispose() {
    _closed = true;
    if (ownsHelper) unawaited(_tail.then((_) => helper.close()));
    super.dispose();
  }
}
