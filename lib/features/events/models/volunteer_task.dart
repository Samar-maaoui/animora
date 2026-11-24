import '../../../core/enums/volunteer_task_status.dart';

const _unset = Object();

class VolunteerTask {
  const VolunteerTask({
    required this.id,
    required this.eventId,
    required this.title,
    required this.description,
    this.assignedUserId,
    required this.status,
  });
  final int id;
  final int eventId;
  final String title;
  final String description;
  final String? assignedUserId;
  final VolunteerTaskStatus status;
  VolunteerTask copyWith({
    int? id,
    int? eventId,
    String? title,
    String? description,
    Object? assignedUserId = _unset,
    VolunteerTaskStatus? status,
  }) => VolunteerTask(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    title: title ?? this.title,
    description: description ?? this.description,
    assignedUserId: assignedUserId == _unset
        ? this.assignedUserId
        : assignedUserId as String?,
    status: status ?? this.status,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'title': title,
    'description': description,
    'assignedUserId': assignedUserId,
    'status': status.name,
  };
  factory VolunteerTask.fromJson(Map<String, dynamic> j) => VolunteerTask(
    id: j['id'] as int,
    eventId: j['eventId'] as int,
    title: j['title'] as String,
    description: j['description'] as String,
    assignedUserId: j['assignedUserId'] as String?,
    status: VolunteerTaskStatus.values.byName(j['status'] as String),
  );
}
