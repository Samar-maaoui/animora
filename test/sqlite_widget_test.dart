import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:animora/core/database/database_helper.dart';
import 'package:animora/core/enums/animal_status.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/adoption/database/business_user_source.dart';
import 'package:animora/features/adoption/database/sqlite_catalog_database.dart';
import 'package:animora/features/adoption/repositories/local_catalog_database.dart';
import 'package:animora/features/adoption/state/adoption_workflow_store.dart';
import 'package:animora/features/adoption/screens/animal_details_screen.dart';
import 'package:animora/features/adoption/screens/adoption_questionnaire_screen.dart';
import 'package:animora/features/adoption/screens/my_adoptions_screen.dart';
import 'package:animora/features/adoption/screens/adoption_contract_screen.dart';
import 'package:animora/features/animal_services/widgets/services_scope.dart';
import 'package:animora/features/animal_services/widgets/services_widgets.dart'
    show ServicePage;

import 'widget_test.dart' show mountApp;
import 'support/auth_test_support.dart';
import 'services_widget_test.dart' show flush, tapAction;
import 'adoption_widget_test.dart' show selectFilter;
import 'adoption_workflow_repository_test.dart' show answers, motivation;

(DatabaseHelper, BusinessUserSource) widgetSql8() {
  final helper = DatabaseHelper(
    factory: databaseFactoryFfiNoIsolate,
    pathOverride: inMemoryDatabasePath,
  );
  final profiles = BusinessUserSource(
    MemoryAuthStorage(
      jsonEncode({
        'version': 1,
        'accounts': [
          for (final u in DemoAccounts.users) {'user': u.toJson()},
        ],
      }),
    ),
  );
  return (helper, profiles);
}

