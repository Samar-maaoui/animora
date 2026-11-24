import 'package:flutter/foundation.dart';

import '../models/animal.dart';
import '../models/animal_filter.dart';

class CatalogFailure implements Exception {
  const CatalogFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

String catalogErrorMessage(Object error) => error is CatalogFailure
    ? error.message
    : 'Une erreur est survenue. Veuillez réessayer.';

abstract class AnimalRepository extends ChangeNotifier {
  Future<List<Animal>> getAllAnimals();
  Future<Animal?> getAnimalById(int id);
  Future<Animal> addAnimal(Animal animal);
  Future<void> updateAnimal(Animal animal);
  Future<void> deleteAnimal(int id);
  Future<List<Animal>> searchAnimals(AnimalFilter filter);
}
