import '../models/veterinary_appointment.dart';
import '../../../core/enums/appointment_status.dart';

abstract interface class VeterinaryAppointmentRepository {
  Future<List<VeterinaryAppointment>> getAppointments();
  Future<void> bookAppointment(int availabilityId, int animalId, String reason);
  Future<void> changeAppointmentStatus(
    int id,
    AppointmentStatus status, {
    String? notes,
  });
  Future<void> saveConsultationNotes(int id, String notes);
}
