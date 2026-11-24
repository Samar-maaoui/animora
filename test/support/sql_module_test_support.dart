import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:animora/core/database/database_helper.dart';
import 'package:animora/core/database/file_media_storage.dart';
import 'package:animora/core/database/sql_module.dart';
import 'package:animora/features/adoption/database/sqlite_catalog_database.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/users/models/user.dart';

import 'catalog_test_support.dart';

class ModuleHarness {
  ModuleHarness._(this.directory, this.helper, this.catalog) {
    context = SqliteModuleContext(
      helper: helper,
      catalog: catalog,
      loadUsers: () async => users.values.toList(),
      mediaFactory: (name, legacy) =>
          FileMediaStorage(name, legacy, directory: directory.path),
    );
  }
  static Future<ModuleHarness> create({
    String? path,
    Directory? mediaDirectory,
    MemoryCatalogStorage? legacyCatalog,
  }) async {
    sqfliteFfiInit();
    final directory =
        mediaDirectory ?? await Directory.systemTemp.createTemp('animora8b-');
    final helper = DatabaseHelper(
      factory: databaseFactoryFfi,
      pathOverride: path ?? inMemoryDatabasePath,
    );
    final catalog = SqliteCatalogDatabase(
      legacyCatalog ?? MemoryCatalogStorage(),
      helper: helper,
      loadBusinessUsers: () async => DemoAccounts.users,
      ownsHelper: false,
    );
    return ModuleHarness._(directory, helper, catalog);
  }

  final Directory directory;
  final DatabaseHelper helper;
  final SqliteCatalogDatabase catalog;
  late final SqliteModuleContext context;
  User? actor = DemoAccounts.users.firstWhere((u) => u.id == 'demo-citizen');
  final users = {for (final u in DemoAccounts.users) u.id: u};
  User get admin => users['demo-admin']!;
  User get citizen => users['demo-citizen']!;
  User get other => users['demo-foster']!;
  Future<void> close() => context.close();
}
