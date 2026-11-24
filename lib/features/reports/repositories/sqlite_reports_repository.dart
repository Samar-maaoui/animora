import 'local_reports_repository.dart';
import '../database/sqlite_reports_database.dart';

class SqliteReportsRepository extends LocalReportsRepository {
  SqliteReportsRepository(
    SqliteReportsDatabase super.database,
    super.currentUser,
  );
}
