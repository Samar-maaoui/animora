import '../../../core/enums/donation_frequency.dart';
import '../../../core/enums/recurring_donation_status.dart';

const _unset = Object();

class RecurringDonation {
  const RecurringDonation({
    required this.id,
    required this.donorUserId,
    required this.campaignId,
    required this.amount,
    required this.frequency,
    required this.nextDonationDate,
    required this.status,
    required this.anchorDay,
    required this.donorName,
    required this.campaignTitle,
    this.terminationReason,
    this.requestKey,
  });
  final int id;
  final String donorUserId;
  final int campaignId;
  final double amount;
  final DonationFrequency frequency;
  final DateTime nextDonationDate;
  final RecurringDonationStatus status;
  final int anchorDay;
  final String donorName;
  final String campaignTitle;
  final String? terminationReason;
  final String? requestKey;
  RecurringDonation copyWith({
    int? id,
    String? donorUserId,
    int? campaignId,
    double? amount,
    DonationFrequency? frequency,
    DateTime? nextDonationDate,
    RecurringDonationStatus? status,
    int? anchorDay,
    String? donorName,
    String? campaignTitle,
    Object? terminationReason = _unset,
    Object? requestKey = _unset,
  }) => RecurringDonation(
    id: id ?? this.id,
    donorUserId: donorUserId ?? this.donorUserId,
    campaignId: campaignId ?? this.campaignId,
    amount: amount ?? this.amount,
    frequency: frequency ?? this.frequency,
    nextDonationDate: nextDonationDate ?? this.nextDonationDate,
    status: status ?? this.status,
    anchorDay: anchorDay ?? this.anchorDay,
    donorName: donorName ?? this.donorName,
    campaignTitle: campaignTitle ?? this.campaignTitle,
    terminationReason: terminationReason == _unset
        ? this.terminationReason
        : terminationReason as String?,
    requestKey: requestKey == _unset ? this.requestKey : requestKey as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'donorUserId': donorUserId,
    'campaignId': campaignId,
    'amount': amount,
    'frequency': frequency.name,
    'nextDonationDate': nextDonationDate.toIso8601String(),
    'status': status.name,
    'anchorDay': anchorDay,
    'donorName': donorName,
    'campaignTitle': campaignTitle,
    'terminationReason': terminationReason,
    'requestKey': requestKey,
  };
  factory RecurringDonation.fromJson(Map<String, dynamic> j) =>
      RecurringDonation(
        id: j['id'] as int,
        donorUserId: j['donorUserId'] as String,
        campaignId: j['campaignId'] as int,
        amount: (j['amount'] as num).toDouble(),
        frequency: DonationFrequency.values.byName(j['frequency'] as String),
        nextDonationDate: DateTime.parse(j['nextDonationDate'] as String),
        status: RecurringDonationStatus.values.byName(j['status'] as String),
        anchorDay: j['anchorDay'] as int,
        donorName: j['donorName'] as String,
        campaignTitle: j['campaignTitle'] as String,
        terminationReason: j['terminationReason'] == null
            ? null
            : j['terminationReason'] as String,
        requestKey: j['requestKey'] == null ? null : j['requestKey'] as String,
      );
}
