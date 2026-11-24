const _unset = Object();

class ConfirmationSignalement {
  const ConfirmationSignalement({
    required this.id,
    required this.reportId,
    required this.userId,
    required this.date,
    this.comment,
  });
  final int id;
  final int reportId;
  final String userId;
  final DateTime date;
  final String? comment;
  ConfirmationSignalement copyWith({
    int? id,
    int? reportId,
    String? userId,
    DateTime? date,
    Object? comment = _unset,
  }) => ConfirmationSignalement(
    id: id ?? this.id,
    reportId: reportId ?? this.reportId,
    userId: userId ?? this.userId,
    date: date ?? this.date,
    comment: comment == _unset ? this.comment : comment as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'reportId': reportId,
    'userId': userId,
    'date': date.toIso8601String(),
    'comment': comment,
  };
  factory ConfirmationSignalement.fromJson(Map<String, dynamic> j) =>
      ConfirmationSignalement(
        id: j['id'] as int,
        reportId: j['reportId'] as int,
        userId: j['userId'] as String,
        date: DateTime.parse(j['date'] as String),
        comment: j['comment'] == null ? null : j['comment'] as String,
      );
}
