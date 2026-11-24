class EventReport {
  const EventReport({
    required this.id,
    required this.eventId,
    required this.participantCount,
    required this.volunteerCount,
    required this.description,
    required this.createdAt,
    required this.published,
    required this.photos,
  });
  final int id;
  final int eventId;
  final int participantCount;
  final int volunteerCount;
  final String description;
  final DateTime createdAt;
  final bool published;
  final List<String> photos;
  EventReport copyWith({
    int? id,
    int? eventId,
    int? participantCount,
    int? volunteerCount,
    String? description,
    DateTime? createdAt,
    bool? published,
    List<String>? photos,
  }) => EventReport(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    participantCount: participantCount ?? this.participantCount,
    volunteerCount: volunteerCount ?? this.volunteerCount,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
    published: published ?? this.published,
    photos: photos ?? this.photos,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'participantCount': participantCount,
    'volunteerCount': volunteerCount,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'published': published,
    'photos': photos,
  };
  factory EventReport.fromJson(Map<String, dynamic> j) => EventReport(
    id: j['id'] as int,
    eventId: j['eventId'] as int,
    participantCount: j['participantCount'] as int,
    volunteerCount: j['volunteerCount'] as int,
    description: j['description'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    published: j['published'] as bool,
    photos: List<String>.unmodifiable(j['photos'] as List),
  );
}
