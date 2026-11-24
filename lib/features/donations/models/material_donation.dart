import '../../../core/enums/material_type.dart';
import '../../../core/enums/material_donation_status.dart';

const _unset = Object();

class MaterialDonation {
  const MaterialDonation({
    required this.id,
    required this.donationId,
    required this.itemType,
    required this.quantity,
    required this.description,
    required this.status,
    this.materialNeedId,
  });
  final int id;
  final int donationId;
  final MaterialType itemType;
  final int quantity;
  final String description;
  final MaterialDonationStatus status;
  final int? materialNeedId;
  MaterialDonation copyWith({
    int? id,
    int? donationId,
    MaterialType? itemType,
    int? quantity,
    String? description,
    MaterialDonationStatus? status,
    Object? materialNeedId = _unset,
  }) => MaterialDonation(
    id: id ?? this.id,
    donationId: donationId ?? this.donationId,
    itemType: itemType ?? this.itemType,
    quantity: quantity ?? this.quantity,
    description: description ?? this.description,
    status: status ?? this.status,
    materialNeedId: materialNeedId == _unset
        ? this.materialNeedId
        : materialNeedId as int?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'donationId': donationId,
    'itemType': itemType.name,
    'quantity': quantity,
    'description': description,
    'status': status.name,
    'materialNeedId': materialNeedId,
  };
  factory MaterialDonation.fromJson(Map<String, dynamic> j) => MaterialDonation(
    id: j['id'] as int,
    donationId: j['donationId'] as int,
    itemType: MaterialType.values.byName(j['itemType'] as String),
    quantity: j['quantity'] as int,
    description: j['description'] as String,
    status: MaterialDonationStatus.values.byName(j['status'] as String),
    materialNeedId: j['materialNeedId'] == null
        ? null
        : j['materialNeedId'] as int,
  );
}
