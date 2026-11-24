import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:animora/core/database/database_helper.dart';
import 'package:animora/core/database/database_constants.dart';
import 'package:animora/core/database/database_migrations.dart';
import 'package:animora/core/enums/adoption_status.dart';
import 'package:animora/core/enums/animal_status.dart';
import 'package:animora/core/enums/account_status.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/users/models/user.dart';
import 'package:animora/features/adoption/database/business_user_source.dart';
import 'package:animora/features/adoption/database/sqlite_catalog_database.dart';
import 'package:animora/features/adoption/repositories/sqlite_catalog_repositories.dart';
import 'package:animora/features/adoption/repositories/animal_repository.dart';
import 'package:animora/features/adoption/repositories/local_catalog_database.dart';
import 'package:animora/features/adoption/repositories/local_animal_repository.dart';
import 'package:animora/features/adoption/repositories/local_favorite_repository.dart';
import 'package:animora/features/adoption/repositories/local_adoption_workflow_repository.dart';
import 'package:animora/features/adoption/models/adoption.dart';
import 'package:animora/features/adoption/models/favorite.dart';
import 'package:animora/features/adoption/models/questionnaire_adoptant.dart';

import 'support/catalog_test_support.dart';
import 'support/auth_test_support.dart' show MemoryAuthStorage;

final sqlAdmin = DemoAccounts.users.firstWhere((u) => u.id == 'demo-admin');
final sqlCitizen = DemoAccounts.users.firstWhere((u) => u.id == 'demo-citizen');
final sqlOther = DemoAccounts.users.firstWhere((u) => u.id == 'demo-foster');
QuestionnaireAdoptant answers8({bool children = false}) =>
    QuestionnaireAdoptant(
      id: 0,
      adoptionId: 0,
      housingType: 'Maison avec jardin',
      hasChildren: children,
      hasOtherAnimals: false,
      experience: 'Déjà eu un animal',
      availableTime: 'Plus de deux heures',
    );

class SqliteHarness8 {
  SqliteHarness8({
    MemoryCatalogStorage? legacy,
    String? file,
    bool initializeUsers = true,
  }) : legacy = legacy ?? MemoryCatalogStorage() {
    helper = DatabaseHelper(
      factory: databaseFactoryFfi,
      pathOverride: file ?? inMemoryDatabasePath,
    );
    db = SqliteCatalogDatabase(
      this.legacy,
      helper: helper,
      loadBusinessUsers: () async =>
          initializeUsers ? users.values.toList() : [],
    );
    animals = SqliteAnimalRepository(db, () => actor);
    favorites = SqliteFavoriteRepository(db, () => actor);
    workflow = SqliteAdoptionWorkflowRepository(
      db,
      () => actor,
      listUsers: () async => users.values.toList(),
      clock: () => now,
    );
  }
  User? actor = sqlAdmin;
  final users = {for (final u in DemoAccounts.users) u.id: u};
  final DateTime now = DateTime.utc(2026, 11, 9, 12);
  final MemoryCatalogStorage legacy;
  late final DatabaseHelper helper;
  late final SqliteCatalogDatabase db;
  late final SqliteAnimalRepository animals;
  late final SqliteFavoriteRepository favorites;
  late final SqliteAdoptionWorkflowRepository workflow;
  Future<Adoption> apply({int animalId = 1}) {
    actor = sqlCitizen;
    return workflow.submitAdoption(
      animalId,
      answers8(),
      'Je souhaite accueillir cet animal et assurer ses soins.',
    );
  }

  Future<void> dispose() async {
    animals.dispose();
    favorites.dispose();
    workflow.dispose();
    await db.close();
    db.dispose();
  }
}

