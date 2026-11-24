import 'local_services_repository.dart';

/// Keeps existing access checks and business rules, backed by relational storage.
class SqliteServicesRepository extends LocalServicesRepository {
  SqliteServicesRepository(
    super.database,
    super.catalog,
    super.currentUser,
    super.listProviders, {
    super.clock,
  });
}
