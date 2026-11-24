import '../../users/models/user.dart';
import '../models/pet_sitter_settings.dart';
import '../models/pet_sitting_request.dart';
import '../../../core/enums/pet_sitting_status.dart';

abstract interface class PetSittingRepository {
  Future<List<User>> getPetSitters();
  Future<bool> isPetSitterAvailable(String id, DateTime start, DateTime end);
  Future<PetSitterSettings?> getPetSitterSettings(String userId);
  Future<void> savePetSitterSettings(PetSitterSettings draft);
  Future<List<PetSittingRequest>> getPetSittingRequests();
  Future<PetSittingRequest> getPetSittingRequest(int id);
  Future<void> createPetSittingRequest(
    String sitterId,
    int animalId,
    DateTime start,
    DateTime end,
    String instructions,
  );
  Future<void> changePetSittingStatus(int id, PetSittingStatus status);
  double estimatePrice(double dailyRate, DateTime start, DateTime end);
}
