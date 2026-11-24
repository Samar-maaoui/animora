class Availability {
  const Availability({
    required this.id,
    required this.veterinarianUserId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.isFree,
  });
  final int id;
  final String veterinarianUserId;
  final DateTime date;
  final int startTime;
  final int endTime;
  final bool isFree;
  Availability copyWith({
    int? id,
    String? veterinarianUserId,
    DateTime? date,
    int? startTime,
    int? endTime,
    bool? isFree,
  }) => Availability(
    id: id ?? this.id,
    veterinarianUserId: veterinarianUserId ?? this.veterinarianUserId,
    date: date ?? this.date,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    isFree: isFree ?? this.isFree,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'veterinarianUserId': veterinarianUserId,
    'date': date.toIso8601String(),
    'startTime': startTime,
    'endTime': endTime,
    'isFree': isFree,
  };
  factory Availability.fromJson(Map<String, dynamic> j) => Availability(
    id: j['id'] as int,
    veterinarianUserId: j['veterinarianUserId'] as String,
    date: DateTime.parse(j['date'] as String),
    startTime: j['startTime'] as int,
    endTime: j['endTime'] as int,
    isFree: j['isFree'] as bool,
  );
}
