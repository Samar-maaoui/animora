import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:animora/core/enums/adoption_status.dart';
import 'package:animora/core/enums/animal_status.dart';
import 'package:animora/features/adoption/screens/adoption_details_screen.dart';
import 'package:animora/features/adoption/screens/adoption_questionnaire_screen.dart';
import 'package:animora/features/adoption/screens/my_adoptions_screen.dart';
import 'package:animora/features/adoption/screens/adoption_contract_screen.dart';
import 'package:animora/features/adoption/screens/foster_placement_details_screen.dart';
import 'package:animora/features/adoption/state/adoption_workflow_store.dart';
import 'package:animora/features/adoption/services/adoption_compatibility_service.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';

import 'widget_test.dart' show mountApp;
import 'adoption_widget_test.dart' show flush, tapAction, selectFilter;
import 'adoption_workflow_repository_test.dart' show answers, motivation;
import 'support/auth_test_support.dart';

AdoptionWorkflowStore workflow(WidgetTester tester, Type type) =>
    tester.element(find.byType(type).first).read<AdoptionWorkflowStore>();
Future<void> choose<T>(WidgetTester tester, String value) async {
  final field = find.byType(DropdownButton<T>).first;
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(seedDatabase);
  testWidgets(
    'Questionnaire requires all answers, explains score, confirms and persists one request',
    (tester) async {
      await mountApp(tester, account: 'citizen', path: '/adoptions/new/1');
      final store = workflow(tester, AdoptionQuestionnaireScreen);
      await tapAction(tester, find.text('Continuer'));
      expect(find.text('Réponse obligatoire.'), findsNWidgets(5));
      await selectFilter(
        tester,
        'Type de logement',
        AdoptionCompatibilityService.housingTypes[1],
      );
      await selectFilter(tester, 'Avez-vous des enfants ?', 'Non');
      await selectFilter(tester, 'Avez-vous d’autres animaux ?', 'Non');
      await selectFilter(
        tester,
        'Expérience avec les animaux',
        AdoptionCompatibilityService.experiences[2],
      );
      await selectFilter(
        tester,
        'Temps quotidien disponible',
        AdoptionCompatibilityService.availableTimes[2],
      );
      await tapAction(tester, find.text('Continuer'));
      expect(find.text('Compatibilité : 100.0 %'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), motivation);
      await tapAction(tester, find.text('Continuer'));
      expect(find.text('Récapitulatif pour Luna'), findsOneWidget);
      await tapAction(tester, find.text('Confirmer la demande'));
      expect(find.byType(AdoptionDetailsScreen), findsOneWidget);
      final list = await tester.runAsync(() => store.adoptions.getAdoptions());
      expect(list!.length, 1);
      expect(list.single.status, AdoptionStatus.PENDING);
    },
  );
  testWidgets(
    'Admin decision is confirmed, owner signs simulated contract and publishes follow-up',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'citizen',
        path: '/adoptions/my',
      );
      final store = workflow(tester, MyAdoptionsScreen);
      final a = (await tester.runAsync(
        () => store.adoptions.submitAdoption(1, answers(), motivation),
      ))!;
      await tester.runAsync(() async {
        await session.logout();
        await session.login('admin@animora.test', DemoAccounts.password);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      router.go('/adoptions/${a.id}');
      await flush(tester);
      await tapAction(tester, find.text('Accepter la demande'));
      expect(find.text('Accepter cette demande ?'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(() => store.adoptions.getAdoption(a.id)))!
            .adoption
            .status,
        AdoptionStatus.PENDING,
      );
      await tapAction(tester, find.text('Accepter la demande'));
      await tapAction(tester, find.text('Confirmer'));
      expect(find.text('Consulter le contrat'), findsOneWidget);
      await tester.runAsync(() async {
        await session.logout();
        await session.login('citizen@animora.test', DemoAccounts.password);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      router.go('/adoptions/${a.id}/contract');
      await flush(tester);
      await tester.pump(const Duration(seconds: 5));
      await flush(tester);
      expect(find.byType(AdoptionContractScreen), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                'Accepter et signer le contrat',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tapAction(tester, find.text('Accepter et signer le contrat'));
      expect(
        find.text('Confirmer la signature de démonstration ?'),
        findsOneWidget,
      );
      await tapAction(tester, find.text('Confirmer'));
      expect(find.text('Contrat signé en démonstration'), findsOneWidget);
      expect(
        (await tester.runAsync(() => store.adoptions.getAdoption(a.id)))!
            .animal
            .status,
        AnimalStatus.ADOPTED,
      );
      router.go('/adoptions/${a.id}/follow-up');
      await flush(tester);
      const news =
          'Luna mange bien et découvre tranquillement sa nouvelle maison.';
      await tester.enterText(find.byType(TextFormField), news);
      await choose<String>(tester, 'Nouvelles à domicile');
      await tapAction(tester, find.text('Publier les nouvelles'));
      expect(find.text(news), findsOneWidget);
    },
  );
  testWidgets(
    'Private request, contract and follow-up URLs never reveal another account data',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'citizen',
        path: '/adoptions/my',
      );
      final store = workflow(tester, MyAdoptionsScreen);
      final a = (await tester.runAsync(
        () => store.adoptions.submitAdoption(1, answers(), motivation),
      ))!;
      await tester.runAsync(() async {
        await session.logout();
        await session.login('veterinarian@animora.test', DemoAccounts.password);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      for (final suffix in ['', '/contract', '/follow-up']) {
        router.go('/adoptions/${a.id}$suffix');
        await flush(tester);
        expect(
          find.text('Demande introuvable ou accès refusé.'),
          findsOneWidget,
        );
        expect(find.text(motivation), findsNothing);
        expect(find.text('amine@example.com'), findsNothing);
      }
    },
  );
  testWidgets(
    'Admin assigns a foster placement; family adds a remark and starts conversion questionnaire',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'admin',
        path: '/admin/foster-placements',
      );
      await choose<int>(tester, 'Luna');
      await choose<String>(tester, 'Karim Saidi');
      await tapAction(tester, find.text('Affecter à la famille'));
      await tapAction(tester, find.text('Confirmer'));
      expect(find.text('Luna'), findsOneWidget);
      await tester.runAsync(() async {
        await session.logout();
        await session.login('foster@animora.test', DemoAccounts.password);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      router.go('/foster-family');
      await flush(tester);
      await tapAction(tester, find.text('Luna'));
      expect(find.byType(FosterPlacementDetailsScreen), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        'Luna s’adapte très bien à son accueil.',
      );
      await tapAction(tester, find.text('Enregistrer la remarque'));
      ScaffoldMessenger.of(
        tester.element(find.byType(FosterPlacementDetailsScreen)),
      ).clearSnackBars();
      await tester.pump(const Duration(seconds: 5));
      await flush(tester);
      await tapAction(tester, find.text('Demander l’adoption définitive'));
      expect(find.byType(AdoptionQuestionnaireScreen), findsOneWidget);
      expect(find.text('Étape 1 sur 3'), findsOneWidget);
    },
  );
  for (final path in [
    '/admin/adoptions',
    '/admin/foster-placements',
    '/foster-family',
    '/foster-family/1',
  ]) {
    testWidgets('Citizen is denied access to $path', (tester) async {
      final (_, router) = await mountApp(
        tester,
        account: 'citizen',
        path: path,
      );
      expect(router.routeInformationProvider.value.uri.path, '/access-denied');
    });
  }
  testWidgets('New adoption and foster screens fit a narrow mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (_, router) = await mountApp(
      tester,
      account: 'admin',
      path: '/admin/foster-placements',
    );
    expect(tester.takeException(), isNull);
    router.go('/adoptions/new/1');
    await flush(tester);
    expect(tester.takeException(), isNull);
    router.go('/adoptions/my');
    await flush(tester);
    expect(tester.takeException(), isNull);
  });
}
