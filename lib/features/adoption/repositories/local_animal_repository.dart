import '../../../core/enums/account_status.dart';
import '../../../core/enums/user_profile.dart';
import '../../../core/enums/adoption_status.dart';
import '../../../core/enums/hebergement_status.dart';
import '../../../core/enums/animal_status.dart';
import '../../users/models/user.dart';
import '../models/animal.dart';
import '../models/animal_filter.dart';
import '../services/animal_validation.dart';
import 'animal_repository.dart';
import 'local_catalog_database.dart';

class LocalAnimalRepository extends AnimalRepository {
  LocalAnimalRepository(this.database, this.currentUser) {
    database.addListener(_changed);
  }
  final LocalCatalogDatabase database;
  final User? Function() currentUser;
  void _changed() => notifyListeners();
  void _requireActive({bool admin = false}) {
    final user = currentUser();
    if (user == null ||
        user.status != AccountStatus.active ||
        (admin && user.profile != UserProfile.admin)) {
      throw CatalogFailure(
        admin
            ? 'Accès réservé aux administrateurs actifs.'
            : 'Connectez-vous avec un compte actif.',
      );
    }
  }

  @override
  Future<List<Animal>> getAllAnimals() => database.read((data) {
    _requireActive();
    return List.unmodifiable(data.animals.values);
  });
  @override
  Future<Animal?> getAnimalById(int id) => database.read((data) {
    _requireActive();
    return data.animals[id];
  });
  @override
  Future<List<Animal>> searchAnimals(AnimalFilter filter) async =>
      (await getAllAnimals()).where(filter.matches).toList();
  @override
  Future<Animal> addAnimal(Animal animal) => database.mutate((data) {
    _requireActive(admin: true);
    AnimalValidation.validate(animal);
    if (data.nextId >= 9007199254740991) {
      throw const CatalogFailure('Limite des identifiants atteinte.');
    }
    final created = animal.copyWith(id: data.nextId++);
    data.animals[created.id] = created;
    return created;
  });
  @override
  Future<void> updateAnimal(Animal animal) => database.mutate<void>((data) {
    _requireActive(admin: true);
    AnimalValidation.validate(animal);
    if (!data.animals.containsKey(animal.id)) {
      throw const CatalogFailure('Cet animal n’existe plus.');
    }
    final accepted = data.workflow.adoptions.values
        .where(
          (a) => a.animalId == animal.id && a.status == AdoptionStatus.ACCEPTED,
        )
        .firstOrNull;
    final activePlacement = data.workflow.placements.values.any(
      (p) => p.animalId == animal.id && p.status == HebergementStatus.ACTIVE,
    );
    final lockedStatus = accepted != null
        ? (accepted.adoptionDate == null
              ? AnimalStatus.PENDING_ADOPTION
              : AnimalStatus.ADOPTED)
        : activePlacement
        ? AnimalStatus.FOSTERED
        : null;
    if (lockedStatus != null && animal.status != lockedStatus) {
      throw const CatalogFailure(
        'Le statut est géré par le contrat ou l’hébergement en cours.',
      );
    }
    if (![
      AnimalStatus.AVAILABLE,
      AnimalStatus.FOSTERED,
    ].contains(animal.status)) {
      for (final a in data.workflow.adoptions.values.toList()) {
        if (a.animalId == animal.id && a.status == AdoptionStatus.PENDING) {
          data.workflow.adoptions[a.id] = a.copyWith(
            status: AdoptionStatus.REJECTED,
            decisionDate: DateTime.now().toUtc(),
          );
        }
      }
    }
    data.animals[animal.id] = animal.copyWith(
      arrivalDate: data.animals[animal.id]!.arrivalDate,
    );
  });
  @override
  Future<void> deleteAnimal(int id) => database.mutate<void>((data) {
    _requireActive(admin: true);
    if (data.workflow.adoptions.values.any((a) => a.animalId == id) ||
        data.workflow.placements.values.any((p) => p.animalId == id)) {
      throw const CatalogFailure(
        'Cet animal possède un historique d’adoption ou d’hébergement et ne peut pas être supprimé.',
      );
    }
    if (data.animals.remove(id) == null) {
      throw const CatalogFailure('Cet animal n’existe plus.');
    }
    data.favorites.removeWhere((favorite) => favorite.animalId == id);
  });
  @override
  void dispose() {
    database.removeListener(_changed);
    super.dispose();
  }
}
