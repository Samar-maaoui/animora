import '../../../core/enums/claim_status.dart';

const _unset = Object();

class Reclamation {
  const Reclamation({
    required this.id,
    required this.announcementId,
    required this.claimantUserId,
    this.verificationCode,
    required this.evidence,
    required this.status,
    required this.createdAt,
  });
  final int id;
  final int announcementId;
  final String claimantUserId;
  final String? verificationCode;
  final String evidence;
  final ClaimStatus status;
  final DateTime createdAt;
  Reclamation copyWith({
    int? id,
    int? announcementId,
    String? claimantUserId,
    Object? verificationCode = _unset,
    String? evidence,
    ClaimStatus? status,
    DateTime? createdAt,
  }) => Reclamation(
    id: id ?? this.id,
    announcementId: announcementId ?? this.announcementId,
    claimantUserId: claimantUserId ?? this.claimantUserId,
    verificationCode: verificationCode == _unset
        ? this.verificationCode
        : verificationCode as String?,
    evidence: evidence ?? this.evidence,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'announcementId': announcementId,
    'claimantUserId': claimantUserId,
    'verificationCode': verificationCode,
    'evidence': evidence,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
  };
  factory Reclamation.fromJson(Map<String, dynamic> j) => Reclamation(
    id: j['id'] as int,
    announcementId: j['announcementId'] as int,
    claimantUserId: j['claimantUserId'] as String,
    verificationCode: j['verificationCode'] == null
        ? null
        : j['verificationCode'] as String,
    evidence: j['evidence'] as String,
    status: ClaimStatus.values.byName(j['status'] as String),
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}
