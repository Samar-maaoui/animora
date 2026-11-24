class QuestionnaireAdoptant {
  const QuestionnaireAdoptant({
    required this.id,
    required this.adoptionId,
    required this.housingType,
    required this.hasChildren,
    required this.hasOtherAnimals,
    required this.experience,
    required this.availableTime,
  });
  final int id, adoptionId;
  final String housingType, experience, availableTime;
  final bool hasChildren, hasOtherAnimals;
  Map<String, dynamic> toJson() => {
    'id': id,
    'adoptionId': adoptionId,
    'housingType': housingType,
    'hasChildren': hasChildren,
    'hasOtherAnimals': hasOtherAnimals,
    'experience': experience,
    'availableTime': availableTime,
  };
  factory QuestionnaireAdoptant.fromJson(Map<String, dynamic> j) =>
      QuestionnaireAdoptant(
        id: j['id'] as int,
        adoptionId: j['adoptionId'] as int,
        housingType: j['housingType'] as String,
        hasChildren: j['hasChildren'] as bool,
        hasOtherAnimals: j['hasOtherAnimals'] as bool,
        experience: j['experience'] as String,
        availableTime: j['availableTime'] as String,
      );
}
