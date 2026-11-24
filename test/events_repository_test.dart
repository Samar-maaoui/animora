import 'dart:typed_data';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/users/models/user.dart';
import 'package:animora/core/enums/account_status.dart';
import 'package:animora/features/events/repositories/events_database.dart';
import 'package:animora/features/events/repositories/local_event_repository.dart';
import 'package:animora/features/events/services/event_rules.dart';

import 'support/reports_test_support.dart';

import 'package:animora/core/enums/event_type.dart';
import 'package:animora/core/enums/event_status.dart';
import 'package:animora/core/enums/registration_type.dart';
import 'package:animora/core/enums/registration_status.dart';
import 'package:animora/core/enums/volunteer_task_status.dart';
import 'package:animora/features/events/models/event.dart';
import 'package:animora/features/events/models/event_registration.dart';
import 'package:animora/features/events/models/event_activity.dart';
import 'package:animora/features/events/models/volunteer_task.dart';

final admin7 = DemoAccounts.users.firstWhere((u) => u.id == 'demo-admin');
final citizen7 = DemoAccounts.users.firstWhere((u) => u.id == 'demo-citizen');
final other7 = DemoAccounts.users.firstWhere((u) => u.id == 'demo-foster');

class EventHarness {
  EventHarness() {
    db = EventsDatabase(storage);
    repo = LocalEventRepository(
      db,
      () => actor,
      (id) async => users[id]?.status == AccountStatus.active,
      clock: () => now,
    );
  }
  DateTime now = DateTime(2026, 11, 10, 12);
  User? actor = admin7;
  final users = {for (final u in DemoAccounts.users) u.id: u};
  final storage = MemoryReportsStorage();
  late final EventsDatabase db;
  late final LocalEventRepository repo;
  Event draft({int capacity = 1}) => Event(
    id: 0,
    title: 'Journée adoption Animora',
    description:
        'Une rencontre de protection animale avec ateliers et bénévoles.',
    type: EventType.ADOPTION_DAY,
    location: 'Parc de la ville',
    city: 'Tunis',
    startDate: now.add(const Duration(days: 1)),
    endDate: now.add(const Duration(days: 1, hours: 3)),
    capacity: capacity,
    status: EventStatus.PUBLISHED,
    organizerUserId: 'faux',
  );
  Future<Event> event({int capacity = 1, bool publish = true}) async {
    actor = admin7;
    final e = await repo.saveEvent(draft(capacity: capacity), creating: true);
    if (publish) await repo.changeEventStatus(e.id, EventStatus.PUBLISHED);
    return await repo.getEvent(e.id);
  }

  Future<EventRegistration> join(
    Event e, {
    User? user,
    RegistrationType type = RegistrationType.PARTICIPANT,
    bool wait = false,
  }) {
    actor = user ?? citizen7;
    return repo.register(e.id, type, acceptWaitlist: wait);
  }

  VolunteerTask task(Event e, {String? assigned}) => VolunteerTask(
    id: 0,
    eventId: e.id,
    title: 'Accueil des visiteurs',
    description: 'Accompagner et orienter les visiteurs à l’entrée.',
    assignedUserId: assigned,
    status: VolunteerTaskStatus.COMPLETED,
  );
  EventActivity activity(Event e) => EventActivity(
    id: 0,
    eventId: e.id,
    title: 'Atelier animalier',
    description: 'Présentation des soins et des animaux à adopter.',
    startTime: e.startDate,
    endTime: e.startDate.add(const Duration(hours: 1)),
  );
  void dispose() => db.dispose();
}

