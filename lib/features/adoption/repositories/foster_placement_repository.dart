import '../../../core/enums/animal_status.dart';
import '../../users/models/user.dart';
import '../models/adoption.dart';
import '../models/hebergement.dart';
import '../models/questionnaire_adoptant.dart';

abstract interface class FosterPlacementRepository {
  Future<List<Hebergement>> getPlacements();
  Future<Hebergement> getPlacement(int id);
  Future<List<User>> getActiveFamilies();
  Future<Hebergement> assignPlacement(
    int animalId,
    String familyId,
    DateTime startDate, {
    String remarks = '',
  });
  Future<void> addPlacementRemark(int id, String remark);
  Future<void> finishPlacement(
    int id, {
    bool cancel = false,
    AnimalStatus releaseStatus = AnimalStatus.AVAILABLE,
  });
  Future<Adoption> convertToAdoption(
    int placementId,
    QuestionnaireAdoptant? answers,
    String motivation,
  );
}
