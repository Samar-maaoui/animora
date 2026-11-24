import '../../../core/database/database_platform.dart' as platform;
import '../../../core/database/media_platform.dart' as media;
import '../../../core/database/sql_module.dart';
import '../../adoption/database/business_user_source.dart';
import '../../adoption/database/sqlite_catalog_dao.dart';
import '../../adoption/database/sqlite_catalog_database.dart';
import '../../adoption/services/catalog_storage.dart';
import '../repositories/local_auth_repository.dart';
import '../repositories/sqlite_auth_repository.dart';
import 'auth_backend_model.dart';
import 'auth_security_store.dart';
import 'sqlite_auth_security_store.dart';
import 'auth_vault_native.dart';
import 'local_auth_storage.dart';
import 'sqlite_auth_storage.dart';
import '../data/demo_recovery.dart';

AuthBackend createAuthBackend() {
  if (!platform.supportsNativeSqlite) {
    return AuthBackend(
      LocalAuthRepository(
        storage: PreferencesAuthStorage(),
        recoverDemoAccounts: DemoRecovery.enabled,
        securityStore: PreferencesAuthSecurityStore(),
      ),
    );
  }
  final helper = platform.createPlatformDatabase();
  final legacy = PreferencesAuthStorage();
  final source = BusinessUserSource(legacy);
  final dao = SqliteCatalogDao();
  final catalog = SqliteCatalogDatabase(
    PreferencesCatalogStorage(),
    helper: helper,
    ownsHelper: false,
    loadBusinessUsers: () async {
      final db = await helper.database;
      if (await dao.metadata(db, SqliteAuthStorage.marker) != null) {
        return (await dao.readUsers(db)).values.toList();
      }
      return source.read();
    },
  );
  final context = SqliteModuleContext(
    helper: helper,
    catalog: catalog,
    loadUsers: catalog.loadBusinessUsers,
    mediaFactory: media.createMediaStorage,
  );
  final storage = SqliteAuthStorage(
    helper: helper,
    legacy: legacy,
    vault: const NativeAuthVault(),
    prepareCatalog: catalog.initialize,
  );
  return AuthBackend(
    SqliteAuthRepository(
      storage: storage,
      recoverDemoAccounts: DemoRecovery.enabled,
      securityStore: SqliteAuthSecurityStore(helper),
    ),
    context: context,
    close: () async {
      await storage.drain();
      await context.close();
    },
  );
}
