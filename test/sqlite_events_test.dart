import 'package:animora/features/events/services/event_rules.dart';

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:animora/features/reports/database/sqlite_reports_database.dart';
import 'package:animora/features/animal_services/database/sqlite_animal_services_database.dart';
import 'package:animora/features/donations/database/sqlite_donations_database.dart';
import 'package:animora/features/events/database/sqlite_events_database.dart';
import 'package:animora/features/events/repositories/local_event_repository.dart';
import 'package:animora/core/enums/event_status.dart';
import 'package:animora/core/enums/registration_type.dart';
import 'package:animora/core/enums/registration_status.dart';

import 'events_repository_test.dart' show EventHarness;
import 'support/sql_module_test_support.dart';
import 'support/reports_test_support.dart';

void main() {
  late ModuleHarness h;
  late SqliteEventsDatabase db;
  late MemoryReportsStorage legacy;
  late LocalEventRepository r;
  var now = DateTime(2026, 11, 10, 12);
  setUp(() async {
    h = await ModuleHarness.create();
    SqliteReportsDatabase(h.context, MemoryReportsStorage());
    SqliteServicesDatabase(h.context, MemoryReportsStorage());
    SqliteDonationsDatabase(h.context, MemoryReportsStorage());
    legacy = MemoryReportsStorage();
    db = SqliteEventsDatabase(h.context, legacy);
    r = LocalEventRepository(
      db,
      () => h.actor,
      (id) async => h.users.containsKey(id),
      clock: () => now,
    );
    now = DateTime(2026, 11, 10, 12);
  });
  tearDown(() async {
    await h.close();
    db.dispose();
  });
  test(
    'SQLite capacity waitlist promotion ticket checkin report and uniqueness',
    () async {
      h.actor = h.admin;
      final fixture = EventHarness();
      final e = await r.saveEvent(fixture.draft(), creating: true);
      fixture.dispose();
      await r.changeEventStatus(e.id, EventStatus.PUBLISHED);
      h.actor = h.citizen;
      final first = await r.register(e.id, RegistrationType.PARTICIPANT);
      h.actor = h.other;
      final waiting = await r.register(
        e.id,
        RegistrationType.VOLUNTEER,
        acceptWaitlist: true,
      );
      expect(waiting.status, RegistrationStatus.WAITLISTED);
      final sql = await h.helper.database;
      final row = (await sql.query(
        'event_registrations',
        where: 'id=?',
        whereArgs: [first.id],
      )).single;
      await expectLater(
        sql.insert('event_registrations', {
          ...row,
          'id': 999,
          'userId': 'demo-veterinarian',
        }),
        throwsA(isA<DatabaseException>()),
      );
      h.actor = h.citizen;
      await r.cancelRegistration(first.id);
      h.actor = h.other;
      final ticket = (await r.ticketForRegistration(waiting.id))!;
      expect(
        (await r.getRegistrations()).single.status,
        RegistrationStatus.CONFIRMED,
      );
      h.actor = h.admin;
      now = DateTime(2026, 11, 11, 12);
      await r.checkIn(e.id, ticket.code);
      await expectLater(
        r.checkIn(e.id, ticket.code),
        throwsA(isA<EventFailure>()),
      );
      expect(
        (await sql.query(
          'event_tickets',
          where: 'registrationId=?',
          whereArgs: [waiting.id],
        )).single['used'],
        1,
      );
      now = DateTime(2026, 11, 11, 16);
      await r.changeEventStatus(e.id, EventStatus.COMPLETED);
      await r.saveReport(
        e.id,
        'Une journée réussie de rencontres et de sensibilisation.',
        publish: true,
        photos: [
          Uint8List.fromList([1, 2, 3]),
        ],
      );
      expect((await r.getReport(e.id))!.volunteerCount, 1);
      expect((await sql.query('event_reports')).length, 1);
    },
  );
  test('Old event store tickets statuses photos and source survive idempotent import', () async {
    final old = EventHarness();
    final e = await old.event();
    final registration = await old.join(e);
    final ticket = (await old.repo.ticketForRegistration(registration.id))!;
    old.actor = old.users['demo-admin'];
    await old.repo.saveEvent(
      e,
      creating: false,
      imageBytes: Uint8List.fromList([6, 5, 4]),
    );
    legacy.value = old.storage.value;
    legacy.photos.addAll(old.storage.photos);
    final source = legacy.value;
    h.actor = h.admin;
    expect((await r.getEvents()).single.id, e.id);
    expect((await r.ticketForRegistration(registration.id))!.code, ticket.code);
    expect(await r.eventPhoto(e.id), [6, 5, 4]);
    await h.context.ensure('events');
    expect(
      (await (await h.helper.database).query('event_registrations')).length,
      1,
    );
    expect(legacy.value, source);
    old.dispose();
  });
}
