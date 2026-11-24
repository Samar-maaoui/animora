import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:animora/core/enums/adoption_status.dart';
import 'package:animora/core/enums/appointment_status.dart';
import 'package:animora/core/enums/pet_sitting_status.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/adoption/models/adoption.dart';
import 'package:animora/features/adoption/models/contrat_adoption.dart';
import 'package:animora/features/animal_services/widgets/services_scope.dart';
import 'package:animora/features/animal_services/widgets/services_widgets.dart'
    show ServicePage;
import 'package:animora/features/veterinary/screens/health_screens.dart';
import 'package:animora/features/veterinary/models/availability.dart';
import 'package:animora/features/pet_sitting/models/pet_sitter_settings.dart';

import 'support/auth_test_support.dart';
import 'widget_test.dart' show mountApp;

Future<void> flush(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.runAsync(() async {
      await t.pump();
      await Future<void>.delayed(const Duration(milliseconds: 15));
    });
  }
  await t.pumpAndSettle();
}

Future<void> tapAction(WidgetTester t, Finder target) async {
  t.testTextInput.hide();
  FocusManager.instance.primaryFocus?.unfocus();
  await flush(t);
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  await t.runAsync(() async {
    await t.tap(target);
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });
  await flush(t);
}

ServicesStore store(WidgetTester t) =>
    t.element(find.byType(ServicePage).first).read<ServicesStore>();
Future<void> assign(WidgetTester t, ServicesStore s) async {
  await t.runAsync(
    () => s.repository.catalog.mutate((d) {
      final now = DateTime.now(), id = d.workflow.nextId++;
      d.workflow.adoptions[id] = Adoption(
        id: id,
        userId: 'demo-citizen',
        animalId: 1,
        applicationDate: now,
        motivation: 'Fixture adoption signée',
        compatibilityScore: 80,
        status: AdoptionStatus.ACCEPTED,
        adoptionDate: now,
      );
      d.workflow.contracts[id] = ContratAdoption(
        id: d.workflow.nextId++,
        adoptionId: id,
        conditions: 'Fixture',
        signed: true,
        signatureDate: now,
      );
    }),
  );
  await flush(t);
}

Future<void> chooseInt(WidgetTester t, int index, String label) async {
  await tapAction(t, find.byType(DropdownButtonFormField<int>).at(index));
  await tapAction(t, find.text(label).last);
}

