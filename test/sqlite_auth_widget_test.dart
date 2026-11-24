import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:animora/app/app.dart';
import 'package:animora/core/database/database_helper.dart';
import 'package:animora/core/database/sql_module.dart';
import 'package:animora/core/database/file_media_storage.dart';
import 'package:animora/features/adoption/database/sqlite_catalog_database.dart';
import 'package:animora/features/adoption/database/sqlite_catalog_dao.dart';
import 'package:animora/features/adoption/database/business_user_source.dart';
import 'package:animora/features/adoption/repositories/local_catalog_database.dart';
import 'package:animora/features/adoption/state/adoption_store.dart';
import 'package:animora/features/auth/services/auth_backend_model.dart';
import 'package:animora/features/auth/services/sqlite_auth_storage.dart';
import 'package:animora/features/auth/services/auth_vault.dart';
import 'package:animora/features/auth/services/password_hasher.dart';
import 'package:animora/features/auth/repositories/sqlite_auth_repository.dart';
import 'package:animora/features/auth/state/auth_session.dart';

import 'support/auth_test_support.dart';
import 'support/catalog_test_support.dart';
import 'sqlite_widget_test.dart' show runSqliteWidgetAsync;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await seedDatabase();
  });
  testWidgets(
    'Native auth and business modules boot share one database and preserve foreign keys',
    (t) async {
      final raw = (await t.runAsync(seedDatabase))!;
      final legacy = MemoryAuthStorage(raw);
      final helper = DatabaseHelper(
        factory: databaseFactoryFfiNoIsolate,
        pathOverride: inMemoryDatabasePath,
      );
      final dao = SqliteCatalogDao();
      final source = BusinessUserSource(legacy);
      final catalog = SqliteCatalogDatabase(
        MemoryCatalogStorage(),
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
      final storage = SqliteAuthStorage(
        helper: helper,
        legacy: legacy,
        vault: MemoryAuthVault(),
        prepareCatalog: catalog.initialize,
      );
      final repo = SqliteAuthRepository(
        storage: storage,
        hasher: const PasswordHasher(iterations: 10000),
      );
      final directory = (await t.runAsync(
        () => Directory.systemTemp.createTemp('animora-auth-ui-'),
      ))!;
      final runtime = SqliteModuleContext(
        helper: helper,
        catalog: catalog,
        loadUsers: catalog.loadBusinessUsers,
        mediaFactory: (name, old) =>
            FileMediaStorage(name, old, directory: directory.path),
      );
      addTearDown(() async {
        await t.pumpWidget(const SizedBox.shrink());
        await runSqliteWidgetAsync(t, () async {
          await storage.drain();
          await runtime.close();
        });
        repo.dispose();
      });
      await t.runAsync(
        () => t.pumpWidget(
          AnimoraApp(backend: AuthBackend(repo, context: runtime)),
        ),
      );
      await runSqliteWidgetAsync(t, repo.initialize);
      for (var i = 0; i < 10; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(find.text('Commencer'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('welcome-start')));
      await t.pumpAndSettle();
      expect(find.text('Se connecter'), findsOneWidget);
      final element = t.element(find.byType(Scaffold).first);
      final session = element.read<AuthSession>();
      expect(session.ready, true);
      expect(session.initializationError, isNull);
      await runSqliteWidgetAsync(
        t,
        () => session.login('citizen@animora.test', 'Animora2026!'),
      );
      await t.pumpAndSettle();
      final home = t.element(find.byType(Scaffold).first);
      final sql = home.read<LocalCatalogDatabase>();
      expect(sql, isA<SqliteCatalogDatabase>());
      expect(identical((sql as SqliteCatalogDatabase).helper, helper), true);
      final store = home.read<AdoptionStore>();
      await runSqliteWidgetAsync(
        t,
        () => store.favoriteRepository.addFavorite(1),
      );
      final rows = (await runSqliteWidgetAsync(
        t,
        () async => (await helper.database).query('favorites'),
      ))!;
      expect(rows.single['userId'], 'demo-citizen');
      expect(
        (await runSqliteWidgetAsync(
          t,
          () async =>
              (await helper.database).rawQuery('PRAGMA foreign_key_check'),
        ))!,
        isEmpty,
      );
      expect(legacy.value, raw);
      expect(t.takeException(), isNull);
    },
  );
}
