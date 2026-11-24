import '../models/event_registration.dart';
import '../models/event_ticket.dart';

abstract interface class EventTicketRepository {
  Future<EventTicket?> ticketForRegistration(int registrationId);
  Future<EventTicket> getTicket(int id);
  Future<EventRegistration> checkIn(int eventId, String code);
}
