import '../../../core/enums/donation_type.dart';
import '../../../core/enums/donation_status.dart';

const _unset = Object();

class Donation {
  const Donation({
    required this.id,
    required this.donorUserId,
    required this.campaignId,
    required this.type,
    this.amount,
    required this.donationDate,
    required this.status,
    required this.donorName,
    required this.campaignTitle,
    this.requestKey,
    this.recurringDonationId,
    this.scheduledFor,
  });
  final int id;
  final String donorUserId;
  final int campaignId;
  final DonationType type;
  final double? amount;
  final DateTime donationDate;
  final DonationStatus status;
  final String donorName;
  final String campaignTitle;
  final String? requestKey;
  final int? recurringDonationId;
  final DateTime? scheduledFor;
  Donation copyWith({
    int? id,
    String? donorUserId,
    int? campaignId,
    DonationType? type,
    Object? amount = _unset,
    DateTime? donationDate,
    DonationStatus? status,
    String? donorName,
    String? campaignTitle,
    Object? requestKey = _unset,
    Object? recurringDonationId = _unset,
    Object? scheduledFor = _unset,
  }) => Donation(
    id: id ?? this.id,
    donorUserId: donorUserId ?? this.donorUserId,
    campaignId: campaignId ?? this.campaignId,
    type: type ?? this.type,
    amount: amount == _unset ? this.amount : (amount as num?)?.toDouble(),
    donationDate: donationDate ?? this.donationDate,
    status: status ?? this.status,
    donorName: donorName ?? this.donorName,
    campaignTitle: campaignTitle ?? this.campaignTitle,
    requestKey: requestKey == _unset ? this.requestKey : requestKey as String?,
    recurringDonationId: recurringDonationId == _unset
        ? this.recurringDonationId
        : recurringDonationId as int?,
    scheduledFor: scheduledFor == _unset
        ? this.scheduledFor
        : scheduledFor as DateTime?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'donorUserId': donorUserId,
    'campaignId': campaignId,
    'type': type.name,
    'amount': amount,
    'donationDate': donationDate.toIso8601String(),
    'status': status.name,
    'donorName': donorName,
    'campaignTitle': campaignTitle,
    'requestKey': requestKey,
    'recurringDonationId': recurringDonationId,
    'scheduledFor': scheduledFor?.toIso8601String(),
  };
  factory Donation.fromJson(Map<String, dynamic> j) => Donation(
    id: j['id'] as int,
    donorUserId: j['donorUserId'] as String,
    campaignId: j['campaignId'] as int,
    type: DonationType.values.byName(j['type'] as String),
    amount: j['amount'] == null ? null : (j['amount'] as num).toDouble(),
    donationDate: DateTime.parse(j['donationDate'] as String),
    status: DonationStatus.values.byName(j['status'] as String),
    donorName: j['donorName'] as String,
    campaignTitle: j['campaignTitle'] as String,
    requestKey: j['requestKey'] == null ? null : j['requestKey'] as String,
    recurringDonationId: j['recurringDonationId'] == null
        ? null
        : j['recurringDonationId'] as int,
    scheduledFor: j['scheduledFor'] == null
        ? null
        : DateTime.parse(j['scheduledFor'] as String),
  );
}
