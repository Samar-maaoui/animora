import 'dart:convert';

import 'package:sqflite/sqlite_api.dart';

import '../../users/models/user.dart';
import '../models/animal.dart';
import '../models/favorite.dart';
import '../models/adoption.dart';
import '../models/questionnaire_adoptant.dart';
import '../models/contrat_adoption.dart';
import '../models/suivi_adoption.dart';
import '../models/hebergement.dart';
import '../models/workflow_data.dart';
import '../repositories/local_catalog_database.dart';

/// SQL mapping only. Authorization and lifecycle rules remain in repositories.
class SqliteCatalogDao {
  Map<String, Object?> row(Map<String, dynamic> json) => {
    for (final e in json.entries)
      e.key: e.value is bool ? (e.value == true ? 1 : 0) : e.value as Object?,
  };
  Map<String, dynamic> decoded(
    Map<String, Object?> row,
    List<String> booleans,
  ) => {
    for (final e in row.entries)
      e.key: booleans.contains(e.key) ? e.value == 1 : e.value,
  };
  Future<void> upsert(
    DatabaseExecutor db,
    String table,
    Map<String, Object?> value, {
    List<String> keys = const ['id'],
  }) async {
    final where = keys.map((k) => '$k = ?').join(' AND '),
        args = keys.map((k) => value[k]).toList();
    if (await db.update(table, value, where: where, whereArgs: args) == 0) {
      await db.insert(table, value);
    }
  }

