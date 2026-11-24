import '../../../core/enums/account_status.dart';
import '../../../core/enums/user_profile.dart';
import '../../../core/enums/adoption_status.dart';
import '../../users/models/user.dart';
import '../models/animal.dart';
import '../models/favorite.dart';
import '../models/adoption.dart';
import '../database/sqlite_catalog_database.dart';
import 'animal_repository.dart';
import 'local_animal_repository.dart';
import 'local_favorite_repository.dart';
import 'local_adoption_workflow_repository.dart';

User sqliteActor(
  User? Function() currentUser, {
  String? expected,
  bool admin = false,
}) {
  final u = currentUser();
  if (u == null ||
      u.status != AccountStatus.active ||
      (expected != null && u.id != expected) ||
      (admin && u.profile != UserProfile.admin)) {
    throw const CatalogFailure('Session active et autorisations requises.');
  }
  return u;
}

/// Inherited mutations run through the relational transaction adapter; no rule fork.
class SqliteAnimalRepository extends LocalAnimalRepository {
  SqliteAnimalRepository(this.sql, User? Function() user) : super(sql, user);
  final SqliteCatalogDatabase sql;
  @override
  Future<List<Animal>> getAllAnimals() async {
    final uid = sqliteActor(currentUser).id;
    return sql.readSql((db, dao) async {
      sqliteActor(currentUser, expected: uid);
      final rows = await dao.getAllAnimals(db);
      sqliteActor(currentUser, expected: uid);
      return List.unmodifiable(rows);
    });
  }

  @override
  Future<Animal?> getAnimalById(int id) async {
    final uid = sqliteActor(currentUser).id;
    return sql.readSql((db, dao) async {
      sqliteActor(currentUser, expected: uid);
      final row = await dao.getAnimalById(db, id);
      sqliteActor(currentUser, expected: uid);
      return row;
    });
  }
}

class SqliteFavoriteRepository extends LocalFavoriteRepository {
  SqliteFavoriteRepository(this.sql, User? Function() user) : super(sql, user);
  final SqliteCatalogDatabase sql;
  @override
  Future<List<Favorite>> getFavorites() async {
    final uid = sqliteActor(currentUser).id;
    return sql.readSql((db, dao) async {
      sqliteActor(currentUser, expected: uid);
      final rows = await dao.getFavoritesByUser(db, uid);
      sqliteActor(currentUser, expected: uid);
      return List.unmodifiable(rows);
    });
  }
}

class SqliteAdoptionWorkflowRepository extends LocalAdoptionWorkflowRepository {
  SqliteAdoptionWorkflowRepository(
    this.sql,
    User? Function() user, {
    super.listUsers,
    super.clock,
  }) : super(sql, user);
  final SqliteCatalogDatabase sql;
  @override
  Future<List<Adoption>> getAdoptions() async {
    final actor = sqliteActor(currentUser);
    return sql.readSql((db, dao) async {
      sqliteActor(currentUser, expected: actor.id);
      final rows = await dao.getAdoptions(
        db,
        userId: actor.profile == UserProfile.admin ? null : actor.id,
      );
      sqliteActor(currentUser, expected: actor.id);
      return rows;
    });
  }

  Future<List<Adoption>> getByUser(String userId) async {
    final actor = sqliteActor(currentUser);
    if (actor.id != userId && actor.profile != UserProfile.admin) {
      throw const CatalogFailure('Ces demandes sont privées.');
    }
    return sql.readSql((db, dao) async {
      sqliteActor(currentUser, expected: actor.id);
      final rows = await dao.getAdoptions(db, userId: userId);
      sqliteActor(currentUser, expected: actor.id);
      return rows;
    });
  }

  Future<List<Adoption>> getByAnimal(int animalId) async {
    final actor = sqliteActor(currentUser, admin: true);
    return sql.readSql((db, dao) async {
      sqliteActor(currentUser, expected: actor.id, admin: true);
      final rows = await dao.getAdoptions(db, animalId: animalId);
      sqliteActor(currentUser, expected: actor.id, admin: true);
      return rows;
    });
  }

  Future<void> updateStatus(int id, AdoptionStatus status) async {
    switch (status) {
      case AdoptionStatus.ACCEPTED:
        await decideAdoption(id, accept: true);
      case AdoptionStatus.REJECTED:
        await decideAdoption(id, accept: false);
      case AdoptionStatus.CANCELLED:
        await cancelAdoption(id);
      case AdoptionStatus.PENDING:
        throw const CatalogFailure(
          'Une demande traitée ne peut pas être rouverte.',
        );
    }
  }
}
