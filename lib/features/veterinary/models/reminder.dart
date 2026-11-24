const _unset = Object();

class Reminder {
  const Reminder({
    required this.id,
    required this.animalId,
    required this.type,
    required this.scheduledDate,
    required this.isSent,
    this.vaccinationId,
    required this.authorUserId,
  });
  final int id;
  final int animalId;
  final String type;
  final DateTime scheduledDate;
  final bool isSent;
  final int? vaccinationId;
  final String authorUserId;
  Reminder copyWith({
    int? id,
    int? animalId,
    String? type,
    DateTime? scheduledDate,
    bool? isSent,
    Object? vaccinationId = _unset,
    String? authorUserId,
  }) => Reminder(
    id: id ?? this.id,
    animalId: animalId ?? this.animalId,
    type: type ?? this.type,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    isSent: isSent ?? this.isSent,
    vaccinationId: vaccinationId == _unset
        ? this.vaccinationId
        : vaccinationId as int?,
    authorUserId: authorUserId ?? this.authorUserId,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'animalId': animalId,
    'type': type,
    'scheduledDate': scheduledDate.toIso8601String(),
    'isSent': isSent,
    'vaccinationId': vaccinationId,
    'authorUserId': authorUserId,
  };
  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
    id: j['id'] as int,
    animalId: j['animalId'] as int,
    type: j['type'] as String,
    scheduledDate: DateTime.parse(j['scheduledDate'] as String),
    isSent: j['isSent'] as bool,
    vaccinationId: j['vaccinationId'] == null
        ? null
        : j['vaccinationId'] as int,
    authorUserId: j['authorUserId'] as String,
  );
}