void main() {
  late EventHarness h;
  late LocalEventRepository r;
  final failure = throwsA(isA<EventFailure>());
  setUp(() {
    h = EventHarness();
    r = h.repo;
  });
  tearDown(() => h.dispose());
  test(
    'Create forces draft and actual organizer, publish then public catalog',
    () async {
      final e = await h.event(publish: false);
      expect(e.status, EventStatus.DRAFT);
      expect(e.organizerUserId, admin7.id);
      h.actor = citizen7;
      expect(await r.getEvents(), isEmpty);
      await expectLater(r.getEvent(e.id), failure);
      await expectLater(
        r.changeEventStatus(e.id, EventStatus.PUBLISHED),
        failure,
      );
      h.actor = admin7;
      await r.changeEventStatus(e.id, EventStatus.PUBLISHED);
      h.actor = citizen7;
      expect((await r.getEvents()).single.id, e.id);
    },
  );
  test('Dates capacity coordinates and text validated', () async {
    final e = h.draft();
    for (final bad in [
      e.copyWith(endDate: e.startDate),
      e.copyWith(capacity: 0),
      e.copyWith(capacity: -1),
      e.copyWith(title: 'x'),
      e.copyWith(latitude: 90.1, longitude: 0),
      e.copyWith(latitude: 0),
      e.copyWith(latitude: double.nan, longitude: 0),
    ]) {
      await expectLater(r.saveEvent(bad, creating: true), failure);
    }
    expect(await r.getEvents(), isEmpty);
  });
  test('Only active ADMIN can create', () async {
    h.actor = citizen7;
    await expectLater(r.saveEvent(h.draft(), creating: true), failure);
    h.actor = admin7.copyWith(status: AccountStatus.blocked);
    await expectLater(r.getEvents(), failure);
    h.actor = null;
    await expectLater(r.getEvents(), failure);
  });
  test('Publish rejects past start and terminal transition', () async {
    final e = await h.event(publish: false);
    h.now = e.startDate;
    await expectLater(
      r.changeEventStatus(e.id, EventStatus.PUBLISHED),
      failure,
    );
    await r.changeEventStatus(e.id, EventStatus.CANCELLED);
    await expectLater(
      r.changeEventStatus(e.id, EventStatus.PUBLISHED),
      failure,
    );
  });
  test('Participant receives one unique valid ticket', () async {
    final e = await h.event();
    final reg = await h.join(e);
    expect(reg.status, RegistrationStatus.CONFIRMED);
    final t = await r.ticketForRegistration(reg.id);
    expect(t, isNotNull);
    expect(t!.used, isFalse);
    expect((await r.getTicket(t.id)).registrationId, reg.id);
    expect((await r.ticketForRegistration(reg.id))!.id, t.id);
    expect(await r.availablePlaces(e.id), 0);
  });
  test('Volunteer consumes same capacity and duplicate active registration rejected', () async {
    final e = await h.event();
    await h.join(e, type: RegistrationType.VOLUNTEER);
    await expectLater(r.register(e.id, RegistrationType.PARTICIPANT), failure);
    await expectLater(h.join(e, user: other7), failure);
    final wait = await h.join(e, user: other7, wait: true);
    expect(wait.status, RegistrationStatus.WAITLISTED);
    expect(await r.ticketForRegistration(wait.id), isNull);
  });
  test(
    'Concurrent requests never exceed capacity or duplicate registration',
    () async {
      final e = await h.event();
      h.actor = citizen7;
      final results = await Future.wait(
        List.generate(
          8,
          (_) => r
              .register(e.id, RegistrationType.PARTICIPANT)
              .then<Object>((x) => x, onError: (Object e) => e),
        ),
      );
      expect(results.whereType<EventRegistration>().length, 1);
      expect(await r.availablePlaces(e.id), 0);
    },
  );
  test('Cancel atomically invalidates ticket and promotes FIFO once', () async {
    final e = await h.event();
    final first = await h.join(e);
    final oldTicket = await r.ticketForRegistration(first.id);
    final wait = await h.join(e, user: other7, wait: true);
    h.actor = citizen7;
    await r.cancelRegistration(first.id);
    await expectLater(r.getTicket(oldTicket!.id), failure);
    h.actor = other7;
    expect(
      (await r.getRegistrations()).single.status,
      RegistrationStatus.CONFIRMED,
    );
    final t = await r.ticketForRegistration(wait.id);
    expect(t, isNotNull);
    h.actor = citizen7;
    await expectLater(r.cancelRegistration(first.id), failure);
    h.actor = admin7;
    expect(
      (await r.getRegistrations())
          .where((r) => r.status == RegistrationStatus.CONFIRMED)
          .length,
      1,
    );
  });
  test(
    'Waitlist skips blocked account and promotes earliest eligible',
    () async {
      final e = await h.event();
      final first = await h.join(e);
      await h.join(e, user: other7, wait: true);
      final third = await h.join(e, user: admin7, wait: true);
      h.users[other7.id] = other7.copyWith(status: AccountStatus.blocked);
      h.actor = citizen7;
      await r.cancelRegistration(first.id);
      h.actor = admin7;
      expect(
        (await r.getRegistrations()).firstWhere((r) => r.id == third.id).status,
        RegistrationStatus.CONFIRMED,
      );
    },
  );
  test('Capacity increase promotes waiting users and cannot decrease below occupied', () async {
    final e = await h.event();
    await h.join(e);
    final wait = await h.join(e, user: other7, wait: true);
    h.actor = admin7;
    await r.saveEvent(e.copyWith(capacity: 2), creating: false);
    expect(
      (await r.getRegistrations()).firstWhere((r) => r.id == wait.id).status,
      RegistrationStatus.CONFIRMED,
    );
    await expectLater(
      r.saveEvent(e.copyWith(capacity: 1), creating: false),
      failure,
    );
  });
  test('Dates frozen after registration and cancellation permits new distinct registration', () async {
    final e = await h.event();
    final first = await h.join(e);
    h.actor = admin7;
    await expectLater(
      r.saveEvent(
        e.copyWith(startDate: e.startDate.add(const Duration(minutes: 5))),
        creating: false,
      ),
      failure,
    );
    h.actor = citizen7;
    await r.cancelRegistration(first.id);
    final again = await r.register(e.id, RegistrationType.VOLUNTEER);
    expect(again.id, isNot(first.id));
  });
  test('No registration cancellation or promotion after start', () async {
    final e = await h.event();
    final reg = await h.join(e);
    h.now = e.startDate;
    await expectLater(r.cancelRegistration(reg.id), failure);
    await expectLater(h.join(e, user: other7, wait: true), failure);
  });
  test(
    'Event cancellation invalidates active registrations without promoting',
    () async {
      final e = await h.event();
      final reg = await h.join(e);
      final t = await r.ticketForRegistration(reg.id);
      await h.join(e, user: other7, wait: true);
      h.actor = admin7;
      await r.changeEventStatus(e.id, EventStatus.CANCELLED);
      expect(
        (await r.getRegistrations()).every(
          (r) => r.status == RegistrationStatus.CANCELLED,
        ),
        isTrue,
      );
      await expectLater(r.getTicket(t!.id), failure);
      await expectLater(h.join(e), failure);
    },
  );
  test('Ticket and registrations private including direct IDs', () async {
    final e = await h.event();
    final reg = await h.join(e);
    final t = await r.ticketForRegistration(reg.id);
    h.actor = other7;
    expect(await r.getRegistrations(eventId: e.id), isEmpty);
    await expectLater(r.getTicket(t!.id), failure);
    await expectLater(r.cancelRegistration(reg.id), failure);
    await expectLater(r.ticketForRegistration(reg.id), failure);
  });
  test('Check-in verifies ADMIN event timing and code', () async {
    final e = await h.event();
    final reg = await h.join(e);
    final t = (await r.ticketForRegistration(reg.id))!;
    await expectLater(r.checkIn(e.id, t.code), failure);
    h.actor = admin7;
    await expectLater(r.checkIn(e.id, t.code), failure);
    final second = await h.event();
    h.now = e.startDate;
    await expectLater(r.checkIn(second.id, t.code), failure);
    await expectLater(r.checkIn(e.id, 'UNKNOWN'), failure);
    expect((await r.checkIn(e.id, t.code)).status, RegistrationStatus.ATTENDED);
    expect(await r.ticketForRegistration(reg.id), isNull);
    await expectLater(r.getTicket(t.id), failure);
  });
  test('Concurrent double check-in only succeeds once', () async {
    final e = await h.event();
    final reg = await h.join(e);
    final t = (await r.ticketForRegistration(reg.id))!;
    h.actor = admin7;
    h.now = e.startDate;
    final results = await Future.wait(
      List.generate(
        2,
        (_) => r
            .checkIn(e.id, t.code)
            .then<Object>((x) => x, onError: (Object e) => e),
      ),
    );
    expect(results.whereType<EventRegistration>().length, 1);
    expect(results.whereType<EventFailure>().length, 1);
  });
  test('Blocked participant cannot be checked in', () async {
    final e = await h.event();
    final reg = await h.join(e);
    final t = (await r.ticketForRegistration(reg.id))!;
    h.users[citizen7.id] = citizen7.copyWith(status: AccountStatus.blocked);
    h.actor = admin7;
    h.now = e.startDate;
    await expectLater(r.checkIn(e.id, t.code), failure);
  });
  test('Activities within event including bounds and edit delete', () async {
    final e = await h.event();
    final a = h.activity(e);
    await r.saveActivity(a, creating: true);
    var stored = (await r.getActivities(e.id)).single;
    await expectLater(
      r.saveActivity(
        a.copyWith(startTime: e.startDate.subtract(const Duration(seconds: 1))),
        creating: true,
      ),
      failure,
    );
    await expectLater(
      r.saveActivity(
        a.copyWith(endTime: e.endDate.add(const Duration(seconds: 1))),
        creating: true,
      ),
      failure,
    );
    await expectLater(
      r.saveActivity(a.copyWith(endTime: a.startTime), creating: true),
      failure,
    );
    await r.saveActivity(
      stored.copyWith(title: 'Atelier de protection'),
      creating: false,
    );
    expect((await r.getActivities(e.id)).single.title, 'Atelier de protection');
    await r.deleteActivity(stored.id);
    expect(await r.getActivities(e.id), isEmpty);
  });
  test('Event edits cannot strand existing activities', () async {
    final e = await h.event(publish: false);
    await r.saveActivity(h.activity(e), creating: true);
    await expectLater(
      r.saveEvent(
        e.copyWith(startDate: e.startDate.add(const Duration(minutes: 30))),
        creating: false,
      ),
      failure,
    );
  });
  test(
    'Task assignment requires confirmed volunteer and active account',
    () async {
      final e = await h.event(capacity: 2);
      await h.join(e);
      await h.join(e, user: other7, type: RegistrationType.VOLUNTEER);
      h.actor = admin7;
      await expectLater(
        r.saveTask(h.task(e, assigned: citizen7.id), creating: true),
        failure,
      );
      await r.saveTask(h.task(e, assigned: other7.id), creating: true);
      final task = (await r.getTasks()).single;
      expect(task.status, VolunteerTaskStatus.ASSIGNED);
      expect((await r.eligibleVolunteers(e.id)).single.userId, other7.id);
      h.users[other7.id] = other7.copyWith(status: AccountStatus.blocked);
      await expectLater(
        r.saveTask(h.task(e, assigned: other7.id), creating: true),
        failure,
      );
    },
  );
  test('Waitlisted volunteer is not assignable', () async {
    final e = await h.event();
    await h.join(e);
    await h.join(e, user: other7, type: RegistrationType.VOLUNTEER, wait: true);
    h.actor = admin7;
    await expectLater(
      r.saveTask(h.task(e, assigned: other7.id), creating: true),
      failure,
    );
  });
  test(
    'Only assigned volunteer advances task through valid statuses',
    () async {
      final e = await h.event();
      await h.join(e, type: RegistrationType.VOLUNTEER);
      h.actor = admin7;
      await r.saveTask(h.task(e, assigned: citizen7.id), creating: true);
      final t = (await r.getTasks()).single;
      await expectLater(
        r.advanceTask(t.id, VolunteerTaskStatus.IN_PROGRESS),
        failure,
      );
      h.actor = citizen7;
      await expectLater(
        r.advanceTask(t.id, VolunteerTaskStatus.COMPLETED),
        failure,
      );
      await r.advanceTask(t.id, VolunteerTaskStatus.IN_PROGRESS);
      await r.advanceTask(t.id, VolunteerTaskStatus.COMPLETED);
      await expectLater(
        r.advanceTask(t.id, VolunteerTaskStatus.IN_PROGRESS),
        failure,
      );
      h.actor = other7;
      expect(await r.getTasks(), isEmpty);
      await expectLater(
        r.advanceTask(t.id, VolunteerTaskStatus.COMPLETED),
        failure,
      );
    },
  );
  test('Cancellation unassigns unfinished task', () async {
    final e = await h.event();
    final reg = await h.join(e, type: RegistrationType.VOLUNTEER);
    h.actor = admin7;
    await r.saveTask(h.task(e, assigned: citizen7.id), creating: true);
    h.actor = citizen7;
    await r.cancelRegistration(reg.id);
    h.actor = admin7;
    final t = (await r.getTasks()).single;
    expect(t.assignedUserId, isNull);
    expect(t.status, VolunteerTaskStatus.AVAILABLE);
  });
  test(
    'Completing only after end preserves attended history and freezes report',
    () async {
      final e = await h.event(capacity: 3);
      final a = await h.join(e);
      final ta = (await r.ticketForRegistration(a.id))!;
      final b = await h.join(e, user: other7, type: RegistrationType.VOLUNTEER);
      final tb = (await r.ticketForRegistration(b.id))!;
      h.actor = admin7;
      await expectLater(
        r.changeEventStatus(e.id, EventStatus.COMPLETED),
        failure,
      );
      await expectLater(
        r.saveReport(
          e.id,
          'Bilan descriptif vérifié et sans chiffres fictifs.',
        ),
        failure,
      );
      h.now = e.startDate;
      await r.checkIn(e.id, ta.code);
      await r.checkIn(e.id, tb.code);
      h.now = e.endDate;
      await r.changeEventStatus(e.id, EventStatus.COMPLETED);
      await r.saveReport(
        e.id,
        'Bilan descriptif vérifié et sans chiffres fictifs.',
      );
      h.actor = citizen7;
      expect(await r.getReport(e.id), isNull);
      h.actor = admin7;
      await r.saveReport(
        e.id,
        'Bilan public des actions réalisées pendant cette journée.',
        publish: true,
      );
      final report = (await r.getReport(e.id))!;
      expect(report.participantCount, 1);
      expect(report.volunteerCount, 1);
      expect(report.published, isTrue);
      await expectLater(
        r.saveReport(e.id, 'Réécriture des résultats du bilan publié.'),
        failure,
      );
      await expectLater(r.checkIn(e.id, ta.code), failure);
      h.actor = citizen7;
      expect((await r.getReport(e.id))!.participantCount, 1);
    },
  );
  test('Unpointed registrations never count as attendance', () async {
    final e = await h.event();
    await h.join(e);
    h.actor = admin7;
    h.now = e.endDate;
    await r.changeEventStatus(e.id, EventStatus.COMPLETED);
    await r.saveReport(
      e.id,
      'Aucun participant ne s’est présenté au pointage.',
      publish: true,
    );
    expect((await r.getReport(e.id))!.participantCount, 0);
  });
  test(
    'Failed cancellation rolls back seat ticket and promotion then retry works',
    () async {
      final e = await h.event();
      final first = await h.join(e);
      final wait = await h.join(e, user: other7, wait: true);
      h.actor = citizen7;
      h.storage.fail = true;
      await expectLater(r.cancelRegistration(first.id), throwsStateError);
      h.storage.fail = false;
      expect(
        (await r.getRegistrations()).single.status,
        RegistrationStatus.CONFIRMED,
      );
      expect(await r.ticketForRegistration(first.id), isNotNull);
      h.actor = other7;
      expect(await r.ticketForRegistration(wait.id), isNull);
      h.actor = citizen7;
      await r.cancelRegistration(first.id);
      h.actor = other7;
      expect(await r.ticketForRegistration(wait.id), isNotNull);
    },
  );
  test('Reload keeps events registrations and unique tickets', () async {
    final e = await h.event();
    final reg = await h.join(e);
    final t = (await r.ticketForRegistration(reg.id))!;
    final db = EventsDatabase(h.storage);
    addTearDown(db.dispose);
    final reloaded = LocalEventRepository(
      db,
      () => h.actor,
      (id) async => true,
      clock: () => h.now,
    );
    expect((await reloaded.getTicket(t.id)).code, t.code);
    await expectLater(
      reloaded.register(e.id, RegistrationType.PARTICIPANT),
      failure,
    );
  });
  test(
    'Event edits retain status and organizer while updating public fields',
    () async {
      final e = await h.event();
      await r.saveEvent(
        e.copyWith(
          title: 'Journée de protection animale',
          city: 'Sousse',
          organizerUserId: 'faux',
          status: EventStatus.COMPLETED,
        ),
        creating: false,
      );
      final updated = await r.getEvent(e.id);
      expect(updated.title, 'Journée de protection animale');
      expect(updated.city, 'Sousse');
      expect(updated.organizerUserId, admin7.id);
      expect(updated.status, EventStatus.PUBLISHED);
    },
  );
  test('Task description edits preserve progress and assignment cannot move after start', () async {
    final e = await h.event(capacity: 2);
    await h.join(e, type: RegistrationType.VOLUNTEER);
    await h.join(e, user: other7, type: RegistrationType.VOLUNTEER);
    h.actor = admin7;
    await r.saveTask(h.task(e, assigned: citizen7.id), creating: true);
    final t = (await r.getTasks()).single;
    h.actor = citizen7;
    await r.advanceTask(t.id, VolunteerTaskStatus.IN_PROGRESS);
    h.actor = admin7;
    await r.saveTask(
      t.copyWith(
        description:
            'Nouvelle consigne détaillée pour accompagner les visiteurs.',
      ),
      creating: false,
    );
    expect((await r.getTasks()).single.status, VolunteerTaskStatus.IN_PROGRESS);
    await expectLater(
      r.saveTask(t.copyWith(assignedUserId: other7.id), creating: false),
      failure,
    );
  });
  test('Report photos persist and remain private until publication', () async {
    final e = await h.event();
    h.now = e.endDate;
    await r.changeEventStatus(e.id, EventStatus.COMPLETED);
    await r.saveReport(
      e.id,
      'Une journée terminée avec des ateliers de protection.',
      photos: [
        Uint8List.fromList([1, 2, 3]),
      ],
    );
    final report = (await r.getReport(e.id))!;
    expect(await r.reportPhoto(e.id, report.photos.single), [1, 2, 3]);
    h.actor = citizen7;
    await expectLater(r.reportPhoto(e.id, report.photos.single), failure);
    h.actor = admin7;
    await r.saveReport(e.id, report.description, publish: true);
    h.actor = citizen7;
    expect(await r.reportPhoto(e.id, report.photos.single), [1, 2, 3]);
  });
  test('Image limits and deferred image access recheck identity', () async {
    final draft = h.draft();
    await expectLater(
      r.saveEvent(
        draft,
        creating: true,
        imageBytes: Uint8List(2 * 1024 * 1024 + 1),
      ),
      failure,
    );
    final e = await r.saveEvent(
      draft,
      creating: true,
      imageBytes: Uint8List.fromList([1]),
    );
    h.storage.photoGate = Completer<void>();
    final photo = r.eventPhoto(e.id);
    await Future<void>.delayed(Duration.zero);
    h.actor = citizen7;
    h.storage.photoGate!.complete();
    await expectLater(photo, failure);
  });
  test('Failed check-in does not consume ticket and can retry', () async {
    final e = await h.event();
    final reg = await h.join(e);
    final ticket = (await r.ticketForRegistration(reg.id))!;
    h.actor = admin7;
    h.now = e.startDate;
    h.storage.fail = true;
    await expectLater(r.checkIn(e.id, ticket.code), throwsStateError);
    h.storage.fail = false;
    expect((await r.getTicket(ticket.id)).used, isFalse);
    expect(
      (await r.checkIn(e.id, ticket.code)).status,
      RegistrationStatus.ATTENDED,
    );
  });
  test('Corrupt persistence is preserved and not reset', () async {
    h.storage.value = 'invalid';
    await expectLater(r.getEvents(), throwsFormatException);
    expect(h.storage.value, 'invalid');
  });
  test('Queued mutation rejects a switched session', () async {
    final e = await h.event();
    h.actor = citizen7;
    final gate = Completer<void>();
    final pending = h.db.read((_) => gate.future);
    final attempt = r.register(e.id, RegistrationType.PARTICIPANT);
    h.actor = other7;
    gate.complete();
    await pending;
    await expectLater(attempt, failure);
    expect(await r.availablePlaces(e.id), 1);
  });
}
