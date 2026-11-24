import '../../../core/enums/hebergement_status.dart';

class Hebergement {
  const Hebergement({
    required this.id,
    required this.animalId,
    required this.fosterFamilyUserId,
    required this.startDate,
    this.endDate,
    required this.status,
    required this.remarks,
  });
  final int id, animalId;
  final String fosterFamilyUserId, remarks;
  final DateTime startDate;
  final DateTime? endDate;
  final HebergementStatus status;
  Hebergement copyWith({
    DateTime? endDate,
    HebergementStatus? status,
    String? remarks,
  }) => Hebergement(
    id: id,
    animalId: animalId,
    fosterFamilyUserId: fosterFamilyUserId,
    startDate: startDate,
    endDate: endDate ?? this.endDate,
    status: status ?? this.status,
    remarks: remarks ?? this.remarks,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'animalId': animalId,
    'fosterFamilyUserId': fosterFamilyUserId,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'status': status.name,
    'remarks': remarks,
  };
  factory Hebergement.fromJson(Map<String, dynamic> j) => Hebergement(
    id: j['id'] as int,
    animalId: j['animalId'] as int,
    fosterFamilyUserId: j['fosterFamilyUserId'] as String,
    startDate: DateTime.parse(j['startDate'] as String),
    endDate: j['endDate'] == null
        ? null
        : DateTime.parse(j['endDate'] as String),
    status: HebergementStatus.values.byName(j['status'] as String),
    remarks: j['remarks'] as String,
  );
}
