class EventActivity {
  const EventActivity({
    required this.id,
    required this.eventId,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
  });
  final int id;
  final int eventId;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  EventActivity copyWith({
    int? id,
    int? eventId,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
  }) => EventActivity(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    title: title ?? this.title,
    description: description ?? this.description,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'title': title,
    'description': description,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
  };
  factory EventActivity.fromJson(Map<String, dynamic> j) => EventActivity(
    id: j['id'] as int,
    eventId: j['eventId'] as int,
    title: j['title'] as String,
    description: j['description'] as String,
    startTime: DateTime.parse(j['startTime'] as String),
    endTime: DateTime.parse(j['endTime'] as String),
  );
}
