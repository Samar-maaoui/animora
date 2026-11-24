import '../../users/models/user.dart';
import '../models/animal.dart';
import '../models/adoption.dart';
import '../models/questionnaire_adoptant.dart';
import '../models/contrat_adoption.dart';

class AdoptionDetails {
  const AdoptionDetails({
    required this.adoption,
    required this.animal,
    required this.applicant,
    required this.questionnaire,
    this.contract,
  });
  final Adoption adoption;
  final Animal animal;
  final User applicant;
  final QuestionnaireAdoptant questionnaire;
  final ContratAdoption? contract;
}

abstract interface class AdoptionRepository {
  Future<List<Adoption>> getAdoptions();
  Future<AdoptionDetails> getAdoption(int id);
  Future<Adoption> submitAdoption(
    int animalId,
    QuestionnaireAdoptant? answers,
    String motivation,
  );
  Future<void> cancelAdoption(int id);
  Future<void> decideAdoption(int id, {required bool accept});
}
