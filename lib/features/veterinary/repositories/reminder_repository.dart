import '../models/reminder.dart';

abstract interface class ReminderRepository {
  Future<List<Reminder>> getReminders(int animalId);
  Future<void> addReminder(int animalId, String type, DateTime date);
}
