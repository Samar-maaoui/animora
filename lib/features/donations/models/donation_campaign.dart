import '../../../core/enums/campaign_status.dart';

const _unset = Object();

class DonationCampaign {
  const DonationCampaign({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.collectedAmount,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.image,
  });
  final int id;
  final String title;
  final String description;
  final double targetAmount;
  final double collectedAmount;
  final DateTime startDate;
  final DateTime endDate;
  final CampaignStatus status;
  final String? image;
  DonationCampaign copyWith({
    int? id,
    String? title,
    String? description,
    double? targetAmount,
    double? collectedAmount,
    DateTime? startDate,
    DateTime? endDate,
    CampaignStatus? status,
    Object? image = _unset,
  }) => DonationCampaign(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    targetAmount: targetAmount ?? this.targetAmount,
    collectedAmount: collectedAmount ?? this.collectedAmount,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    status: status ?? this.status,
    image: image == _unset ? this.image : image as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'targetAmount': targetAmount,
    'collectedAmount': collectedAmount,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'status': status.name,
    'image': image,
  };
  factory DonationCampaign.fromJson(Map<String, dynamic> j) => DonationCampaign(
    id: j['id'] as int,
    title: j['title'] as String,
    description: j['description'] as String,
    targetAmount: (j['targetAmount'] as num).toDouble(),
    collectedAmount: (j['collectedAmount'] as num).toDouble(),
    startDate: DateTime.parse(j['startDate'] as String),
    endDate: DateTime.parse(j['endDate'] as String),
    status: CampaignStatus.values.byName(j['status'] as String),
    image: j['image'] == null ? null : j['image'] as String,
  );
}
