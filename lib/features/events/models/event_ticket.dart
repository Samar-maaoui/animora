class EventTicket {
  const EventTicket({
    required this.id,
    required this.registrationId,
    required this.code,
    required this.issueDate,
    required this.used,
  });
  final int id;
  final int registrationId;
  final String code;
  final DateTime issueDate;
  final bool used;
  EventTicket copyWith({
    int? id,
    int? registrationId,
    String? code,
    DateTime? issueDate,
    bool? used,
  }) => EventTicket(
    id: id ?? this.id,
    registrationId: registrationId ?? this.registrationId,
    code: code ?? this.code,
    issueDate: issueDate ?? this.issueDate,
    used: used ?? this.used,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'registrationId': registrationId,
    'code': code,
    'issueDate': issueDate.toIso8601String(),
    'used': used,
  };
  factory EventTicket.fromJson(Map<String, dynamic> j) => EventTicket(
    id: j['id'] as int,
    registrationId: j['registrationId'] as int,
    code: j['code'] as String,
    issueDate: DateTime.parse(j['issueDate'] as String),
    used: j['used'] as bool,
  );
}
