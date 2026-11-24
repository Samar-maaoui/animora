import 'local_event_repository.dart';

/// Keeps existing access checks and business rules, backed by relational storage.
class SqliteEventRepository extends LocalEventRepository {
  SqliteEventRepository(
    super.database,
    super.currentUser,
    super.isUserActive, {
    super.clock,
  });
}
