import '../../../core/enums/registration_type.dart';
import '../models/event_registration.dart';

abstract interface class EventRegistrationRepository {
  Future<List<EventRegistration>> getRegistrations({int? eventId});
  Future<EventRegistration> register(
    int eventId,
    RegistrationType type, {
    bool acceptWaitlist = false,
  });
  Future<void> cancelRegistration(int id);
  Future<List<EventRegistration>> eligibleVolunteers(int eventId);
}
