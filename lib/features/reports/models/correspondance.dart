import '../../../core/enums/match_status.dart';

class Correspondance {
  const Correspondance({
    required this.id,
    required this.lostAnnouncementId,
    required this.foundAnnouncementId,
    required this.score,
    required this.status,
    required this.detectedAt,
  });
  final int id;
  final int lostAnnouncementId;
  final int foundAnnouncementId;
  final double score;
  final MatchStatus status;
  final DateTime detectedAt;
  Correspondance copyWith({
    int? id,
    int? lostAnnouncementId,
    int? foundAnnouncementId,
    double? score,
    MatchStatus? status,
    DateTime? detectedAt,
  }) => Correspondance(
    id: id ?? this.id,
    lostAnnouncementId: lostAnnouncementId ?? this.lostAnnouncementId,
    foundAnnouncementId: foundAnnouncementId ?? this.foundAnnouncementId,
    score: score ?? this.score,
    status: status ?? this.status,
    detectedAt: detectedAt ?? this.detectedAt,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'lostAnnouncementId': lostAnnouncementId,
    'foundAnnouncementId': foundAnnouncementId,
    'score': score,
    'status': status.name,
    'detectedAt': detectedAt.toIso8601String(),
  };
  factory Correspondance.fromJson(Map<String, dynamic> j) => Correspondance(
    id: j['id'] as int,
    lostAnnouncementId: j['lostAnnouncementId'] as int,
    foundAnnouncementId: j['foundAnnouncementId'] as int,
    score: (j['score'] as num).toDouble(),
    status: MatchStatus.values.byName(j['status'] as String),
    detectedAt: DateTime.parse(j['detectedAt'] as String),
  );
}
