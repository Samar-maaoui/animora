import '../services/sqlite_auth_storage.dart';
import 'local_auth_repository.dart';

class SqliteAuthRepository extends LocalAuthRepository {
  SqliteAuthRepository({
    required SqliteAuthStorage super.storage,
    super.hasher,
    super.recoverDemoAccounts,
    super.securityStore,
    super.clock,
  });
}
