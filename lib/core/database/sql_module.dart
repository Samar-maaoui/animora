import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqlite_api.dart';

import '../../features/reports/repositories/reports_storage.dart';
import '../../features/adoption/database/sqlite_catalog_database.dart';
import '../../features/users/models/user.dart';
import 'database_helper.dart';

abstract interface class MigratingMediaStorage implements ReportsStorage {
  Future<void> importPhoto(String reference);
  Future<void> disposeStorage();
}

class SqlTable {
  const SqlTable({
    required this.name,
    required this.collection,
    required this.createSql,
    this.primaryKey = const ['id'],
    this.booleans = const [],
    this.jsonFields = const [],
    this.moneyFields = const [],
    this.releaseStatuses = const [],
    this.optionalReferences = const {},
  });
  final String name, collection, createSql;
  final Map<String, String> optionalReferences;
  final List<String> primaryKey,
      booleans,
      jsonFields,
      moneyFields,
      releaseStatuses;
  String key(Map<String, dynamic> row) =>
      jsonEncode(primaryKey.map((k) => row[k]).toList());
  Map<String, Object?> encode(Map<String, dynamic> row) => {
    for (final e in row.entries)
      if (!optionalReferences.containsKey(e.key))
        e.key: booleans.contains(e.key)
            ? (e.value == true ? 1 : 0)
            : jsonFields.contains(e.key)
            ? jsonEncode(e.value)
            : moneyFields.contains(e.key) && e.value != null
            ? ((e.value as num) * 1000).round()
            : e.value as Object?,
  };
  Map<String, dynamic> decode(Map<String, Object?> row) => {
    for (final e in row.entries)
      e.key: booleans.contains(e.key)
          ? e.value == 1
          : jsonFields.contains(e.key)
          ? jsonDecode(e.value as String)
          : moneyFields.contains(e.key) && e.value != null
          ? (e.value as num) / 1000
          : e.value,
  };
}

/// One owner, one SQLite helper. Initializers run in the requested module order.
class SqliteModuleContext {
  SqliteModuleContext({
    required this.helper,
    required this.catalog,
    required this.loadUsers,
    required this.mediaFactory,
  });
  final DatabaseHelper helper;
  final SqliteCatalogDatabase catalog;
  final Future<List<User>> Function() loadUsers;
  final MigratingMediaStorage Function(String, ReportsStorage) mediaFactory;
  static const order = ['reports', 'care_services', 'donations', 'events'];
  final Map<String, SqlModuleStore> stores = {};
  Future<void> _initialization = Future.value();
  void register(SqlModuleStore store) {
    if (stores.containsKey(store.namespace)) {
      throw StateError('Duplicate SQL module');
    }
    stores[store.namespace] = store;
  }

  Future<void> ensure(String namespace) {
    final result = _initialization.then((_) async {
      await catalog.initialize();
      for (final name in order) {
        final store = stores[name];
        if (store == null) {
          throw DatabaseFailure(
            'Le module $name doit être initialisé avant $namespace.',
          );
        }
        await store.initializeOnly();
        if (name == namespace) return;
      }
      throw StateError('Unknown module');
    });
    _initialization = result.then<void>(
      (_) {},
      onError: (Object e, StackTrace s) {},
    );
    return result;
  }

  Future<void> close() async {
    await _initialization;
    for (final s in stores.values) {
      await s.drain();
    }
    await catalog.close();
    catalog.dispose();
    for (final s in stores.values) {
      await s.storage.disposeStorage();
    }
    await helper.close();
  }
}

class SqlModuleStore {
  SqlModuleStore({
    required this.context,
    required this.namespace,
    required this.tables,
    required ReportsStorage legacy,
    required this.empty,
    required this.canonicalize,
    this.normalize,
  }) : storage = context.mediaFactory(namespace, legacy) {
    context.register(this);
  }
  final SqliteModuleContext context;
  final String namespace;
  final List<SqlTable> tables;
  final MigratingMediaStorage storage;
  final Map<String, dynamic> Function() empty;
  final Map<String, dynamic> Function(Map<String, dynamic>) canonicalize;
  final void Function(Map<String, dynamic>)? normalize;
  Future<void> _tail = Future.value();
  bool _initialized = false, _closed = false;
  String get marker => 'sembast_${namespace}_v1';
  String get counter => '${namespace}_next_id';
  Future<T> _run<T>(Future<T> Function() f) {
    final result = _tail.then((_) async {
      if (_closed) throw const DatabaseFailure('Le module SQL est fermé.');
      return f();
    });
    _tail = result.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return result;
  }

