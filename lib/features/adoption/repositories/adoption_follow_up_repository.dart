import '../models/suivi_adoption.dart';

abstract interface class AdoptionFollowUpRepository {
  Future<List<SuiviAdoption>> getFollowUps(int adoptionId);
  Future<void> addFollowUp(
    int adoptionId, {
    required String news,
    required String visitType,
    String? photo,
  });
}
