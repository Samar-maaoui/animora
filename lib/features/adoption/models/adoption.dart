import '../../../core/enums/adoption_status.dart';

class Adoption {
  const Adoption({
    required this.id,
    required this.userId,
    required this.animalId,
    required this.applicationDate,
    required this.motivation,
    required this.compatibilityScore,
    required this.status,
    this.decisionDate,
    this.adoptionDate,
  });
  final int id, animalId;
  final String userId, motivation;
  final DateTime applicationDate;
  final double compatibilityScore;
  final AdoptionStatus status;
  final DateTime? decisionDate, adoptionDate;
  Adoption copyWith({
    AdoptionStatus? status,
    DateTime? decisionDate,
    DateTime? adoptionDate,
  }) => Adoption(
    id: id,
    userId: userId,
    animalId: animalId,
    applicationDate: applicationDate,
    motivation: motivation,
    compatibilityScore: compatibilityScore,
    status: status ?? this.status,
    decisionDate: decisionDate ?? this.decisionDate,
    adoptionDate: adoptionDate ?? this.adoptionDate,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'animalId': animalId,
    'applicationDate': applicationDate.toIso8601String(),
    'motivation': motivation,
    'compatibilityScore': compatibilityScore,
    'status': status.name,
    'decisionDate': decisionDate?.toIso8601String(),
    'adoptionDate': adoptionDate?.toIso8601String(),
  };
  factory Adoption.fromJson(Map<String, dynamic> j) => Adoption(
    id: j['id'] as int,
    userId: j['userId'] as String,
    animalId: j['animalId'] as int,
    applicationDate: DateTime.parse(j['applicationDate'] as String),
    motivation: j['motivation'] as String,
    compatibilityScore: (j['compatibilityScore'] as num).toDouble(),
    status: AdoptionStatus.values.byName(j['status'] as String),
    decisionDate: j['decisionDate'] == null
        ? null
        : DateTime.parse(j['decisionDate'] as String),
    adoptionDate: j['adoptionDate'] == null
        ? null
        : DateTime.parse(j['adoptionDate'] as String),
  );
}
