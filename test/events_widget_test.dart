import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/events/widgets/event_widgets.dart';
import 'package:animora/features/events/models/event.dart';
import 'package:animora/features/events/models/volunteer_task.dart';

import 'support/auth_test_support.dart';
import 'widget_test.dart' show mountApp;
import 'services_widget_test.dart' show flush, tapAction;

EventsStore eventStore(WidgetTester t) =>
    t.element(find.byType(EventsPage).first).read<EventsStore>();
Future<Event> seedEvent7(
  WidgetTester t,
  EventsStore s, {
  int capacity = 1,
}) async {
  final now = s.now;
  final e = (await t.runAsync(
    () => s.events.saveEvent(
      Event(
        id: 0,
        title: 'Journée fictive Animora',
        description:
            'Une journée de protection animale avec atelier et bénévoles.',
        type: EventType.ADOPTION_DAY,
        location: 'Parc des animaux',
        city: 'Tunis',
        startDate: now.add(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 1, hours: 3)),
        capacity: capacity,
        status: EventStatus.DRAFT,
        organizerUserId: 'faux',
      ),
      creating: true,
    ),
  ))!;
  await t.runAsync(
    () => s.events.changeEventStatus(e.id, EventStatus.PUBLISHED),
  );
  await flush(t);
  return (await t.runAsync(() => s.events.getEvent(e.id)))!;
}

Future<void> confirm7(WidgetTester t) =>
    tapAction(t, find.widgetWithText(FilledButton, 'Confirmer'));
