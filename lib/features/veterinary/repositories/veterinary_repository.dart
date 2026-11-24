import '../../users/models/user.dart';
import '../../adoption/models/animal.dart';

abstract interface class VeterinaryRepository {
  Future<List<User>> getVeterinarians();
  Future<bool> canTreatAnimal(int animalId);
  Future<List<Animal>> getResponsibleAnimals();
  Future<List<Animal>> getHealthAnimals();
  Future<Animal> getHealthAnimal(int animalId);
}
