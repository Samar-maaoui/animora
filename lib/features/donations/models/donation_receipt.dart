import '../../../core/enums/donation_type.dart';

const _unset = Object();

class DonationReceipt {
  const DonationReceipt({
    required this.id,
    required this.donationId,
    required this.issueDate,
    required this.reference,
    this.filePath,
    required this.donationReference,
    required this.donorName,
    required this.campaignTitle,
    required this.type,
    this.amount,
    this.materialDescription,
  });
  final int id;
  final int donationId;
  final DateTime issueDate;
  final String reference;
  final String? filePath;
  final String donationReference;
  final String donorName;
  final String campaignTitle;
  final DonationType type;
  final double? amount;
  final String? materialDescription;
  DonationReceipt copyWith({
    int? id,
    int? donationId,
    DateTime? issueDate,
    String? reference,
    Object? filePath = _unset,
    String? donationReference,
    String? donorName,
    String? campaignTitle,
    DonationType? type,
    Object? amount = _unset,
    Object? materialDescription = _unset,
  }) => DonationReceipt(
    id: id ?? this.id,
    donationId: donationId ?? this.donationId,
    issueDate: issueDate ?? this.issueDate,
    reference: reference ?? this.reference,
    filePath: filePath == _unset ? this.filePath : filePath as String?,
    donationReference: donationReference ?? this.donationReference,
    donorName: donorName ?? this.donorName,
    campaignTitle: campaignTitle ?? this.campaignTitle,
    type: type ?? this.type,
    amount: amount == _unset ? this.amount : (amount as num?)?.toDouble(),
    materialDescription: materialDescription == _unset
        ? this.materialDescription
        : materialDescription as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'donationId': donationId,
    'issueDate': issueDate.toIso8601String(),
    'reference': reference,
    'filePath': filePath,
    'donationReference': donationReference,
    'donorName': donorName,
    'campaignTitle': campaignTitle,
    'type': type.name,
    'amount': amount,
    'materialDescription': materialDescription,
  };
  factory DonationReceipt.fromJson(Map<String, dynamic> j) => DonationReceipt(
    id: j['id'] as int,
    donationId: j['donationId'] as int,
    issueDate: DateTime.parse(j['issueDate'] as String),
    reference: j['reference'] as String,
    filePath: j['filePath'] == null ? null : j['filePath'] as String,
    donationReference: j['donationReference'] as String,
    donorName: j['donorName'] as String,
    campaignTitle: j['campaignTitle'] as String,
    type: DonationType.values.byName(j['type'] as String),
    amount: j['amount'] == null ? null : (j['amount'] as num).toDouble(),
    materialDescription: j['materialDescription'] == null
        ? null
        : j['materialDescription'] as String,
  );
}