void main() {
  setUpAll(seedDatabase);
  testWidgets(
    'Directory shows only active vets and searches without inventing specialty',
    (tester) async {
      await mountApp(tester, account: 'citizen', path: '/veterinary');
      await flush(tester);
      expect(find.text('Sarra Mansour'), findsOneWidget);
      expect(find.text('Nour Haddad'), findsNothing);
      await tester.enterText(find.byType(TextField), 'introuvable');
      await flush(tester);
      expect(
        find.text('Aucun vétérinaire actif ne correspond à ces critères.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Availability create edit and delete through UI', (tester) async {
    await mountApp(
      tester,
      account: 'veterinarian',
      path: '/veterinary/availability',
    );
    await flush(tester);
    await tapAction(tester, find.text('Ajouter une disponibilité'));
    await tapAction(tester, find.text('Enregistrer le créneau'));
    expect(find.text('Libre'), findsOneWidget);
    await tapAction(tester, find.text('Modifier'));
    expect(find.text('Modifier le créneau'), findsOneWidget);
    await tapAction(tester, find.text('Annuler').last);
    await tapAction(tester, find.text('Supprimer'));
    await tapAction(tester, find.widgetWithText(FilledButton, 'Confirmer'));
    await flush(tester);
    expect(find.textContaining('Aucun créneau.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Citizen books signed animal, vet accepts and patient records are accessible',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'veterinarian',
        path: '/veterinary/availability',
      );
      await flush(tester);
      final s = store(tester);
      await tapAction(tester, find.text('Ajouter une disponibilité'));
      await tapAction(tester, find.text('Enregistrer le créneau'));
      await assign(tester, s);
      await tester.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      router.go('/veterinary/book/demo-veterinarian');
      await flush(tester);
      await tapAction(tester, find.byType(DropdownButtonFormField<int>).at(0));
      await tapAction(tester, find.textContaining('09:00 – 10:00').last);
      await chooseInt(tester, 1, 'Luna');
      await tester.enterText(
        find.byType(TextField),
        'Consultation de contrôle pour notre chat Luna.',
      );
      await tapAction(tester, find.text('Demander le rendez-vous'));
      await tapAction(tester, find.widgetWithText(FilledButton, 'Confirmer'));
      await flush(tester);
      expect(find.text('En attente'), findsOneWidget);
      await tester.runAsync(
        () => session.login('veterinarian@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      router.go('/veterinary/dashboard');
      await flush(tester);
      await tapAction(tester, find.text('Accepter le rendez-vous'));
      await tapAction(tester, find.widgetWithText(FilledButton, 'Confirmer'));
      await flush(tester);
      expect(find.text('Confirmé'), findsOneWidget);
      await tapAction(tester, find.text('Notes de consultation').last);
      await tester.enterText(
        find.byType(TextField),
        'Notes privées de la consultation de démonstration.',
      );
      await tapAction(tester, find.text('Enregistrer les notes'));
      await flush(tester);
      await tapAction(tester, find.text('Carnet de santé'));
      await flush(tester);
      expect(find.byType(AnimalCareHistoryScreen), findsOneWidget);
      expect(find.text('Enregistrer un soin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Vet adds vaccination with reminder and care; responsible user can only read',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'veterinarian',
        path: '/veterinary/availability',
      );
      await flush(tester);
      final s = store(tester);
      await assign(tester, s);
      await tester.runAsync(
        () => s.availability.saveAvailability(
          Availability(
            id: 0,
            veterinarianUserId: '',
            date: DateTime.now().add(const Duration(days: 1)),
            startTime: 540,
            endTime: 600,
            isFree: true,
          ),
          creating: true,
        ),
      );
      final slot = (await tester.runAsync(
        () => s.availability.getAvailability('demo-veterinarian'),
      ))!.single;
      await tester.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      await tester.runAsync(
        () => s.appointments.bookAppointment(
          slot.id,
          1,
          'Contrôle général de notre compagnon.',
        ),
      );
      final id = (await tester.runAsync(
        () => s.appointments.getAppointments(),
      ))!.single.id;
      await tester.runAsync(
        () => session.login('veterinarian@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      await tester.runAsync(
        () => s.appointments.changeAppointmentStatus(
          id,
          AppointmentStatus.CONFIRMED,
        ),
      );
      router.go('/animals/1/vaccinations');
      await flush(tester);
      await tapAction(tester, find.text('Ajouter une vaccination'));
      await tester.enterText(
        find.byType(TextField).first,
        'Vaccin de démonstration',
      );
      await tapAction(tester, find.text('Prévoir une prochaine dose'));
      await tapAction(tester, find.text('Enregistrer').last);
      await flush(tester);
      expect(find.text('Vaccin de démonstration'), findsOneWidget);
      router.go('/animals/1/reminders');
      await flush(tester);
      expect(
        find.text('Prochaine dose : Vaccin de démonstration'),
        findsOneWidget,
      );
      router.go('/animals/1/health');
      await flush(tester);
      await tapAction(tester, find.text('Enregistrer un soin'));
      await tester.enterText(find.byType(TextField).at(0), 'Contrôle');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Soin de démonstration enregistré par le vétérinaire.',
      );
      await tester.enterText(find.byType(TextField).at(2), '25.5');
      await tapAction(tester, find.text('Enregistrer').last);
      await flush(tester);
      expect(find.text('Coût déclaré : 25.50 TND'), findsOneWidget);
      await tester.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      expect(find.text('Enregistrer un soin'), findsNothing);
      expect(find.text('Coût déclaré : 25.50 TND'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Pet-sitter configures tariff, citizen requests and sitter accepts',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'pet-sitter',
        path: '/pet-sitting/settings',
      );
      await flush(tester);
      final s = store(tester);
      await tester.enterText(find.byType(TextField), '30');
      await tapAction(tester, find.text('Accepter de nouvelles demandes'));
      await tapAction(tester, find.text('Enregistrer mes services'));
      await flush(tester);
      await assign(tester, s);
      await tester.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      router.go('/pet-sitting/request/demo-pet-sitter');
      await flush(tester);
      await chooseInt(tester, 0, 'Luna');
      await tester.enterText(
        find.byType(TextField),
        'Repas à heures fixes et promenade quotidienne.',
      );
      expect(find.textContaining('Prix estimé :'), findsOneWidget);
      await tapAction(tester, find.text('Confirmer la demande de garde'));
      await tapAction(tester, find.widgetWithText(FilledButton, 'Confirmer'));
      await flush(tester);
      expect(find.text('En attente'), findsOneWidget);
      await tester.runAsync(
        () => session.login('pet-sitter@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      router.go('/pet-sitting/dashboard');
      await flush(tester);
      await tapAction(tester, find.text('Accepter la garde'));
      await tapAction(tester, find.widgetWithText(FilledButton, 'Confirmer'));
      await flush(tester);
      expect(find.text('Acceptée'), findsOneWidget);
      expect(find.text('Démarrer la garde'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Private tracking shows updates and completed guard can be reviewed only once',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'pet-sitter',
        path: '/pet-sitting/settings',
      );
      await flush(tester);
      final s = store(tester);
      await assign(tester, s);
      final now = DateTime.now();
      await tester.runAsync(
        () => s.petSitting.savePetSitterSettings(
          PetSitterSettings(
            userId: '',
            available: true,
            dailyRate: 20,
            availableFrom: DateTime(now.year, now.month, now.day),
            availableUntil: now.add(const Duration(days: 20)),
          ),
        ),
      );
      await tester.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      await tester.runAsync(
        () => s.petSitting.createPetSittingRequest(
          'demo-pet-sitter',
          1,
          now.add(const Duration(days: 1)),
          now.add(const Duration(days: 2)),
          'Repas et promenades de notre compagnon.',
        ),
      );
      final request = (await tester.runAsync(
        () => s.petSitting.getPetSittingRequests(),
      ))!.single;
      // Fixtures arrange elapsed time; production transitions are covered in repository tests.
      await tester.runAsync(
        () => s.database.mutate((d) async {
          d.requests[request.id] = request.copyWith(
            status: PetSittingStatus.IN_PROGRESS,
            startDate: now.subtract(const Duration(hours: 1)),
            endDate: now.add(const Duration(hours: 1)),
          );
        }),
      );
      await tester.runAsync(
        () => session.login('pet-sitter@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      router.go('/pet-sitting/requests/${request.id}/tracking');
      await flush(tester);
      await tester.enterText(
        find.byType(TextField),
        'Tout va bien après la promenade.',
      );
      await tapAction(tester, find.text('Publier une nouvelle'));
      await flush(tester);
      expect(find.text('Tout va bien après la promenade.'), findsOneWidget);
      await tester.runAsync(
        () => session.login('foster@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      expect(find.text('Tout va bien après la promenade.'), findsNothing);
      expect(
        find.text('Cette garde est privée ou introuvable.'),
        findsOneWidget,
      );
      await tester.runAsync(
        () => s.database.mutate((d) async {
          d.requests[request.id] = d.requests[request.id]!.copyWith(
            status: PetSittingStatus.COMPLETED,
          );
        }),
      );
      await tester.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      router.go('/pet-sitting/requests/${request.id}/review');
      await flush(tester);
      await tester.enterText(
        find.byType(TextField),
        'Une garde attentive avec des nouvelles régulières.',
      );
      await tapAction(tester, find.text('Publier mon avis'));
      await tapAction(tester, find.widgetWithText(FilledButton, 'Confirmer'));
      await flush(tester);
      expect(find.text('Note moyenne : 5.0 / 5'), findsOneWidget);
      expect(
        find.text('Une garde attentive avec des nouvelles régulières.'),
        findsOneWidget,
      );
      router.go('/pet-sitting/requests/${request.id}/review');
      await flush(tester);
      await tester.enterText(
        find.byType(TextField),
        'Un second avis non autorisé.',
      );
      await tapAction(tester, find.text('Publier mon avis'));
      await tapAction(tester, find.widgetWithText(FilledButton, 'Confirmer'));
      await flush(tester);
      expect(
        find.text('Un avis existe déjà pour cette garde.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final path in [
    '/veterinary/dashboard',
    '/veterinary/availability',
    '/pet-sitting/dashboard',
    '/pet-sitting/settings',
    '/admin/services',
  ]) {
    testWidgets('Citizen route protected $path', (tester) async {
      final (_, router) = await mountApp(
        tester,
        account: 'citizen',
        path: path,
      );
      await flush(tester);
      expect(router.routeInformationProvider.value.uri.path, '/access-denied');
      expect(
        find.text(
          'Votre profil ne permet pas d’ouvrir cet espace. Revenez à l’accueil pour accéder à vos fonctionnalités.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'New screens fit 360 px and private health route rejects foreign user',
    (tester) async {
      tester.view.physicalSize = const Size(360, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (session, router) = await mountApp(
        tester,
        account: 'citizen',
        path: '/veterinary',
      );
      await flush(tester);
      for (final path in [
        '/veterinary',
        '/pet-sitting',
        '/veterinary/my-appointments',
        '/pet-sitting/my-requests',
        '/health',
        '/animals/1/health',
      ]) {
        router.go(path);
        await flush(tester);
        expect(tester.takeException(), isNull);
      }
      expect(
        find.text('Vous n’êtes pas autorisé à consulter ce carnet de santé.'),
        findsOneWidget,
      );
      await tester.runAsync(
        () => session.login('veterinarian@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      for (final path in [
        '/veterinary/dashboard',
        '/veterinary/availability',
      ]) {
        router.go(path);
        await flush(tester);
        expect(tester.takeException(), isNull);
      }
      await tester.runAsync(
        () => session.login('pet-sitter@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      for (final path in ['/pet-sitting/dashboard', '/pet-sitting/settings']) {
        router.go(path);
        await flush(tester);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