/// Keep FakeAsync store callbacks moving while awaiting real SQLite completion.
Future<T?> runSqliteWidgetAsync<T>(
  WidgetTester tester,
  Future<T> Function() action,
) async {
  T? result;
  Object? error;
  StackTrace? trace;
  bool done = false;
  await tester.runAsync(() async {
    unawaited(
      Future<T>.sync(action).then<void>(
        (value) {
          result = value;
          done = true;
        },
        onError: (Object e, StackTrace s) {
          error = e;
          trace = s;
          done = true;
        },
      ),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!done && DateTime.now().isBefore(deadline)) {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });
  if (!done) {
    throw TestFailure(
      'SQLite operation did not complete while pumping pending callbacks.',
    );
  }
  if (error != null) Error.throwWithStackTrace(error!, trace!);
  return result;
}

/// Real FFI completion and pending FakeAsync store callbacks must both run.
Future<void> closeSqliteWidget(
  WidgetTester tester,
  DatabaseHelper helper,
) async {
  final scaffold = find.byType(Scaffold);
  final catalog = scaffold.evaluate().isEmpty
      ? null
      : tester.element(scaffold.first).read<LocalCatalogDatabase>();
  await tester.runAsync(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    bool done = false;
    Object? error;
    StackTrace? trace;
    final closing = catalog is SqliteCatalogDatabase
        ? catalog.close()
        : helper.close();
    unawaited(
      closing.then(
        (_) => done = true,
        onError: (Object e, StackTrace s) {
          error = e;
          trace = s;
          done = true;
        },
      ),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!done && DateTime.now().isBefore(deadline)) {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    if (!done) {
      throw TestFailure(
        'SQLite cleanup did not complete while pumping pending store callbacks.',
      );
    }
    if (error != null) Error.throwWithStackTrace(error!, trace!);
  });
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await seedDatabase();
    final warm = DatabaseHelper(
      factory: databaseFactoryFfiNoIsolate,
      pathOverride: inMemoryDatabasePath,
    );
    await warm.database;
    await warm.close();
  });
  testWidgets('Existing favorite screens write and remove actual SQLite rows', (
    t,
  ) async {
    final (helper, profiles) = widgetSql8();
    addTearDown(() => closeSqliteWidget(t, helper));
    final (_, router) = await mountApp(
      t,
      account: 'citizen',
      path: '/animals/1',
      catalogDatabaseHelper: helper,
      catalogBusinessUsers: profiles,
    );
    await flush(t);
    expect(
      t.element(find.byType(AnimalDetailsScreen)).read<LocalCatalogDatabase>(),
      isA<SqliteCatalogDatabase>(),
    );
    await tapAction(t, find.byKey(const ValueKey('favorite-1')));
    final rows = (await runSqliteWidgetAsync(
      t,
      () async => (await helper.database).query('favorites'),
    ))!;
    expect(rows.single['animalId'], 1);
    router.go('/favorites');
    await flush(t);
    expect(find.text('Luna'), findsOneWidget);
    await tapAction(t, find.byKey(const ValueKey('favorite-1')));
    expect(
      (await runSqliteWidgetAsync(
        t,
        () async => (await helper.database).query('favorites'),
      ))!,
      isEmpty,
    );
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Existing adoption wizard persists SQL adoption questionnaire and business user',
    (t) async {
      final (helper, profiles) = widgetSql8();
      addTearDown(() => closeSqliteWidget(t, helper));
      await mountApp(
        t,
        account: 'citizen',
        path: '/adoptions/new/1',
        catalogDatabaseHelper: helper,
        catalogBusinessUsers: profiles,
      );
      await flush(t);
      expect(find.byType(AdoptionQuestionnaireScreen), findsOneWidget);
      await selectFilter(t, 'Type de logement', 'Maison avec jardin');
      await selectFilter(t, 'Avez-vous des enfants ?', 'Non');
      await selectFilter(t, 'Avez-vous d’autres animaux ?', 'Non');
      await selectFilter(
        t,
        'Expérience avec les animaux',
        'Expérience régulière',
      );
      await selectFilter(
        t,
        'Temps quotidien disponible',
        'Plus de deux heures',
      );
      await tapAction(t, find.text('Continuer'));
      await t.enterText(find.byType(TextFormField), motivation);
      await tapAction(t, find.text('Continuer'));
      await tapAction(t, find.text('Confirmer la demande'));
      final counts = await runSqliteWidgetAsync(t, () async {
        final db = await helper.database;
        return [
          (await db.query('adoptions')).length,
          (await db.query('adoption_questionnaires')).length,
          (await db.query('users')).length,
        ];
      });
      expect(counts, [1, 1, 7]);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'SQL admin acceptance contract signing and health integration preserve existing flows',
    (t) async {
      final (helper, profiles) = widgetSql8();
      addTearDown(() => closeSqliteWidget(t, helper));
      final (session, router) = await mountApp(
        t,
        account: 'citizen',
        path: '/adoptions/my',
        catalogDatabaseHelper: helper,
        catalogBusinessUsers: profiles,
      );
      await flush(t);
      final store = t
          .element(find.byType(MyAdoptionsScreen))
          .read<AdoptionWorkflowStore>();
      final a = (await runSqliteWidgetAsync(
        t,
        () => store.adoptions.submitAdoption(1, answers(), motivation),
      ))!;
      await runSqliteWidgetAsync(
        t,
        () => session.login('admin@animora.test', DemoAccounts.password),
      );
      router.go('/adoptions/${a.id}');
      await flush(t);
      await tapAction(t, find.text('Accepter la demande'));
      await tapAction(t, find.widgetWithText(FilledButton, 'Confirmer'));
      await runSqliteWidgetAsync(
        t,
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      router.go('/adoptions/${a.id}/contract');
      await flush(t);
      expect(find.byType(AdoptionContractScreen), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      await flush(t);
      await tapAction(t, find.byType(CheckboxListTile));
      await tapAction(t, find.text('Accepter et signer le contrat'));
      await tapAction(t, find.widgetWithText(FilledButton, 'Confirmer'));
      final raw = (await runSqliteWidgetAsync(
        t,
        () async => (await helper.database).query('adoption_contracts'),
      ))!;
      expect(raw.single['signed'], 1);
      expect(
        (await runSqliteWidgetAsync(
          t,
          () => store.adoptions.getAdoption(a.id),
        ))!.animal.status,
        AnimalStatus.ADOPTED,
      );
      router.go('/health');
      await flush(t);
      expect(find.text('Luna'), findsOneWidget);
      final services = t
          .element(find.byType(ServicePage))
          .read<ServicesStore>();
      expect(
        (await runSqliteWidgetAsync(
          t,
          () => services.veterinary.getResponsibleAnimals(),
        ))!.single.id,
        1,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'SQL favorite isolation survives account changes through existing navigation',
    (t) async {
      final (helper, profiles) = widgetSql8();
      addTearDown(() => closeSqliteWidget(t, helper));
      final (session, router) = await mountApp(
        t,
        account: 'citizen',
        path: '/animals/1',
        catalogDatabaseHelper: helper,
        catalogBusinessUsers: profiles,
      );
      await flush(t);
      await tapAction(t, find.byKey(const ValueKey('favorite-1')));
      await runSqliteWidgetAsync(
        t,
        () => session.login('veterinarian@animora.test', DemoAccounts.password),
      );
      router.go('/favorites');
      await flush(t);
      expect(find.text('Aucun favori'), findsOneWidget);
      expect(find.text('Luna'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
}
