import '../../../core/enums/pet_sitting_status.dart';

class PetSittingRequest {
  const PetSittingRequest({
    required this.id,
    required this.ownerUserId,
    required this.petSitterUserId,
    required this.animalId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.totalPrice,
    required this.createdAt,
    required this.instructions,
    required this.ownerName,
    required this.petSitterName,
    required this.animalName,
  });
  final int id;
  final String ownerUserId;
  final String petSitterUserId;
  final int animalId;
  final DateTime startDate;
  final DateTime endDate;
  final PetSittingStatus status;
  final double totalPrice;
  final DateTime createdAt;
  final String instructions;
  final String ownerName;
  final String petSitterName;
  final String animalName;
  PetSittingRequest copyWith({
    int? id,
    String? ownerUserId,
    String? petSitterUserId,
    int? animalId,
    DateTime? startDate,
    DateTime? endDate,
    PetSittingStatus? status,
    double? totalPrice,
    DateTime? createdAt,
    String? instructions,
    String? ownerName,
    String? petSitterName,
    String? animalName,
  }) => PetSittingRequest(
    id: id ?? this.id,
    ownerUserId: ownerUserId ?? this.ownerUserId,
    petSitterUserId: petSitterUserId ?? this.petSitterUserId,
    animalId: animalId ?? this.animalId,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    status: status ?? this.status,
    totalPrice: totalPrice ?? this.totalPrice,
    createdAt: createdAt ?? this.createdAt,
    instructions: instructions ?? this.instructions,
    ownerName: ownerName ?? this.ownerName,
    petSitterName: petSitterName ?? this.petSitterName,
    animalName: animalName ?? this.animalName,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerUserId': ownerUserId,
    'petSitterUserId': petSitterUserId,
    'animalId': animalId,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'status': status.name,
    'totalPrice': totalPrice,
    'createdAt': createdAt.toIso8601String(),
    'instructions': instructions,
    'ownerName': ownerName,
    'petSitterName': petSitterName,
    'animalName': animalName,
  };
  factory PetSittingRequest.fromJson(Map<String, dynamic> j) =>
      PetSittingRequest(
        id: j['id'] as int,
        ownerUserId: j['ownerUserId'] as String,
        petSitterUserId: j['petSitterUserId'] as String,
        animalId: j['animalId'] as int,
        startDate: DateTime.parse(j['startDate'] as String),
        endDate: DateTime.parse(j['endDate'] as String),
        status: PetSittingStatus.values.byName(j['status'] as String),
        totalPrice: (j['totalPrice'] as num).toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        instructions: j['instructions'] as String,
        ownerName: j['ownerName'] as String,
        petSitterName: j['petSitterName'] as String,
        animalName: j['animalName'] as String,
      );
}
