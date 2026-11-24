import '../models/vaccination.dart';

abstract interface class VaccinationRepository {
  Future<List<Vaccination>> getVaccinations(int animalId);
  Future<void> saveVaccination(Vaccination draft, {required bool creating});
}
