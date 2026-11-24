import '../models/care.dart';

abstract interface class CareRepository {
  Future<List<Care>> getCare(int animalId);
  Future<void> addCare(Care draft);
}