Future<MemoryCatalogStorage> legacyFixture8() async {
  final storage = MemoryCatalogStorage();
  final legacy = LocalCatalogDatabase(storage);
  User actor = sqlCitizen;
  final animals = LocalAnimalRepository(legacy, () => actor),
      favorite = LocalFavoriteRepository(legacy, () => actor),
      workflow = LocalAdoptionWorkflowRepository(
        legacy,
        () => actor,
        listUsers: () async => DemoAccounts.users,
        clock: () => DateTime.utc(2026, 11, 9, 12),
      );
  await animals.getAllAnimals();
  await favorite.addFavorite(1);
  final adoption = await workflow.submitAdoption(
    1,
    answers8(),
    'Je souhaite accueillir cet animal et assurer ses soins.',
  );
  actor = sqlAdmin;
  await workflow.decideAdoption(adoption.id, accept: true);
  actor = sqlCitizen;
  await workflow.signContract(adoption.id, confirmed: true);
  await workflow.addFollowUp(
    adoption.id,
    news: 'L’animal s’adapte très bien à sa nouvelle maison.',
    visitType: 'Nouvelles à domicile',
    photo: 'data:image/png;base64,AQ==',
  );
  actor = sqlAdmin;
  await workflow.assignPlacement(
    2,
    sqlOther.id,
    DateTime.utc(2026, 11, 8),
    remarks: 'Accueil temporaire de démonstration.',
  );
  animals.dispose();
  favorite.dispose();
  workflow.dispose();
  legacy.dispose();
  return storage;
}

