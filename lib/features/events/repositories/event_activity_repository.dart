import '../models/event_activity.dart';

abstract interface class EventActivityRepository {
  Future<List<EventActivity>> getActivities(int eventId);
  Future<void> saveActivity(EventActivity activity, {required bool creating});
  Future<void> deleteActivity(int id);
}
