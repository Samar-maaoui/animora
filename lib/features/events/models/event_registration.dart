import '../../../core/enums/registration_type.dart';
import '../../../core/enums/registration_status.dart';

class EventRegistration {
  const EventRegistration({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.registrationDate,
    required this.type,
    required this.status,
    required this.userName,
  });
  final int id;
  final int eventId;
  final String userId;
  final DateTime registrationDate;
  final RegistrationType type;
  final RegistrationStatus status;
  final String userName;
  EventRegistration copyWith({
    int? id,
    int? eventId,
    String? userId,
    DateTime? registrationDate,
    RegistrationType? type,
    RegistrationStatus? status,
    String? userName,
  }) => EventRegistration(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    userId: userId ?? this.userId,
    registrationDate: registrationDate ?? this.registrationDate,
    type: type ?? this.type,
    status: status ?? this.status,
    userName: userName ?? this.userName,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'userId': userId,
    'registrationDate': registrationDate.toIso8601String(),
    'type': type.name,
    'status': status.name,
    'userName': userName,
  };
  factory EventRegistration.fromJson(Map<String, dynamic> j) =>
      EventRegistration(
        id: j['id'] as int,
        eventId: j['eventId'] as int,
        userId: j['userId'] as String,
        registrationDate: DateTime.parse(j['registrationDate'] as String),
        type: RegistrationType.values.byName(j['type'] as String),
        status: RegistrationStatus.values.byName(j['status'] as String),
        userName: j['userName'] as String,
      );
}