  Future<void> drain() => _tail;
  void dispose() {
    _closed = true;
  }

  Map<String, dynamic> _validate(Map<String, dynamic> raw) {
    final ids = <int>{};
    final next = raw['nextId'] as int;
    if (next < 1) throw const DatabaseFailure('Compteur de données invalide.');
    for (final t in tables) {
      final keys = <String>{};
      for (final value in raw[t.collection] as List) {
        final row = Map<String, dynamic>.from(value as Map);
        if (!keys.add(t.key(row))) {
          throw const DatabaseFailure('Identifiants dupliqués dans la source.');
        }
        for (final field in t.moneyFields) {
          final value = row[field];
          if (value != null &&
              (value is! num ||
                  !value.isFinite ||
                  (value * 1000 - (value * 1000).round()).abs() > 0.000001)) {
            throw const DatabaseFailure(
              'Montant source invalide : précision maximale de trois décimales.',
            );
          }
        }
        if (row['id'] is int) {
          final id = row['id'] as int;
          if (id < 1 || id >= next || !ids.add(id)) {
            throw const DatabaseFailure(
              'Identifiants ou compteur incohérents.',
            );
          }
        }
      }
    }
    final normalized = canonicalize(raw);
    normalize?.call(normalized);
    return normalized;
  }

  Iterable<String> _media(dynamic value, {bool reference = false}) sync* {
    if (reference && value is String && value.startsWith('media:')) {
      yield value;
    } else if (value is Map) {
      for (final e in value.entries) {
        yield* _media(
          e.value,
          reference: const {
            'photo',
            'image',
            'photos',
            'filePath',
            'documentPath',
          }.contains(e.key),
        );
      }
    } else if (value is List) {
      for (final v in value) {
        yield* _media(v, reference: reference);
      }
    }
  }

  Future<void> _importMedia(Map<String, dynamic> data) async {
    for (final ref in _media(data).toSet()) {
      await storage.importPhoto(ref);
    }
  }

  Future<Map<String, dynamic>> _load(DatabaseExecutor db) async {
    final d = empty();
    d['nextId'] = int.parse(
      await context.catalog.dao.metadata(db, counter) ?? '1',
    );
    for (final t in tables) {
      d[t.collection] = (await db.query(
        t.name,
        orderBy: t.primaryKey.join(','),
      )).map(t.decode).toList();
    }
    return d;
  }

  Future<void> initializeOnly() => _run(() async {
    if (_initialized) return;
    final dao = context.catalog.dao;
    final db = await context.helper.database;
    if (await dao.metadata(db, marker) != null) {
      _initialized = true;
      return;
    }
    final source = await storage.read();
    final data = _validate(
      source == null ? empty() : jsonDecode(source) as Map<String, dynamic>,
    );
    await _importMedia(data);
    final users = await context.loadUsers();
    await context.helper.transaction((tx) async {
      if (await dao.metadata(tx, marker) != null) return;
      for (final t in tables) {
        if ((await tx.rawQuery('SELECT COUNT(*) n FROM ${t.name}'))
                .single['n'] !=
            0) {
          throw const DatabaseFailure(
            'Destination non vide sans marqueur : aucun écrasement automatique.',
          );
        }
      }
      await dao.syncUsers(tx, users);
      await _persist(tx, empty(), data);
      for (final t in tables) {
        if ((await tx.rawQuery('SELECT COUNT(*) n FROM ${t.name}'))
                .single['n'] !=
            (data[t.collection] as List).length) {
          throw const DatabaseFailure(
            'Nombre de lignes transférées incorrect.',
          );
        }
      }
      await dao.verifyIntegrity(tx);
      final loaded = _validate(await _load(tx));
      if (_stable(loaded) != _stable(data)) {
        throw const DatabaseFailure(
          'Le transfert ne conserve pas toutes les valeurs.',
        );
      }
      await dao.putMetadata(
        tx,
        marker,
        jsonEncode({
          'counts': {
            for (final t in tables) t.name: (data[t.collection] as List).length,
          },
        }),
      );
    });
    _initialized = true;
  });
  String _stable(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data);
    for (final t in tables) {
      final rows =
          (data[t.collection] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList()
            ..sort((a, b) => t.key(a).compareTo(t.key(b)));
      copy[t.collection] = rows
          .map((r) => {for (final k in (r.keys.toList()..sort())) k: r[k]})
          .toList();
    }
    return jsonEncode({
      for (final k in (copy.keys.toList()..sort())) k: copy[k],
    });
  }