  Future<List<Animal>> getAllAnimals(DatabaseExecutor db) async =>
      (await db.query(
        'animals',
        orderBy: 'id',
      )).map((r) => Animal.fromJson(decoded(r, ['sterilized']))).toList();
  Future<Animal?> getAnimalById(DatabaseExecutor db, int id) async {
    final rows = await db.query(
      'animals',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : Animal.fromJson(decoded(rows.single, ['sterilized']));
  }

  Future<List<Favorite>> getFavoritesByUser(
    DatabaseExecutor db,
    String userId,
  ) async => (await db.query(
    'favorites',
    where: 'userId = ?',
    whereArgs: [userId],
    orderBy: 'addedAt DESC',
  )).map((r) => Favorite.fromJson(Map<String, dynamic>.from(r))).toList();
  Future<List<Adoption>> getAdoptions(
    DatabaseExecutor db, {
    String? userId,
    int? animalId,
  }) async => (await db.query(
    'adoptions',
    where: userId != null
        ? 'userId = ?'
        : animalId != null
        ? 'animalId = ?'
        : null,
    whereArgs: userId != null
        ? [userId]
        : animalId != null
        ? [animalId]
        : null,
    orderBy: 'applicationDate DESC',
  )).map((r) => Adoption.fromJson(Map<String, dynamic>.from(r))).toList();
  Future<Adoption?> getAdoptionById(DatabaseExecutor db, int id) async {
    final rows = await db.query(
      'adoptions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : Adoption.fromJson(Map<String, dynamic>.from(rows.single));
  }

  Future<QuestionnaireAdoptant?> getQuestionnaireByAdoption(
    DatabaseExecutor db,
    int id,
  ) async {
    final rows = await db.query(
      'adoption_questionnaires',
      where: 'adoptionId = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : QuestionnaireAdoptant.fromJson(
            decoded(rows.single, ['hasChildren', 'hasOtherAnimals']),
          );
  }

  Future<void> createAnimal(DatabaseExecutor db, Animal value) async {
    await db.insert('animals', row(value.toJson()));
  }

  Future<void> updateAnimal(DatabaseExecutor db, Animal value) async {
    if (await db.update(
          'animals',
          row(value.toJson()),
          where: 'id = ?',
          whereArgs: [value.id],
        ) !=
        1) {
      throw StateError('Animal introuvable');
    }
  }

  Future<void> deleteAnimal(DatabaseExecutor db, int id) async {
    await db.delete('animals', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addFavorite(DatabaseExecutor db, Favorite value) async {
    await db.insert('favorites', row(value.toJson()));
  }

  Future<void> removeFavorite(
    DatabaseExecutor db,
    String userId,
    int animalId,
  ) async {
    await db.delete(
      'favorites',
      where: 'userId = ? AND animalId = ?',
      whereArgs: [userId, animalId],
    );
  }

  Future<void> createAdoption(
    DatabaseExecutor db,
    Adoption value,
    User applicant,
  ) async {
    await db.insert('adoptions', {
      ...row(value.toJson()),
      'applicantSnapshot': jsonEncode(applicant.toJson()),
    });
  }

  Future<void> updateAdoptionStatus(DatabaseExecutor db, Adoption value) async {
    if (await db.update(
          'adoptions',
          row(value.toJson()),
          where: 'id = ?',
          whereArgs: [value.id],
        ) !=
        1) {
      throw StateError('Adoption introuvable');
    }
  }

  Future<void> createQuestionnaire(
    DatabaseExecutor db,
    QuestionnaireAdoptant value,
  ) async {
    await db.insert('adoption_questionnaires', row(value.toJson()));
  }

  Future<void> updateQuestionnaire(
    DatabaseExecutor db,
    QuestionnaireAdoptant value,
  ) async {
    if (await db.update(
          'adoption_questionnaires',
          row(value.toJson()),
          where: 'id = ? AND adoptionId = ?',
          whereArgs: [value.id, value.adoptionId],
        ) !=
        1) {
      throw StateError('Questionnaire introuvable');
    }
  }

  Future<Map<String, User>> readUsers(DatabaseExecutor db) async => {
    for (final r in await db.query('users'))
      r['id'] as String: User.fromJson(Map<String, dynamic>.from(r)),
  };
  Future<void> syncUsers(DatabaseExecutor db, Iterable<User> users) async {
    final authTable = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: "type='table' AND name='auth_accounts'",
    );
    final protected = authTable.isEmpty
        ? <String>{}
        : (await db.query(
            'auth_accounts',
            columns: ['userId'],
          )).map((r) => r['userId'] as String).toSet();
    for (final u in users) {
      if (protected.contains(u.id)) {
        continue; // Native auth is authoritative after migration.
      }
      await upsert(db, 'users', row(u.toJson()));
    }
  }

  Future<String?> metadata(DatabaseExecutor db, String key) async {
    final rows = await db.query(
      'database_metadata',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  Future<void> putMetadata(DatabaseExecutor db, String key, String value) =>
      upsert(
        db,
        'database_metadata',
        {'key': key, 'value': value},
        keys: ['key'],
      );
  Future<CatalogData> readCatalog(DatabaseExecutor db) async {
    final animals = await getAllAnimals(db);
    final w = WorkflowData(
      nextId: int.parse(await metadata(db, 'workflow_next_id') ?? '1'),
    );
    for (final r in await db.query('adoptions')) {
      final a = Adoption.fromJson(Map<String, dynamic>.from(r));
      w.adoptions[a.id] = a;
      w.applicants[a.id] = User.fromJson(
        jsonDecode(r['applicantSnapshot'] as String) as Map<String, dynamic>,
      );
    }
    for (final r in await db.query('adoption_questionnaires')) {
      final q = QuestionnaireAdoptant.fromJson(
        decoded(r, ['hasChildren', 'hasOtherAnimals']),
      );
      w.questionnaires[q.adoptionId] = q;
    }
    for (final r in await db.query('adoption_contracts')) {
      final x = ContratAdoption.fromJson(decoded(r, ['signed']));
      w.contracts[x.adoptionId] = x;
    }
    for (final r in await db.query('adoption_followups')) {
      final x = SuiviAdoption.fromJson(Map<String, dynamic>.from(r));
      w.followUps[x.id] = x;
    }
    for (final r in await db.query('foster_placements')) {
      final x = Hebergement.fromJson(Map<String, dynamic>.from(r));
      w.placements[x.id] = x;
    }
    return CatalogData(
      animals: {for (final a in animals) a.id: a},
      favorites: (await db.query('favorites'))
          .map((r) => Favorite.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
      nextId: int.parse(await metadata(db, 'animal_next_id') ?? '1'),
      workflow: w,
    );
  }

  Map<String, Map<String, Map<String, Object?>>> rows(CatalogData d) {
    Map<String, Map<String, Object?>> keyed(
      Iterable<Map<String, Object?>> values, {
      List<String> keys = const ['id'],
    }) => {
      for (final v in values) jsonEncode(keys.map((k) => v[k]).toList()): v,
    };
    return {
      'animals': keyed(d.animals.values.map((v) => row(v.toJson()))),
      'favorites': keyed(
        d.favorites.map((v) => row(v.toJson())),
        keys: ['userId', 'animalId'],
      ),
      'adoptions': keyed(
        d.workflow.adoptions.values.map(
          (v) => {
            ...row(v.toJson()),
            'applicantSnapshot': jsonEncode(
              d.workflow.applicants[v.id]!.toJson(),
            ),
          },
        ),
      ),
      'adoption_questionnaires': keyed(
        d.workflow.questionnaires.values.map((v) => row(v.toJson())),
      ),
      'adoption_contracts': keyed(
        d.workflow.contracts.values.map((v) => row(v.toJson())),
      ),
      'adoption_followups': keyed(
        d.workflow.followUps.values.map((v) => row(v.toJson())),
      ),
      'foster_placements': keyed(
        d.workflow.placements.values.map((v) => row(v.toJson())),
      ),
    };
  }

  /// Write row differences in FK order, inside the caller's SQLite transaction.
  Future<void> persistChanges(
    DatabaseExecutor db,
    CatalogData before,
    CatalogData after,
  ) async {
    final old = rows(before), fresh = rows(after);
    for (final table in [
      'favorites',
      'adoption_followups',
      'adoption_contracts',
      'adoption_questionnaires',
      'foster_placements',
      'adoptions',
      'animals',
    ]) {
      for (final key in old[table]!.keys.where(
        (k) => !fresh[table]!.containsKey(k),
      )) {
        final value = old[table]![key]!;
        if (table == 'favorites') {
          await removeFavorite(
            db,
            value['userId'] as String,
            value['animalId'] as int,
          );
        } else {
          await db.delete(table, where: 'id = ?', whereArgs: [value['id']]);
        }
      }
    }
    // Release unique partial-index claims before granting them to another row.
    for (final table in ['adoptions', 'foster_placements']) {
      for (final entry in fresh[table]!.entries) {
        final previous = old[table]![entry.key];
        if (previous != null && previous['status'] != entry.value['status']) {
          await upsert(db, table, entry.value);
        }
      }
    }
    for (final table in [
      'animals',
      'adoptions',
      'adoption_questionnaires',
      'adoption_contracts',
      'adoption_followups',
      'foster_placements',
      'favorites',
    ]) {
      for (final entry in fresh[table]!.entries) {
        if (jsonEncode(old[table]![entry.key]) == jsonEncode(entry.value)) {
          continue;
        }
        final existing = old[table]!.containsKey(entry.key);
        final value = entry.value;
        if (table == 'animals') {
          final animal = Animal.fromJson(decoded(value, ['sterilized']));
          if (existing) {
            await updateAnimal(db, animal);
          } else {
            await createAnimal(db, animal);
          }
        } else if (table == 'favorites') {
          if (existing) {
            await upsert(db, table, value, keys: ['userId', 'animalId']);
          } else {
            await addFavorite(
              db,
              Favorite.fromJson(Map<String, dynamic>.from(value)),
            );
          }
        } else if (table == 'adoption_questionnaires') {
          final q = QuestionnaireAdoptant.fromJson(
            decoded(value, ['hasChildren', 'hasOtherAnimals']),
          );
          if (existing) {
            await updateQuestionnaire(db, q);
          } else {
            await createQuestionnaire(db, q);
          }
        } else if (table == 'adoptions' && !existing) {
          await createAdoption(
            db,
            Adoption.fromJson(Map<String, dynamic>.from(value)),
            after.workflow.applicants[value['id']]!,
          );
        } else if (table == 'adoptions') {
          await updateAdoptionStatus(
            db,
            Adoption.fromJson(Map<String, dynamic>.from(value)),
          );
          if (old[table]![entry.key]!['applicantSnapshot'] !=
              value['applicantSnapshot']) {
            await db.update(
              table,
              {'applicantSnapshot': value['applicantSnapshot']},
              where: 'id = ?',
              whereArgs: [value['id']],
            );
          }
        } else {
          await upsert(db, table, value);
        }
      }
    }
    await putMetadata(db, 'animal_next_id', after.nextId.toString());
    await putMetadata(db, 'workflow_next_id', after.workflow.nextId.toString());
  }

  Future<void> verifyIntegrity(DatabaseExecutor db) async {
    if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
      throw StateError('Relations SQLite invalides');
    }
    final result = await db.rawQuery('PRAGMA integrity_check');
    if (result.length != 1 || result.single.values.single != 'ok') {
      throw StateError('Intégrité SQLite invalide');
    }
  }
}
