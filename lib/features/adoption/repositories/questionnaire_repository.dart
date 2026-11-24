import '../models/questionnaire_adoptant.dart';

abstract interface class QuestionnaireRepository {
  Future<QuestionnaireAdoptant> getQuestionnaire(int adoptionId);
  Future<QuestionnaireAdoptant> updateQuestionnaire(
    int adoptionId,
    QuestionnaireAdoptant answers,
  );
}
