import '../../../core/enums/appointment_status.dart';

const _unset = Object();

class VeterinaryAppointment {
  const VeterinaryAppointment({
    required this.id,
    required this.veterinarianUserId,
    required this.clientUserId,
    required this.animalId,
    required this.availabilityId,
    required this.appointmentDate,
    required this.reason,
    required this.status,
    this.notes,
    required this.clientName,
    required this.veterinarianName,
    required this.animalName,
  });
  final int id;
  final String veterinarianUserId;
  final String clientUserId;
  final int animalId;
  final int availabilityId;
  final DateTime appointmentDate;
  final String reason;
  final AppointmentStatus status;
  final String? notes;
  final String clientName;
  final String veterinarianName;
  final String animalName;
  VeterinaryAppointment copyWith({
    int? id,
    String? veterinarianUserId,
    String? clientUserId,
    int? animalId,
    int? availabilityId,
    DateTime? appointmentDate,
    String? reason,
    AppointmentStatus? status,
    Object? notes = _unset,
    String? clientName,
    String? veterinarianName,
    String? animalName,
  }) => VeterinaryAppointment(
    id: id ?? this.id,
    veterinarianUserId: veterinarianUserId ?? this.veterinarianUserId,
    clientUserId: clientUserId ?? this.clientUserId,
    animalId: animalId ?? this.animalId,
    availabilityId: availabilityId ?? this.availabilityId,
    appointmentDate: appointmentDate ?? this.appointmentDate,
    reason: reason ?? this.reason,
    status: status ?? this.status,
    notes: notes == _unset ? this.notes : notes as String?,
    clientName: clientName ?? this.clientName,
    veterinarianName: veterinarianName ?? this.veterinarianName,
    animalName: animalName ?? this.animalName,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'veterinarianUserId': veterinarianUserId,
    'clientUserId': clientUserId,
    'animalId': animalId,
    'availabilityId': availabilityId,
    'appointmentDate': appointmentDate.toIso8601String(),
    'reason': reason,
    'status': status.name,
    'notes': notes,
    'clientName': clientName,
    'veterinarianName': veterinarianName,
    'animalName': animalName,
  };
  factory VeterinaryAppointment.fromJson(Map<String, dynamic> j) =>
      VeterinaryAppointment(
        id: j['id'] as int,
        veterinarianUserId: j['veterinarianUserId'] as String,
        clientUserId: j['clientUserId'] as String,
        animalId: j['animalId'] as int,
        availabilityId: j['availabilityId'] as int,
        appointmentDate: DateTime.parse(j['appointmentDate'] as String),
        reason: j['reason'] as String,
        status: AppointmentStatus.values.byName(j['status'] as String),
        notes: j['notes'] == null ? null : j['notes'] as String,
        clientName: j['clientName'] as String,
        veterinarianName: j['veterinarianName'] as String,
        animalName: j['animalName'] as String,
      );
}
