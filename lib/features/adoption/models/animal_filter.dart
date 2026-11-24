import '../../../core/enums/animal_status.dart';
import 'animal.dart';

enum AnimalAgeGroup { young, adult, senior }

extension AnimalAgeGroupLabel on AnimalAgeGroup {
  String get label => switch (this) {
    AnimalAgeGroup.young => '0 à 1 an',
    AnimalAgeGroup.adult => '2 à 7 ans',
    AnimalAgeGroup.senior => '8 ans et plus',
  };
}

class AnimalFilter {
  const AnimalFilter({
    this.name = '',
    this.species,
    this.breed,
    this.age,
    this.city,
    this.status,
  });
  final String name;
  final String? species, breed, city;
  final AnimalAgeGroup? age;
  final AnimalStatus? status;
  bool matches(Animal animal) {
    final speciesMatch =
        species == null ||
        (species == 'Autre'
            ? !['Chien', 'Chat'].contains(animal.species)
            : animal.species == species);
    final ageMatch = switch (age) {
      null => true,
      AnimalAgeGroup.young => animal.age <= 1,
      AnimalAgeGroup.adult => animal.age >= 2 && animal.age <= 7,
      AnimalAgeGroup.senior => animal.age >= 8,
    };
    return animal.name.toLowerCase().contains(name.trim().toLowerCase()) &&
        speciesMatch &&
        (breed == null || animal.breed == breed) &&
        ageMatch &&
        (city == null || animal.city == city) &&
        (status == null || animal.status == status);
  }
}
