import '../models/animal.dart';
import '../repositories/animal_repository.dart';

abstract final class AnimalValidation {
  static String? nonNegativeInteger(String? value) {
    final age = int.tryParse(value?.trim() ?? '');
    return age != null && age >= 0 && age <= 200
        ? null
        : 'Saisissez un entier entre 0 et 200.';
  }

  static String? positiveWeight(String? value) {
    final weight = double.tryParse((value ?? '').replaceAll(',', '.'));
    return weight != null && weight.isFinite && weight > 0 && weight <= 10000
        ? null
        : 'Saisissez un poids positif (maximum 10 000 kg).';
  }

  static void validate(Animal animal) {
    if ([
      animal.name,
      animal.species,
      animal.breed,
      animal.sex,
      animal.color,
      animal.health,
      animal.character,
      animal.city,
    ].any((value) => value.trim().isEmpty)) {
      throw const CatalogFailure('Renseignez tous les champs obligatoires.');
    }
    if (nonNegativeInteger(animal.age.toString()) != null ||
        positiveWeight(animal.weight.toString()) != null) {
      throw const CatalogFailure('L’âge ou le poids est invalide.');
    }
    if (!animal.animalPhoto.startsWith('assets/') &&
        !animal.animalPhoto.startsWith('data:image/')) {
      throw const CatalogFailure('Choisissez une photo depuis votre appareil.');
    }
    if (animal.animalPhoto.length > 1500000) {
      throw const CatalogFailure(
        'La photo dépasse la limite de stockage locale.',
      );
    }
  }
}