void main() {
  setUpAll(sqfliteFfiInit);
  late SqliteHarness8 h;
  final failure = throwsA(isA<CatalogFailure>()),
      sqlFailure = throwsA(isA<DatabaseException>());
  setUp(() async {
    h = SqliteHarness8();
    await h.db.initialize();
  });
  tearDown(() async {
    await h.dispose();
  });
  test(
    'Fresh seed is normalized SQL and legacy preferences remain absent',
    () async {
      final db = await h.helper.database;
      expect((await db.query('animals')).length, 8);
      expect(h.legacy.value, isNull);
      expect(
        await h.db.dao.metadata(db, DatabaseConstants.catalogMigration),
        isNotNull,
      );
      expect(
        (await db.rawQuery('PRAGMA user_version')).single.values.single,
        DatabaseConstants.version,
      );
    },
  );
  test('Animal create getById getAll update delete use real rows', () async {
    final template = (await h.animals.getAnimalById(1))!;
    final created = await h.animals.addAnimal(
      template.copyWith(name: 'Nouvel animal'),
    );
    expect(created.id, 9);
    expect((await h.animals.getAnimalById(9))!.name, 'Nouvel animal');
    await h.animals.updateAnimal(
      created.copyWith(name: 'Animal modifié', weight: 12.5),
    );
    expect((await h.animals.getAnimalById(9))!.weight, 12.5);
    expect((await h.animals.getAllAnimals()).length, 9);
    await h.animals.deleteAnimal(9);
    expect(await h.animals.getAnimalById(9), isNull);
    expect(
      (await (await h.helper.database).query(
        'animals',
        where: 'id = ?',
        whereArgs: [9],
      )),
      isEmpty,
    );
  });
  test('Favorites add getByUser remove are scoped and idempotent', () async {
    h.actor = sqlCitizen;
    await h.favorites.addFavorite(1);
    await h.favorites.addFavorite(1);
    expect((await h.favorites.getFavorites()).length, 1);
    h.actor = sqlOther;
    expect(await h.favorites.getFavorites(), isEmpty);
    await h.favorites.addFavorite(1);
    h.actor = sqlCitizen;
    await h.favorites.removeFavorite(1);
    expect(await h.favorites.getFavorites(), isEmpty);
    final rows = await (await h.helper.database).query('favorites');
    expect(rows.single['userId'], sqlOther.id);
  });
  test('Animal deletion cascades favorites through actual FK', () async {
    h.actor = sqlCitizen;
    await h.favorites.addFavorite(1);
    h.actor = sqlAdmin;
    await h.animals.deleteAnimal(1);
    expect(await (await h.helper.database).query('favorites'), isEmpty);
  });
  test('Adoption create getById getByUser getByAnimal persist questionnaire and snapshot', () async {
    final a = await h.apply();
    expect((await h.workflow.getAdoption(a.id)).questionnaire.adoptionId, a.id);
    expect((await h.workflow.getByUser(sqlCitizen.id)).single.id, a.id);
    h.actor = sqlAdmin;
    expect((await h.workflow.getByAnimal(1)).single.id, a.id);
    final raw = (await (await h.helper.database).query('adoptions')).single;
    expect(raw['userId'], sqlCitizen.id);
    expect(jsonDecode(raw['applicantSnapshot'] as String)['id'], sqlCitizen.id);
  });
  test('Status accept atomically changes animal creates contract and rejects rivals', () async {
    final a = await h.apply();
    h.actor = sqlOther;
    final rival = await h.workflow.submitAdoption(
      1,
      answers8(),
      'Je peux accueillir cet animal dans un logement adapté.',
    );
    h.actor = sqlAdmin;
    await h.workflow.updateStatus(a.id, AdoptionStatus.ACCEPTED);
    expect(
      (await h.workflow.getAdoption(rival.id)).adoption.status,
      AdoptionStatus.REJECTED,
    );
    expect(
      (await h.animals.getAnimalById(1))!.status,
      AnimalStatus.PENDING_ADOPTION,
    );
    expect((await h.workflow.getContract(a.id)).signed, isFalse);
    h.actor = sqlCitizen;
    await h.workflow.signContract(a.id, confirmed: true);
    expect((await h.animals.getAnimalById(1))!.status, AnimalStatus.ADOPTED);
    expect((await h.workflow.getContract(a.id)).signed, isTrue);
  });
  test('Questionnaire update preserves IDs recalculates score and denies other user or decided request', () async {
    final a = await h.apply();
    final before = await h.workflow.getQuestionnaire(a.id);
    final updated = await h.workflow.updateQuestionnaire(
      a.id,
      answers8(children: true),
    );
    expect(updated.id, before.id);
    expect((await h.workflow.getQuestionnaire(a.id)).hasChildren, isTrue);
    final rows = await (await h.helper.database).query(
      'adoption_questionnaires',
    );
    expect(rows.length, 1);
    expect(rows.single['hasChildren'], 1);
    h.actor = sqlOther;
    await expectLater(
      h.workflow.updateQuestionnaire(a.id, answers8()),
      failure,
    );
    h.actor = sqlAdmin;
    await h.workflow.decideAdoption(a.id, accept: false);
    h.actor = sqlCitizen;
    await expectLater(
      h.workflow.updateQuestionnaire(a.id, answers8()),
      failure,
    );
  });
  test('Cancel adoption persists and cannot reopen', () async {
    final a = await h.apply();
    await h.workflow.updateStatus(a.id, AdoptionStatus.CANCELLED);
    expect(
      (await h.workflow.getAdoption(a.id)).adoption.status,
      AdoptionStatus.CANCELLED,
    );
    await expectLater(
      h.workflow.updateStatus(a.id, AdoptionStatus.PENDING),
      failure,
    );
  });
  test('FK rejects nonexistent user animal and adoption parents', () async {
    final db = await h.helper.database;
    await expectLater(
      db.insert('favorites', {
        'userId': 'missing',
        'animalId': 1,
        'addedAt': h.now.toIso8601String(),
      }),
      sqlFailure,
    );
    await expectLater(
      db.insert('favorites', {
        'userId': sqlCitizen.id,
        'animalId': 999,
        'addedAt': h.now.toIso8601String(),
      }),
      sqlFailure,
    );
    await expectLater(
      h.db.dao.createQuestionnaire(
        db,
        QuestionnaireAdoptant(
          id: 1,
          adoptionId: 999,
          housingType: 'Maison avec jardin',
          hasChildren: false,
          hasOtherAnimals: false,
          experience: 'Déjà eu un animal',
          availableTime: 'Plus de deux heures',
        ),
      ),
      sqlFailure,
    );
  });
  test(
    'UNIQUE favorite and one questionnaire per adoption enforced by SQLite',
    () async {
      h.actor = sqlCitizen;
      await h.favorites.addFavorite(1);
      final db = await h.helper.database;
      await expectLater(
        h.db.dao.addFavorite(
          db,
          Favorite(userId: sqlCitizen.id, animalId: 1, addedAt: h.now),
        ),
        sqlFailure,
      );
      final a = await h.apply();
      final q = (await db.query('adoption_questionnaires')).single;
      await expectLater(
        db.insert('adoption_questionnaires', {...q, 'id': 999}),
        sqlFailure,
      );
      expect((await h.workflow.getQuestionnaire(a.id)).adoptionId, a.id);
    },
  );
  test(
    'UNIQUE pending application is enforced independently of repository',
    () async {
      final a = await h.apply();
      final db = await h.helper.database;
      final raw = (await db.query('adoptions')).single;
      await expectLater(
        db.insert('adoptions', {...raw, 'id': 999}),
        sqlFailure,
      );
      expect((await h.workflow.getAdoptions()).single.id, a.id);
    },
  );
  test(
    'CHECK constraints reject negative age invalid weight enum and booleans',
    () async {
      final db = await h.helper.database;
      for (final bad in [
        {'age': -1},
        {'age': 1.5},
        {'weight': 0},
        {'sterilized': 2},
        {'status': 'INVALID'},
      ]) {
        await expectLater(
          db.update('animals', bad, where: 'id = ?', whereArgs: [1]),
          sqlFailure,
        );
      }
      expect((await h.animals.getAnimalById(1))!.id, 1);
    },
  );
  test('Database transaction rollback leaves no partial rows', () async {
    final db = await h.helper.database;
    final original = (await h.animals.getAnimalById(1))!.name;
    await expectLater(
      db.transaction((tx) async {
        await tx.update(
          'animals',
          {'name': 'Modification annulée'},
          where: 'id = ?',
          whereArgs: [1],
        );
        await tx.insert('favorites', {
          'userId': 'missing',
          'animalId': 1,
          'addedAt': h.now.toIso8601String(),
        });
      }),
      sqlFailure,
    );
    expect((await h.animals.getAnimalById(1))!.name, original);
  });
  test('Failure after adoption status update rolls back contract animal and counter', () async {
    final a = await h.apply();
    h.actor = sqlAdmin;
    final db = await h.helper.database;
    final counter = await h.db.dao.metadata(db, 'workflow_next_id');
    await db.execute(
      "CREATE TRIGGER fail_animal BEFORE UPDATE ON animals BEGIN SELECT RAISE(ABORT,'test rollback'); END",
    );
    await expectLater(h.workflow.decideAdoption(a.id, accept: true), failure);
    expect(
      (await h.workflow.getAdoption(a.id)).adoption.status,
      AdoptionStatus.PENDING,
    );
    expect(await db.query('adoption_contracts'), isEmpty);
    expect(await h.db.dao.metadata(db, 'workflow_next_id'), counter);
    await db.execute('DROP TRIGGER fail_animal');
    await h.workflow.decideAdoption(a.id, accept: true);
    expect((await h.workflow.getContract(a.id)).signed, isFalse);
  });
  test(
    'Deleting an adopted animal is rejected by both business layer and FK',
    () async {
      await h.apply();
      h.actor = sqlAdmin;
      await expectLater(h.animals.deleteAnimal(1), failure);
      await expectLater(
        (await h.helper.database).delete(
          'animals',
          where: 'id = ?',
          whereArgs: [1],
        ),
        sqlFailure,
      );
    },
  );
  test('Concurrent duplicate applications only create one questionnaire and application', () async {
    h.actor = sqlCitizen;
    final results = await Future.wait(
      List.generate(
        4,
        (_) => h.workflow
            .submitAdoption(
              1,
              answers8(),
              'Je peux accueillir cet animal et assurer son bien-être.',
            )
            .then<Object>((x) => x, onError: (Object e) => e),
      ),
    );
    expect(results.whereType<Adoption>().length, 1);
    final db = await h.helper.database;
    expect((await db.query('adoptions')).length, 1);
    expect((await db.query('adoption_questionnaires')).length, 1);
  });
  test(
    'Repositories enforce owner active account and ADMIN guards on SQL paths',
    () async {
      final a = await h.apply();
      h.actor = sqlOther;
      await expectLater(h.workflow.getAdoption(a.id), failure);
      await expectLater(h.workflow.getByUser(sqlCitizen.id), failure);
      await expectLater(h.workflow.getByAnimal(1), failure);
      await expectLater(h.animals.deleteAnimal(2), failure);
      h.actor = sqlCitizen.copyWith(status: AccountStatus.blocked);
      await expectLater(h.favorites.getFavorites(), failure);
      await expectLater(h.animals.getAllAnimals(), failure);
    },
  );
  test(
    'New business profile syncs before a foreign-key-dependent write',
    () async {
      final user = User(
        id: 'new-user',
        firstName: 'Nouveau',
        lastName: 'Profil',
        email: 'new@animora.test',
        city: 'Tunis',
        profile: sqlCitizen.profile,
        status: AccountStatus.active,
        createdAt: h.now,
      );
      h.users[user.id] = user;
      h.actor = user;
      await h.favorites.addFavorite(1);
      expect(
        (await (await h.helper.database).query(
          'users',
          where: 'id = ?',
          whereArgs: [user.id],
        )).single['email'],
        user.email,
      );
    },
  );
  test(
    'Business profile update does not rewrite historical applicant snapshot',
    () async {
      final a = await h.apply();
      final oldName = sqlCitizen.fullName;
      h.users[sqlCitizen.id] = sqlCitizen.copyWith(firstName: 'Nouveau prénom');
      h.actor = h.users[sqlCitizen.id];
      final detail = await h.workflow.getAdoption(a.id);
      expect(detail.applicant.fullName, oldName);
      expect(
        (await (await h.helper.database).query(
          'users',
          where: 'id = ?',
          whereArgs: [sqlCitizen.id],
        )).single['firstName'],
        'Nouveau prénom',
      );
    },
  );
  test('Full legacy migration preserves IDs all counts photos dates and old source', () async {
    final legacy = await legacyFixture8();
    final original = legacy.value!;
    final imported = SqliteHarness8(legacy: legacy);
    addTearDown(imported.dispose);
    await imported.db.initialize();
    final db = await imported.helper.database;
    final expected = {
      'users': 7,
      'animals': 8,
      'favorites': 1,
      'adoptions': 1,
      'adoption_questionnaires': 1,
      'adoption_contracts': 1,
      'adoption_followups': 1,
      'foster_placements': 1,
    };
    for (final e in expected.entries) {
      expect(
        (await db.rawQuery('SELECT COUNT(*) AS n FROM ${e.key}')).single['n'],
        e.value,
      );
    }
    expect(legacy.value, original);
    expect(
      (await db.query('adoption_followups')).single['photo'],
      'data:image/png;base64,AQ==',
    );
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    final source = jsonDecode(original) as Map<String, dynamic>;
    final restored = await imported.db.read((d) => d);
    expect(restored.nextId, source['nextId']);
    expect(restored.workflow.nextId, source['workflow']['nextId']);
    expect(
      restored.workflow.applicants.values.single.fullName,
      sqlCitizen.fullName,
    );
  });
  test(
    'Migration marker makes relaunch idempotent and SQL becomes authority',
    () async {
      final original = h.legacy.value;
      final added = await h.animals.addAnimal(
        (await h.animals.getAnimalById(1))!.copyWith(name: 'Après migration'),
      );
      h.legacy.value = 'invalid legacy must not be reread';
      final second = SqliteCatalogDatabase(
        h.legacy,
        helper: h.helper,
        loadBusinessUsers: () async => h.users.values.toList(),
      );
      await second.initialize();
      expect((await second.read((d) => d.animals.length)), 9);
      expect(
        (await second.read((d) => d.animals[added.id]!.name)),
        'Après migration',
      );
      expect(original, isNull);
    },
  );
  test(
    'Malformed legacy and orphaned favorites abort without marker or writes',
    () async {
      for (final source in [
        'broken',
        jsonEncode({
          'version': 1,
          'nextId': 1,
          'animals': [],
          'favorites': [
            {
              'userId': sqlCitizen.id,
              'animalId': 99,
              'addedAt': h.now.toIso8601String(),
            },
          ],
        }),
      ]) {
        final legacy = MemoryCatalogStorage(source),
            broken = SqliteHarness8(legacy: MemoryCatalogStorage(source));
        addTearDown(broken.dispose);
        await expectLater(broken.db.initialize(), failure);
        final db = await broken.helper.database;
        expect(
          await broken.db.dao.metadata(db, DatabaseConstants.catalogMigration),
          isNull,
        );
        expect(await db.query('users'), isEmpty);
        expect(await db.query('animals'), isEmpty);
        expect(broken.legacy.value, legacy.value);
      }
    },
  );
  test(
    'Duplicate legacy identifiers are rejected rather than overwritten',
    () async {
      final legacy = await legacyFixture8();
      final parsed = jsonDecode(legacy.value!) as Map<String, dynamic>;
      parsed['animals'].add(parsed['animals'].first);
      legacy.value = jsonEncode(parsed);
      final broken = SqliteHarness8(legacy: legacy);
      addTearDown(broken.dispose);
      await expectLater(broken.db.initialize(), failure);
      expect(await (await broken.helper.database).query('animals'), isEmpty);
    },
  );
  test(
    'Mid-import SQL failure rolls back every row and retries after repair',
    () async {
      final legacy = await legacyFixture8(),
          imported = SqliteHarness8(legacy: MemoryCatalogStorage());
      addTearDown(imported.dispose);
      imported.legacy.value = legacy.value;
      final original = legacy.value;
      final db = await imported.helper.database;
      await db.execute(
        "CREATE TRIGGER fail_import BEFORE INSERT ON adoption_contracts BEGIN SELECT RAISE(ABORT,'test import'); END",
      );
      await expectLater(imported.db.initialize(), failure);
      for (final table in DatabaseConstants.tables) {
        expect(await db.query(table), isEmpty);
      }
      expect(
        await imported.db.dao.metadata(db, DatabaseConstants.catalogMigration),
        isNull,
      );
      expect(imported.legacy.value, original);
      await db.execute('DROP TRIGGER fail_import');
      await imported.db.initialize();
      expect((await db.query('adoptions')).length, 1);
      expect(
        await imported.db.dao.metadata(db, DatabaseConstants.catalogMigration),
        isNotNull,
      );
    },
  );
  test(
    'Nonempty unmarked SQL database is never overwritten by importer',
    () async {
      final blocked = SqliteHarness8();
      addTearDown(blocked.dispose);
      final db = await blocked.helper.database;
      await blocked.db.dao.syncUsers(db, [sqlCitizen]);
      await expectLater(blocked.db.initialize(), failure);
      expect((await db.query('users')).single['id'], sqlCitizen.id);
      expect(await db.query('animals'), isEmpty);
    },
  );
  test(
    'Business users exclude credentials hashes salts and persisted session',
    () async {
      final auth = MemoryAuthStorage(
        jsonEncode({
          'version': 1,
          'sessionId': 'SECRET_SESSION',
          'accounts': [
            {
              'user': sqlCitizen.toJson(),
              'credential': {
                'hash': 'SECRET_HASH',
                'salt': 'SECRET_SALT',
                'iterations': 120000,
              },
            },
          ],
        }),
      );
      final source = BusinessUserSource(auth);
      final profiles = await source.read();
      expect(profiles.single.id, sqlCitizen.id);
      final helper = DatabaseHelper(
        factory: databaseFactoryFfi,
        pathOverride: inMemoryDatabasePath,
      );
      final sql = SqliteCatalogDatabase(
        MemoryCatalogStorage(),
        helper: helper,
        loadBusinessUsers: source.read,
      );
      await sql.initialize();
      final rows = await (await helper.database).query('users');
      final serialized = jsonEncode(rows);
      for (final secret in ['SECRET_SESSION', 'SECRET_HASH', 'SECRET_SALT']) {
        expect(serialized.contains(secret), isFalse);
      }
      final columns = (await (await helper.database).rawQuery(
        'PRAGMA table_info(users)',
      )).map((r) => r['name']);
      expect(columns, isNot(contains('password')));
      expect(columns, isNot(contains('credential')));
      expect(jsonDecode(auth.value!)['sessionId'], 'SECRET_SESSION');
      await sql.close();
      sql.dispose();
    },
  );
  test('Real file close reopen keeps SQL rows IDs and foreign keys', () async {
    final dir = await Directory.systemTemp.createTemp('animora8a-');
    final file = path.join(dir.path, 'animora.db');
    final first = SqliteHarness8(file: file);
    await first.db.initialize();
    final newAnimal = await first.animals.addAnimal(
      (await first.animals.getAnimalById(1))!
          .copyWith(name: 'Persistant sur disque'),
    );
    first.actor = sqlCitizen;
    await first.favorites.addFavorite(newAnimal.id);
    await first.dispose();
    final reopened = SqliteHarness8(
      file: file,
      legacy: MemoryCatalogStorage('not reread'),
    );
    await reopened.db.initialize();
    reopened.actor = sqlCitizen;
    expect(
      (await reopened.animals.getAnimalById(newAnimal.id))!.name,
      'Persistant sur disque',
    );
    expect(
      (await reopened.favorites.getFavorites()).single.animalId,
      newAnimal.id,
    );
    expect(
      (await (await reopened.helper.database).rawQuery('PRAGMA foreign_keys'))
          .single
          .values
          .single,
      1,
    );
    await reopened.dispose();
    await File(file).delete();
    await dir.delete();
  });
  test(
    'Schema v1 upgrades to v2 indexes without losing business row',
    () async {
      final dir = await Directory.systemTemp.createTemp('animora8a-upgrade-');
      final file = path.join(dir.path, 'animora.db');
      final old = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, v) => DatabaseMigrations.upgrade(db, 0, 1),
        ),
      );
      await h.db.dao.createAnimal(old, (await h.animals.getAnimalById(1))!);
      await old.close();
      final helper = DatabaseHelper(
        factory: databaseFactoryFfi,
        pathOverride: file,
      );
      final db = await helper.database;
      expect(
        (await db.rawQuery('PRAGMA user_version')).single.values.single,
        DatabaseConstants.version,
      );
      expect((await db.query('animals')).single['id'], 1);
      expect(
        (await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_pending_adoption'",
        )),
        hasLength(1),
      );
      await helper.close();
      await File(file).delete();
      await dir.delete();
    },
  );
  test(
    'Queued favorite cannot cross account switch during SQL initialization',
    () async {
      final gate = Completer<void>();
      final pending = h.db.readSql((db, dao) => gate.future);
      h.actor = sqlCitizen;
      final favorite = h.favorites.addFavorite(1);
      h.actor = sqlOther;
      gate.complete();
      await pending;
      await expectLater(favorite, failure);
      expect(await h.favorites.getFavorites(), isEmpty);
    },
  );
  test('Full relational fixture survives file reopen and exports a fictitious proof database', () async {
    final legacy = await legacyFixture8();
    final original = legacy.value;
    final dir = await Directory.systemTemp.createTemp('animora8a-proof-');
    final file = path.join(dir.path, 'animora.db');
    final first = SqliteHarness8(file: file, legacy: legacy);
    await first.db.initialize();
    await first.dispose();
    final second = SqliteHarness8(
      file: file,
      legacy: MemoryCatalogStorage('not read'),
    );
    await second.db.initialize();
    final db = await second.helper.database;
    expect((await db.query('adoptions')).length, 1);
    expect((await db.query('adoption_contracts')).single['signed'], 1);
    expect((await db.query('adoption_followups')).length, 1);
    expect((await db.query('foster_placements')).length, 1);
    expect((await db.query('favorites')).length, 1);
    await second.db.dao.verifyIntegrity(db);
    await second.dispose();
    await Directory('output/database').create(recursive: true);
    await File(file).copy('output/database/animora-demo.db');
    expect(legacy.value, original);
    await File(file).delete();
    await dir.delete();
  });
}
