import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqlite_api.dart';

import '../../../core/database/database_helper.dart';
import '../../adoption/database/sqlite_catalog_dao.dart';
import '../../users/models/user.dart';
import '../models/auth_requests.dart';
import 'auth_snapshot.dart';
import 'auth_vault.dart';
import 'local_auth_storage.dart';

/// Relational profiles in existing users; credentials/session in native vault.
/// Immutable vault records are staged before the SQL commit. Failed commits may
/// leave unreferenced vault entries, never a half-published SQL/session state.
class SqliteAuthStorage
    implements RefreshableAuthStorage, AuthRecoveryProfileSource {
  SqliteAuthStorage({
    required this.helper,
    required this.legacy,
    required this.vault,
    this.prepareCatalog,
  });
  final DatabaseHelper helper;
  final AuthStorage legacy;
  final AuthVault vault;
  final Future<void> Function()? prepareCatalog;
  static const marker = 'auth_preferences_v1', stateKey = 'auth_state_v1';
  final dao = SqliteCatalogDao();
  Future<void> _tail = Future.value();
  int? _revision;
  bool _initialized = false;
  Future<T> _run<T>(Future<T> Function() action) {
    final task = _tail.then((_) => action());
    _tail = task.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return task;
  }

  Future<void> drain() => _tail;
  @override
  Future<List<User>> readRecoveryProfiles() => _run(() async {
    await _ensure();
    return (await dao.readUsers(await helper.database)).values.toList();
  });
  Never _fail(String message, String code) =>
      throw AuthFailure(AuthFailureCode.storage, message, diagnostic: code);
  String _reference(String kind) =>
      'animora.auth.$kind.${List.generate(24, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  Future<String> _stage(String kind, String value) async {
    final ref = _reference(kind);
    await vault.write(ref, value);
    if (await vault.read(ref) != value) {
      _fail(
        'Le stockage sécurisé n’a pas confirmé l’écriture. Les comptes existants sont conservés.',
        'AUTH_VAULT_VERIFY',
      );
    }
    return ref;
  }

  Future<Map<String, dynamic>> _state(DatabaseExecutor db) async {
    final raw = await dao.metadata(db, stateKey);
    if (raw == null) {
      _fail(
        'Métadonnées des comptes absentes. Aucune réinitialisation automatique.',
        'AUTH_SQL_STATE_MISSING',
      );
    }
    final state = jsonDecode(raw) as Map<String, dynamic>;
    if (state['revision'] is! int || state['sessionRef'] is! String) {
      _fail('Métadonnées des comptes invalides.', 'AUTH_SQL_STATE_INVALID');
    }
    return state;
  }

  Future<void> _ensure() async {
    if (_initialized) return;
    final db = await helper.database;
    if (await dao.metadata(db, marker) != null) {
      _initialized = true;
      return;
    }
    await prepareCatalog?.call();
    final raw = await legacy.read();
    final source = raw == null
        ? const AuthSnapshot({}, null)
        : AuthSnapshot.decode(raw);
    final refs = <String, String>{};
    for (final e in source.accounts.entries) {
      refs[e.key] = await _stage(
        'credential',
        jsonEncode(e.value.password.toJson()),
      );
    }
    final sessionRef = await _stage('session', jsonEncode(source.sessionId));
    await helper.transaction((tx) async {
      if (await dao.metadata(tx, marker) != null) return;
      if ((await tx.query('auth_accounts', limit: 1)).isNotEmpty) {
        _fail(
          'Comptes SQLite présents sans validation de migration. Aucun écrasement.',
          'AUTH_SQL_UNMARKED',
        );
      }
      for (final e in source.accounts.entries) {
        final found = await tx.query(
          'users',
          where: 'id=?',
          whereArgs: [e.key],
        );
        if (found.isNotEmpty) {
          final existing = User.fromJson(
            Map<String, dynamic>.from(found.single),
          );
          if (jsonEncode(existing.toJson()) !=
              jsonEncode(e.value.user.toJson())) {
            _fail(
              'Un profil SQLite diffère de sa source sans date de modification comparable. Migration arrêtée pour préserver les deux versions.',
              'AUTH_SQL_PROFILE_CONFLICT',
            );
          }
        } else {
          await dao.upsert(tx, 'users', e.value.user.toJson());
        }
        await tx.insert('auth_accounts', {
          'userId': e.key,
          'credentialRef': refs[e.key],
          'revision': 1,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
        final checked = await tx.query(
          'users',
          where: 'id=?',
          whereArgs: [e.key],
        );
        if (jsonEncode(
              User.fromJson(Map<String, dynamic>.from(checked.single)).toJson(),
            ) !=
            jsonEncode(e.value.user.toJson())) {
          _fail(
            'Vérification des profils importés impossible.',
            'AUTH_SQL_VERIFY',
          );
        }
      }
      if ((await tx.rawQuery('SELECT COUNT(*) n FROM auth_accounts'))
              .single['n'] !=
          source.accounts.length) {
        _fail('Comptage des comptes importés incorrect.', 'AUTH_SQL_COUNT');
      }
      await dao.verifyIntegrity(tx);
      await dao.putMetadata(
        tx,
        stateKey,
        jsonEncode({'revision': 1, 'sessionRef': sessionRef}),
      );
      // Marker last in same transaction. Legacy document is never altered.
      await dao.putMetadata(
        tx,
        marker,
        jsonEncode({
          'count': source.accounts.length,
          'source': raw == null ? 'fresh_empty' : 'preferences',
          'validated': true,
        }),
      );
    });
    _initialized = true;
  }

  Future<(AuthSnapshot, int)> _snapshot() async {
    final bundle = await helper.transaction((tx) async {
      final state = await _state(tx);
      final rows = await tx.rawQuery(
        'SELECT u.*,a.credentialRef FROM users u JOIN auth_accounts a ON a.userId=u.id ORDER BY u.id',
      );
      return (state, rows);
    });
    final accounts = <String, AuthAccount>{};
    for (final r in bundle.$2) {
      final user = User.fromJson(Map<String, dynamic>.from(r));
      final raw = await vault.read(r['credentialRef'] as String);
      if (raw == null) {
        _fail(
          'Une empreinte sécurisée est indisponible. Aucune donnée source n’est effacée.',
          'AUTH_VAULT_CREDENTIAL_MISSING',
        );
      }
      final password = jsonDecode(raw) as Map<String, dynamic>;
      final checked = AuthSnapshot.decode(
        jsonEncode({
          'version': 1,
          'sessionId': null,
          'accounts': [
            {'user': user.toJson(), 'credential': password},
          ],
        }),
      );
      accounts[user.id] = checked.accounts[user.id]!;
    }
    final sessionRaw = await vault.read(bundle.$1['sessionRef'] as String);
    if (sessionRaw == null) {
      _fail(
        'La session sécurisée est indisponible. Réessayez après déverrouillage du stockage sécurisé.',
        'AUTH_VAULT_SESSION_MISSING',
      );
    }
    final id = jsonDecode(sessionRaw);
    if (id != null && id is! String) {
      _fail('Session sécurisée invalide.', 'AUTH_VAULT_SESSION_INVALID');
    }
    return (
      AuthSnapshot(accounts, accounts.containsKey(id) ? id as String? : null),
      bundle.$1['revision'] as int,
    );
  }

  @override
  Future<String?> read() => _run(() async {
    await _ensure();
    final (snapshot, revision) = await _snapshot();
    _revision = revision;
    return snapshot.encode();
  });
  @override
  Future<void> write(String value) => _run(() async {
    await _ensure();
    final after = AuthSnapshot.decode(value);
    final (before, revision) = await _snapshot();
    if (_revision != null && _revision != revision) {
      _fail(
        'Les comptes ont changé. Réessayez pour relire leur état actuel.',
        'AUTH_SQL_CONCURRENT',
      );
    }
    // Accounts deleted by an administrator (rejection or deletion).
    final removed = before.accounts.keys
        .where((id) => !after.accounts.containsKey(id))
        .toList();
    final refs = <String, String>{};
    for (final e in after.accounts.entries) {
      final old = before.accounts[e.key];
      if (old == null ||
          jsonEncode(old.password.toJson()) !=
              jsonEncode(e.value.password.toJson())) {
        refs[e.key] = await _stage(
          'credential',
          jsonEncode(e.value.password.toJson()),
        );
      }
    }
    final sessionRef = await _stage('session', jsonEncode(after.sessionId));
    final removedRefs = <String>[];
    await helper.transaction((tx) async {
      if ((await _state(tx))['revision'] != revision) {
        _fail(
          'Écriture concurrente détectée. Réessayez.',
          'AUTH_SQL_CONCURRENT',
        );
      }
      for (final e in after.accounts.entries) {
        final old = before.accounts[e.key];
        if (old == null) {
          final rows = await tx.query(
            'users',
            where: 'id=?',
            whereArgs: [e.key],
          );
          if (rows.isNotEmpty &&
              jsonEncode(
                    User.fromJson(Map<String, dynamic>.from(rows.single))
                        .toJson(),
                  ) !=
                  jsonEncode(e.value.user.toJson())) {
            _fail(
              'Un profil existant a changé. Aucun écrasement ; réessayez.',
              'AUTH_SQL_PROFILE_CONFLICT',
            );
          }
        }
        if (old == null ||
            jsonEncode(old.user.toJson()) !=
                jsonEncode(e.value.user.toJson())) {
          await dao.upsert(tx, 'users', e.value.user.toJson());
        }
        if (old == null) {
          await tx.insert('auth_accounts', {
            'userId': e.key,
            'credentialRef': refs[e.key],
            'revision': 1,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          });
        } else if (jsonEncode(old.toJson()) != jsonEncode(e.value.toJson())) {
          final row = (await tx.query(
            'auth_accounts',
            where: 'userId=?',
            whereArgs: [e.key],
          )).single;
          await tx.update(
            'auth_accounts',
            {
              'credentialRef': refs[e.key] ?? row['credentialRef'],
              'revision': (row['revision'] as int) + 1,
              'updatedAt': DateTime.now().toUtc().toIso8601String(),
            },
            where: 'userId=?',
            whereArgs: [e.key],
          );
        }
      }
      for (final id in removed) {
        final rows = await tx.query(
          'auth_accounts',
          where: 'userId=?',
          whereArgs: [id],
        );
        if (rows.isNotEmpty) {
          removedRefs.add(rows.single['credentialRef'] as String);
        }
        await tx.delete('auth_accounts', where: 'userId=?', whereArgs: [id]);
        try {
          // Favorites cascade; any business history (adoptions, reports,
          // donations, events, services) is ON DELETE RESTRICT → refused,
          // and the whole transaction is rolled back.
          await tx.delete('users', where: 'id=?', whereArgs: [id]);
        } on DatabaseException catch (error) {
          if (error.toString().toLowerCase().contains('foreign key')) {
            throw const AuthFailure(
              AuthFailureCode.forbidden,
              'Ce compte a un historique dans l’application (adoptions, '
              'signalements, dons, événements ou services) : le supprimer '
              'effacerait ces données. Bloquez-le plutôt.',
              diagnostic: 'AUTH_SQL_DELETE_HISTORY',
            );
          }
          rethrow;
        }
      }
      await dao.verifyIntegrity(tx);
      await dao.putMetadata(
        tx,
        stateKey,
        jsonEncode({'revision': revision + 1, 'sessionRef': sessionRef}),
      );
    });
    _revision = revision + 1;
    // Best effort: wipe the password hash of deleted accounts.
    for (final ref in removedRefs) {
      try {
        await vault.write(ref, '');
      } catch (_) {}
    }
  });
}
