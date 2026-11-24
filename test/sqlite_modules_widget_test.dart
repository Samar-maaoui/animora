import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:animora/core/database/database_helper.dart';
import 'package:animora/core/database/sql_module.dart';
import 'package:animora/core/database/file_media_storage.dart';
import 'package:animora/features/adoption/database/sqlite_catalog_database.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/reports/repositories/local_reports_repository.dart';
import 'package:animora/features/animal_services/widgets/services_scope.dart';
import 'package:animora/features/donations/widgets/donations_scope.dart';
import 'package:animora/features/events/widgets/events_scope.dart';
import 'package:animora/features/reports/database/sqlite_reports_database.dart';
import 'package:animora/features/animal_services/database/sqlite_animal_services_database.dart';
import 'package:animora/features/donations/database/sqlite_donations_database.dart';
import 'package:animora/features/events/database/sqlite_events_database.dart';

import 'widget_test.dart' show mountApp;
import 'sqlite_widget_test.dart' show runSqliteWidgetAsync;
import 'reports_repository_test.dart' show reportDraft;
import 'support/auth_test_support.dart' show seedDatabase;
import 'support/catalog_test_support.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await seedDatabase();
  });
  testWidgets(
    'All feature scopes use one SQLite context and routes reload after commit',
    (t) async {
      final directory = (await t.runAsync(
        () => Directory.systemTemp.createTemp('animora-widget8b-'),
      ))!;
      final helper = DatabaseHelper(
        factory: databaseFactoryFfiNoIsolate,
        pathOverride: inMemoryDatabasePath,
      );
      final catalog = SqliteCatalogDatabase(
        MemoryCatalogStorage(),
        helper: helper,
        ownsHelper: false,
        loadBusinessUsers: () async => DemoAccounts.users,
      );
      final runtime = SqliteModuleContext(
        helper: helper,
        catalog: catalog,
        loadUsers: () async => DemoAccounts.users,
        mediaFactory: (name, legacy) =>
            FileMediaStorage(name, legacy, directory: directory.path),
      );
      addTearDown(() async {
        await t.pumpWidget(const SizedBox.shrink());
        await runSqliteWidgetAsync(t, runtime.close);
      });
      final (_, router) = await mountApp(
        t,
        account: 'citizen',
        path: '/reports',
        moduleContext: runtime,
      );
      final element = t.element(find.byType(Scaffold).first);
      final reports = element.read<LocalReportsRepository>();
      expect(reports.database, isA<SqliteReportsDatabase>());
      expect(
        element.read<ServicesStore>().database,
        isA<SqliteServicesDatabase>(),
      );
      expect(
        element.read<DonationsStore>().database,
        isA<SqliteDonationsDatabase>(),
      );
      expect(element.read<EventsStore>().database, isA<SqliteEventsDatabase>());
      await runSqliteWidgetAsync(t, () => reports.createReport(reportDraft()));
      router.go('/reports');
      await runSqliteWidgetAsync(t, () => runtime.ensure('events'));
      await t.pumpAndSettle();
      expect(
        (await runSqliteWidgetAsync(
          t,
          () async => (await helper.database).query('reports'),
        ))!.length,
        1,
      );
      router.go('/reports/1');
      await runSqliteWidgetAsync(t, () => runtime.ensure('events'));
      await t.pumpAndSettle();
      expect(find.text('Un chien blessé près du parc.'), findsOneWidget);
      for (final route in [
        '/veterinary',
        '/pet-sitting',
        '/donations',
        '/events',
      ]) {
        router.go(route);
        await runSqliteWidgetAsync(t, () => runtime.ensure('events'));
        await t.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, route);
        expect(find.byType(Scaffold), findsWidgets);
        expect(t.takeException(), isNull);
      }
      final markers = (await runSqliteWidgetAsync(
        t,
        () async => (await helper.database).query(
          'database_metadata',
          where: "key LIKE 'sembast_%'",
        ),
      ))!;
      expect(markers.length, 4);
      expect(t.takeException(), isNull);
    },
  );
}
