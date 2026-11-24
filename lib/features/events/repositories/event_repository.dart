import '../../../core/enums/event_status.dart';
import '../models/event.dart';

import 'dart:typed_data';

abstract interface class EventRepository {
  Future<List<Event>> getEvents();
  Future<int> availablePlaces(int eventId);
  Future<Event> getEvent(int id);
  Future<Event> saveEvent(
    Event value, {
    required bool creating,
    Uint8List? imageBytes,
  });
  Future<void> changeEventStatus(int id, EventStatus status);
  Future<Uint8List?> eventPhoto(int eventId);
}