  Future<T> read<T>(FutureOr<T> Function(Map<String, dynamic>) action) async {
    await context.ensure(namespace);
    return _run(() async {
      final users = await context.loadUsers();
      return context.helper.transaction((tx) async {
        await context.catalog.dao.syncUsers(tx, users);
        return action(await _load(tx));
      });
    });
  }

  Future<T> mutate<T>(
    FutureOr<(Map<String, dynamic>, T)> Function(Map<String, dynamic>) action,
  ) async {
    await context.ensure(namespace);
    return _run(() async {
      final users = await context.loadUsers();
      return context.helper.transaction((tx) async {
        await context.catalog.dao.syncUsers(tx, users);
        final before = await _load(tx);
        final (raw, result) = await action(before);
        final after = _validate(raw);
        await _importMedia(after);
        await _persist(tx, before, after);
        if ((await tx.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
          throw const DatabaseFailure('Relation SQL invalide.');
        }
        return result;
      });
    });
  }

  Future<Map<String, Object?>> _encode(
    DatabaseExecutor db,
    SqlTable table,
    Map<String, dynamic> row,
  ) async {
    final encoded = table.encode(row);
    for (final e in table.optionalReferences.entries) {
      final found = await db.query(
        'veterinarian_availabilities',
        columns: ['id'],
        where: 'id=?',
        whereArgs: [row[e.value]],
        limit: 1,
      );
      encoded[e.key] = found.isEmpty ? null : row[e.value];
    }
    return encoded;
  }

  Future<void> _persist(
    DatabaseExecutor db,
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) async {
    Map<String, Map<String, dynamic>> rows(
      Map<String, dynamic> d,
      SqlTable t,
    ) => {
      for (final r in d[t.collection] as List)
        t.key(Map<String, dynamic>.from(r as Map)): Map<String, dynamic>.from(
          r,
        ),
    };
    for (final t in tables.reversed) {
      final a = rows(before, t), b = rows(after, t);
      for (final k in a.keys.where((k) => !b.containsKey(k))) {
        await db.delete(
          t.name,
          where: t.primaryKey.map((k) => '$k = ?').join(' AND '),
          whereArgs: t.primaryKey.map((column) => a[k]![column]).toList(),
        );
      }
    }
    for (final t in tables) {
      final a = rows(before, t), b = rows(after, t);
      for (final e in b.entries) {
        final old = a[e.key];
        if (old != null &&
            t.releaseStatuses.contains(old['status']) &&
            !t.releaseStatuses.contains(e.value['status'])) {
          await context.catalog.dao.upsert(
            db,
            t.name,
            await _encode(db, t, e.value),
            keys: t.primaryKey,
          );
        }
      }
    }
    for (final t in tables) {
      final a = rows(before, t), b = rows(after, t);
      for (final e in b.entries) {
        if (jsonEncode(a[e.key]) == jsonEncode(e.value)) continue;
        await context.catalog.dao.upsert(
          db,
          t.name,
          await _encode(db, t, e.value),
          keys: t.primaryKey,
        );
      }
    }
    await context.catalog.dao.putMetadata(
      db,
      counter,
      after['nextId'].toString(),
    );
  }
}
