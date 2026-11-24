const _unset = Object();

class Vaccination {
  const Vaccination({
    required this.id,
    required this.animalId,
    required this.veterinarianUserId,
    required this.vaccineName,
    required this.vaccinationDate,
    this.nextDoseDate,
    this.notes,
    required this.veterinarianName,
  });
  final int id;
  final int animalId;
  final String veterinarianUserId;
  final String vaccineName;
  final DateTime vaccinationDate;
  final DateTime? nextDoseDate;
  final String? notes;
  final String veterinarianName;
  Vaccination copyWith({
    int? id,
    int? animalId,
    String? veterinarianUserId,
    String? vaccineName,
    DateTime? vaccinationDate,
    Object? nextDoseDate = _unset,
    Object? notes = _unset,
    String? veterinarianName,
  }) => Vaccination(
    id: id ?? this.id,
    animalId: animalId ?? this.animalId,
    veterinarianUserId: veterinarianUserId ?? this.veterinarianUserId,
    vaccineName: vaccineName ?? this.vaccineName,
    vaccinationDate: vaccinationDate ?? this.vaccinationDate,
    nextDoseDate: nextDoseDate == _unset
        ? this.nextDoseDate
        : nextDoseDate as DateTime?,
    notes: notes == _unset ? this.notes : notes as String?,
    veterinarianName: veterinarianName ?? this.veterinarianName,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'animalId': animalId,
    'veterinarianUserId': veterinarianUserId,
    'vaccineName': vaccineName,
    'vaccinationDate': vaccinationDate.toIso8601String(),
    'nextDoseDate': nextDoseDate?.toIso8601String(),
    'notes': notes,
    'veterinarianName': veterinarianName,
  };
  factory Vaccination.fromJson(Map<String, dynamic> j) => Vaccination(
    id: j['id'] as int,
    animalId: j['animalId'] as int,
    veterinarianUserId: j['veterinarianUserId'] as String,
    vaccineName: j['vaccineName'] as String,
    vaccinationDate: DateTime.parse(j['vaccinationDate'] as String),
    nextDoseDate: j['nextDoseDate'] == null
        ? null
        : DateTime.parse(j['nextDoseDate'] as String),
    notes: j['notes'] == null ? null : j['notes'] as String,
    veterinarianName: j['veterinarianName'] as String,
  );
}
