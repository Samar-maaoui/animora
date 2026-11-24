import '../../../core/enums/volunteer_task_status.dart';
import '../models/volunteer_task.dart';

abstract interface class VolunteerTaskRepository {
  Future<List<VolunteerTask>> getTasks({int? eventId});
  Future<void> saveTask(VolunteerTask task, {required bool creating});
  Future<void> advanceTask(int id, VolunteerTaskStatus status);
}
