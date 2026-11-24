import '../models/availability.dart';

abstract interface class AvailabilityRepository {
  Future<List<Availability>> getAvailability(
    String veterinarianId, {
    bool includeReserved = false,
  });
  Future<void> saveAvailability(Availability draft, {required bool creating});
  Future<void> deleteAvailability(int id);
}