void main() {
  setUpAll(seedDatabase);
  testWidgets('ADMIN creates publishes and citizen searches catalogue', (
    t,
  ) async {
    final (session, router) = await mountApp(
      t,
      account: 'admin',
      path: '/admin/events/new',
    );
    await flush(t);
    await t.enterText(find.byType(TextField).at(0), 'Rencontre locale Animora');
    await t.enterText(
      find.byType(TextField).at(1),
      'Rencontre de protection animale avec des bénévoles et des ateliers.',
    );
    await t.enterText(find.byType(TextField).at(2), 'Parc central');
    await t.enterText(find.byType(TextField).at(3), 'Tunis');
    await tapAction(t, find.text('Enregistrer l’événement'));
    expect(find.text('Brouillon'), findsOneWidget);
    await tapAction(t, find.text('Publier l’événement'));
    await confirm7(t);
    expect(find.text('Publié'), findsOneWidget);
    await t.runAsync(
      () => session.login('citizen@animora.test', DemoAccounts.password),
    );
    router.go('/events');
    await flush(t);
    expect(find.text('Rencontre locale Animora'), findsOneWidget);
    await t.enterText(find.byType(TextField).at(0), 'absent');
    await flush(t);
    expect(find.text('Rencontre locale Animora'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('Invalid event stays editable and creates nothing', (t) async {
    await mountApp(t, account: 'admin', path: '/admin/events/new');
    await flush(t);
    final s = eventStore(t);
    await tapAction(t, find.text('Enregistrer l’événement'));
    expect(find.textContaining('Saisissez entre'), findsOneWidget);
    expect((await t.runAsync(() => s.events.getEvents()))!, isEmpty);
    expect(find.text('Enregistrer l’événement'), findsOneWidget);
  });
  testWidgets('Participant registers sees private QR ticket and cancels', (
    t,
  ) async {
    final (session, router) = await mountApp(
      t,
      account: 'admin',
      path: '/admin/events',
    );
    final s = eventStore(t);
    final e = await seedEvent7(t, s);
    await t.runAsync(
      () => session.login('citizen@animora.test', DemoAccounts.password),
    );
    router.go('/events/${e.id}/register');
    await flush(t);
    await tapAction(t, find.text('Confirmer mon inscription'));
    await confirm7(t);
    expect(find.text('Confirmée'), findsOneWidget);
    await tapAction(t, find.text('Voir mon billet'));
    expect(find.byType(EventQr), findsOneWidget);
    expect(find.text('Valide • non utilisé'), findsOneWidget);
    router.go('/events/my');
    await flush(t);
    await tapAction(t, find.text('Annuler mon inscription'));
    await confirm7(t);
    expect(find.text('Annulée'), findsOneWidget);
    expect(find.text('Voir mon billet'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('Waitlist requires explicit choice then promotion shown in app', (
    t,
  ) async {
    final (session, router) = await mountApp(
      t,
      account: 'admin',
      path: '/admin/events',
    );
    final s = eventStore(t);
    final e = await seedEvent7(t, s);
    await t.runAsync(
      () => session.login('citizen@animora.test', DemoAccounts.password),
    );
    final first = (await t.runAsync(
      () => s.registrations.register(e.id, RegistrationType.PARTICIPANT),
    ))!;
    await t.runAsync(
      () => session.login('foster@animora.test', DemoAccounts.password),
    );
    router.go('/events/${e.id}/register');
    await flush(t);
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirmer mon inscription'),
          )
          .onPressed,
      isNull,
    );
    await tapAction(t, find.text('Rejoindre la liste d’attente'));
    await tapAction(t, find.text('Confirmer mon inscription'));
    await confirm7(t);
    expect(find.text('Liste d’attente'), findsOneWidget);
    await t.runAsync(
      () => session.login('citizen@animora.test', DemoAccounts.password),
    );
    await t.runAsync(() => s.registrations.cancelRegistration(first.id));
    await t.runAsync(
      () => session.login('foster@animora.test', DemoAccounts.password),
    );
    router.go('/events/my');
    await flush(t);
    expect(find.text('Confirmée'), findsOneWidget);
    expect(find.text('Voir mon billet'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Volunteer progresses assigned task and other account cannot see it',
    (t) async {
      final (session, router) = await mountApp(
        t,
        account: 'admin',
        path: '/admin/events',
      );
      final s = eventStore(t);
      final e = await seedEvent7(t, s);
      await t.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      await t.runAsync(
        () => s.registrations.register(e.id, RegistrationType.VOLUNTEER),
      );
      await t.runAsync(
        () => session.login('admin@animora.test', DemoAccounts.password),
      );
      await t.runAsync(
        () => s.tasks.saveTask(
          VolunteerTask(
            id: 0,
            eventId: e.id,
            title: 'Accueil des visiteurs',
            description:
                'Orienter les visiteurs vers les ateliers de protection.',
            assignedUserId: 'demo-citizen',
            status: VolunteerTaskStatus.AVAILABLE,
          ),
          creating: true,
        ),
      );
      await t.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      router.go('/events/volunteer');
      await flush(t);
      await tapAction(t, find.text('Commencer la tâche'));
      expect(find.text('En cours'), findsOneWidget);
      await tapAction(t, find.text('Terminer la tâche'));
      await confirm7(t);
      expect(find.text('Terminée'), findsOneWidget);
      await t.runAsync(
        () => session.login('foster@animora.test', DemoAccounts.password),
      );
      await flush(t);
      expect(find.text('Accueil des visiteurs'), findsNothing);
      expect(
        find.textContaining('réservé aux utilisateurs inscrits'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('ADMIN activities and tasks forms save and render', (t) async {
    final (_, router) = await mountApp(
      t,
      account: 'admin',
      path: '/admin/events',
    );
    final s = eventStore(t);
    final e = await seedEvent7(t, s);
    router.go('/admin/events/${e.id}/activities');
    await flush(t);
    await tapAction(t, find.text('Ajouter une activité'));
    await t.enterText(
      find.byType(TextField).at(0),
      'Atelier de sensibilisation',
    );
    await t.enterText(
      find.byType(TextField).at(1),
      'Présentation des gestes de protection animale.',
    );
    await tapAction(t, find.text('Enregistrer l’activité'));
    expect(find.text('Atelier de sensibilisation'), findsOneWidget);
    await tapAction(t, find.text('Supprimer l’activité'));
    await confirm7(t);
    expect(find.text('Atelier de sensibilisation'), findsNothing);
    router.go('/admin/events/${e.id}/volunteers');
    await flush(t);
    await tapAction(t, find.text('Créer une tâche'));
    await t.enterText(find.byType(TextField).at(0), 'Préparer les stands');
    await t.enterText(
      find.byType(TextField).at(1),
      'Organiser les stands avant l’accueil des visiteurs.',
    );
    await tapAction(t, find.text('Enregistrer la tâche'));
    expect(find.text('Préparer les stands'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'ADMIN checks ticket once then publishes actual attendance report',
    (t) async {
      var now = DateTime(2026, 11, 10, 12);
      final (session, router) = await mountApp(
        t,
        account: 'admin',
        path: '/admin/events',
        eventsClock: () => now,
      );
      final s = eventStore(t);
      final e = await seedEvent7(t, s);
      await t.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      final reg = (await t.runAsync(
        () => s.registrations.register(e.id, RegistrationType.PARTICIPANT),
      ))!;
      final ticket = (await t.runAsync(
        () => s.tickets.ticketForRegistration(reg.id),
      ))!;
      await t.runAsync(
        () => session.login('admin@animora.test', DemoAccounts.password),
      );
      now = e.startDate;
      router.go('/admin/events/${e.id}/registrations');
      await flush(t);
      await t.enterText(find.byType(TextField), ticket.code);
      await tapAction(t, find.text('Valider la présence'));
      await confirm7(t);
      expect(find.text('Présent'), findsOneWidget);
      now = e.endDate;
      await t.runAsync(
        () => s.events.changeEventStatus(e.id, EventStatus.COMPLETED),
      );
      router.go('/admin/events/${e.id}/report');
      await flush(t);
      expect(find.text('Participants présents : 1'), findsOneWidget);
      await t.enterText(
        find.byType(TextField),
        'Journée terminée avec atelier et accueil des participants présents.',
      );
      await tapAction(t, find.text('Publier le bilan'));
      await confirm7(t);
      expect(find.text('Bilan publié et figé'), findsOneWidget);
      await t.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      router.go('/events/${e.id}/report');
      await flush(t);
      expect(find.text('Participants présents : 1'), findsOneWidget);
      expect(find.text('Bénévoles présents : 0'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Changing event ID reloads the correct details and edit form', (
    t,
  ) async {
    final (_, router) = await mountApp(
      t,
      account: 'admin',
      path: '/admin/events',
    );
    final s = eventStore(t);
    final first = await seedEvent7(t, s);
    final second = await seedEvent7(t, s);
    await t.runAsync(
      () => s.events.saveEvent(
        second.copyWith(title: 'Deuxième rencontre de protection'),
        creating: false,
      ),
    );
    router.go('/events/${first.id}');
    await flush(t);
    expect(find.text(first.title), findsOneWidget);
    router.go('/events/${second.id}');
    await flush(t);
    expect(find.text('Deuxième rencontre de protection'), findsOneWidget);
    expect(find.text(first.title), findsNothing);
    router.go('/admin/events/${first.id}/edit');
    await flush(t);
    expect(
      t.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      first.title,
    );
    router.go('/admin/events/${second.id}/edit');
    await flush(t);
    expect(
      t.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      'Deuxième rencontre de protection',
    );
    expect(t.takeException(), isNull);
  });
  for (final route in [
    '/admin/events',
    '/admin/events/new',
    '/admin/events/1/edit',
    '/admin/events/1/registrations',
    '/admin/events/1/activities',
    '/admin/events/1/volunteers',
    '/admin/events/1/report',
  ]) {
    testWidgets('ADMIN guard $route', (t) async {
      final (_, router) = await mountApp(t, account: 'citizen', path: route);
      expect(router.routeInformationProvider.value.uri.path, '/access-denied');
      expect(find.text('Accès refusé'), findsNWidgets(2));
    });
  }
  testWidgets('Event catalogue form details and ticket fit 360 px', (t) async {
    t.view.physicalSize = const Size(360, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final (session, router) = await mountApp(
      t,
      account: 'admin',
      path: '/admin/events',
    );
    final s = eventStore(t);
    final e = await seedEvent7(t, s);
    for (final route in [
      '/events',
      '/events/${e.id}',
      '/admin/events/${e.id}/edit',
      '/admin/events/${e.id}/registrations',
      '/admin/events/${e.id}/report',
    ]) {
      router.go(route);
      await flush(t);
      expect(t.takeException(), isNull, reason: route);
    }
    await t.runAsync(
      () => session.login('citizen@animora.test', DemoAccounts.password),
    );
    final reg = (await t.runAsync(
      () => s.registrations.register(e.id, RegistrationType.VOLUNTEER),
    ))!;
    final ticket = (await t.runAsync(
      () => s.tickets.ticketForRegistration(reg.id),
    ))!;
    router.go('/events/tickets/${ticket.id}');
    await flush(t);
    expect(find.byType(EventQr), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
