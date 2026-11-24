import '../../../core/enums/material_need_status.dart';
import '../../../core/enums/material_type.dart';

class MaterialNeed {
  const MaterialNeed({
    required this.id,
    required this.campaignId,
    required this.description,
    required this.requestedQuantity,
    required this.receivedQuantity,
    required this.status,
    required this.itemType,
  });
  final int id;
  final int campaignId;
  final String description;
  final int requestedQuantity;
  final int receivedQuantity;
  final MaterialNeedStatus status;
  final MaterialType itemType;
  MaterialNeed copyWith({
    int? id,
    int? campaignId,
    String? description,
    int? requestedQuantity,
    int? receivedQuantity,
    MaterialNeedStatus? status,
    MaterialType? itemType,
  }) => MaterialNeed(
    id: id ?? this.id,
    campaignId: campaignId ?? this.campaignId,
    description: description ?? this.description,
    requestedQuantity: requestedQuantity ?? this.requestedQuantity,
    receivedQuantity: receivedQuantity ?? this.receivedQuantity,
    status: status ?? this.status,
    itemType: itemType ?? this.itemType,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'campaignId': campaignId,
    'description': description,
    'requestedQuantity': requestedQuantity,
    'receivedQuantity': receivedQuantity,
    'status': status.name,
    'itemType': itemType.name,
  };
  factory MaterialNeed.fromJson(Map<String, dynamic> j) => MaterialNeed(
    id: j['id'] as int,
    campaignId: j['campaignId'] as int,
    description: j['description'] as String,
    requestedQuantity: j['requestedQuantity'] as int,
    receivedQuantity: j['receivedQuantity'] as int,
    status: MaterialNeedStatus.values.byName(j['status'] as String),
    itemType: MaterialType.values.byName(j['itemType'] as String),
  );
}
