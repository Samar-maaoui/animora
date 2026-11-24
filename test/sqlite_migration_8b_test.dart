import 'sqlite_catalog_test.dart' show legacyFixture8;

import 'package:animora/core/enums/donation_frequency.dart';
import 'package:animora/core/enums/material_type.dart';
import 'package:animora/core/enums/event_status.dart';
import 'package:animora/core/enums/registration_type.dart';
import 'package:animora/core/enums/announcement_type.dart';
import 'package:animora/features/reports/repositories/reports_database.dart';
import 'package:animora/features/reports/repositories/local_reports_repository.dart';

import 'donations_repository_test.dart' show DonationHarness;
import 'events_repository_test.dart' show EventHarness;
import 'reports_repository_test.dart'
    show reportDraft, announcementDraft, evidence;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart' as sembast;
import 'package:animora/features/reports/database/sqlite_reports_database.dart';
import 'package:animora/features/animal_services/database/sqlite_animal_services_database.dart';
import 'package:animora/features/donations/database/sqlite_donations_database.dart';
import 'package:animora/features/events/database/sqlite_events_database.dart';
import 'package:animora/features/reports/repositories/reports_storage.dart';
import 'package:animora/core/database/database_helper.dart';
import 'package:animora/core/database/database_constants.dart';
import 'package:animora/core/database/database_migrations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/reports_test_support.dart';
import 'support/sql_module_test_support.dart';

Map<String, dynamic> servicesFixture8() => jsonDecode(r'''{
  "version": 1,
  "nextId": 10,
  "availability": [
    {
      "id": 1,
      "veterinarianUserId": "demo-veterinarian",
      "date": "2026-11-10T00:00:00.000",
      "startTime": 540,
      "endTime": 600,
      "isFree": false
    }
  ],
  "appointments": [
    {
      "id": 2,
      "veterinarianUserId": "demo-veterinarian",
      "clientUserId": "demo-citizen",
      "animalId": 1,
      "availabilityId": 1,
      "appointmentDate": "2026-11-10T09:00:00.000",
      "reason": "Contrôle de santé",
      "status": "COMPLETED",
      "notes": "Bonne santé",
      "clientName": "Amine",
      "veterinarianName": "Sarra",
      "animalName": "Luna"
    }
  ],
  "vaccinations": [
    {
      "id": 3,
      "animalId": 1,
      "veterinarianUserId": "demo-veterinarian",
      "vaccineName": "Rage",
      "vaccinationDate": "2026-11-10T09:00:00.000",
      "nextDoseDate": "2027-11-10T09:00:00.000",
      "notes": "Rappel annuel",
      "veterinarianName": "Sarra"
    }
  ],
  "care": [
    {
      "id": 4,
      "animalId": 1,
      "veterinarianUserId": "demo-veterinarian",
      "type": "Consultation",
      "date": "2026-11-10T09:00:00.000",
      "description": "Examen de contrôle",
      "cost": 42.1234,
      "veterinarianName": "Sarra"
    }
  ],
  "reminders": [
    {
      "id": 5,
      "animalId": 1,
      "type": "Vaccination",
      "scheduledDate": "2027-11-10T09:00:00.000",
      "isSent": false,
      "vaccinationId": 3,
      "authorUserId": "demo-veterinarian"
    }
  ],
  "settings": [
    {
      "userId": "demo-pet-sitter",
      "available": true,
      "dailyRate": 25.5,
      "availableFrom": "2026-11-01T00:00:00.000",
      "availableUntil": "2026-12-01T00:00:00.000"
    }
  ],
  "requests": [
    {
      "id": 6,
      "ownerUserId": "demo-citizen",
      "petSitterUserId": "demo-pet-sitter",
      "animalId": 1,
      "startDate": "2026-11-11T00:00:00.000",
      "endDate": "2026-11-12T00:00:00.000",
      "status": "COMPLETED",
      "totalPrice": 25.5,
      "createdAt": "2026-11-01T00:00:00.000",
      "instructions": "Repas habituel",
      "ownerName": "Amine",
      "petSitterName": "Sami",
      "animalName": "Luna"
    }
  ],
  "updates": [
    {
      "id": 7,
      "petSittingRequestId": 6,
      "message": "Promenade terminée",
      "photo": "PHOTO",
      "createdAt": "2026-11-11T10:00:00.000"
    }
  ],
  "reviews": [
    {
      "id": 8,
      "petSittingRequestId": 6,
      "reviewerUserId": "demo-citizen",
      "rating": 5,
      "comment": "Excellent accueil",
      "createdAt": "2026-11-12T10:00:00.000"
    }
  ]
}''') as Map<String, dynamic>;
void main() {
  test('All module collections migrate and reopen unchanged', () async {
    final dir = await Directory.systemTemp.createTemp('animora-all8b-');
    final file = dir.uri.resolve('animora.db').toFilePath();
    final h = await ModuleHarness.create(
      path: file,
      mediaDirectory: dir,
      legacyCatalog: await legacyFixture8(),
    );
    final oldReportStorage = MemoryReportsStorage();
    final oldReportsDb = ReportsDatabase(oldReportStorage);
    final oldReports = LocalReportsRepository(oldReportsDb, () => h.actor);
    final report = await oldReports.createReport(
      reportDraft(lat: 36.8, lon: 10.18),
      locationConsent: true,
    );
    h.actor = h.other;
    await oldReports.confirmReport(
      report.id,
      comment: 'Vu à proximité du jardin.',
    );
    h.actor = h.citizen;
    final lost = await oldReports.saveAnnouncement(
      announcementDraft(AnnouncementType.LOST),
      creating: true,
      locationConsent: true,
    );
    await oldReports.saveSearchZone(lost.id, 36.8, 10.18, 2000, consent: true);
    h.actor = h.other;
    final found = await oldReports.saveAnnouncement(
      announcementDraft(AnnouncementType.FOUND),
      creating: true,
      locationConsent: true,
    );
    await oldReports.addTestimony(
      lost.id,
      'Aperçu ce matin près du jardin.',
      DateTime.now().subtract(const Duration(hours: 1)),
    );
    h.actor = h.citizen;
    await oldReports.refreshMatches();
    final claim = await oldReports.createClaim(found.id, evidence);
    h.actor = h.admin;
    await oldReports.decideClaim(claim.id, verified: true);
    h.actor = h.citizen;
    await oldReports.publishStory(
      found.id,
      'Retrouvailles après une recherche attentive.',
    );
    final donor = DonationHarness();
    final campaign = await donor.campaign();
    final need = await donor.need(campaign);
    await donor.repo.createFinancialDonation(
      campaign,
      12.345,
      confirmSimulation: true,
      requestKey: 'financial',
    );
    await donor.repo.createMaterialDonation(
      campaign,
      MaterialType.FOOD,
      2,
      'Deux sacs de nourriture pour les animaux.',
      needId: need,
    );
    final material = (await donor.repo.getMaterialDonations()).single;
    await donor.repo.receiveMaterialDonation(material.id);
    await donor.repo.createRecurringDonation(
      campaign,
      2.005,
      DonationFrequency.MONTHLY,
      donor.now.add(const Duration(days: 1)),
      requestKey: 'plan',
    );
    await donor.repo.publishTransparencyReport(
      campaign,
      'Bilan des dons reçus',
      'Les fonds et les sacs de nourriture soutiennent les animaux.',
    );
    final event = EventHarness();
    final e = await event.event(capacity: 2);
    final registration = await event.join(e, type: RegistrationType.VOLUNTEER);
    final ticket = (await event.repo.ticketForRegistration(registration.id))!;
    event.actor = event.users['demo-admin'];
    await event.repo.saveActivity(event.activity(e), creating: true);
    await event.repo.saveTask(
      event.task(e, assigned: registration.userId),
      creating: true,
    );
    event.now = e.startDate;
    await event.repo.checkIn(e.id, ticket.code);
    event.now = e.endDate.add(const Duration(minutes: 1));
    await event.repo.changeEventStatus(e.id, EventStatus.COMPLETED);
    await event.repo.saveReport(
      e.id,
      'Un événement de sensibilisation riche en rencontres.',
      publish: true,
    );
    Future<SembastReportsStorage> source(String name, String raw) async {
      final db = await sembast.databaseFactoryMemory.openDatabase(name);
      final s = SembastReportsStorage(
        database: Future.value(db),
        namespace: name,
      );
      await s.write(raw);
      return s;
    }

    final reportSource = await source('reports-rich', oldReportStorage.value!);
    final donationSource = await source('donations-rich', donor.storage.value!);
    final eventSource = await source('events-rich', event.storage.value!);
    final reports = SqliteReportsDatabase(h.context, reportSource);
    final serviceSource = servicesFixture8();
    (serviceSource['updates'] as List).single['photo'] = null;
    final serviceDb = SqliteServicesDatabase(
      h.context,
      MemoryReportsStorage()..value = jsonEncode(serviceSource),
    );
    final donations = SqliteDonationsDatabase(h.context, donationSource);
    final events = SqliteEventsDatabase(h.context, eventSource);
    await h.context.ensure('events');
    final snapshots = [
      await reports.read((d) => d.toJson()),
      await donations.read((d) => d.toJson()),
      await events.read((d) => d.toJson()),
    ];
    expect(snapshots[0], jsonDecode(oldReportStorage.value!));
    expect(snapshots[2], jsonDecode(event.storage.value!));
    expect(
      (snapshots[1]['campaigns'] as List).single['collectedAmount'],
      12.345,
    );
    expect((snapshots[1]['needs'] as List).single['receivedQuantity'], 2);
    for (final pair in [
      (reportSource, oldReportStorage.value!),
      (donationSource, donor.storage.value!),
      (eventSource, event.storage.value!),
    ]) {
      expect(await pair.$1.read(), pair.$2);
    }
    final sql = await h.helper.database;
    final counts = <String, int>{};
    for (final t in [
      ...reports.sql.tables,
      ...serviceDb.sql.tables,
      ...donations.sql.tables,
      ...events.sql.tables,
    ]) {
      counts[t.name] =
          (await sql.rawQuery('SELECT COUNT(*) n FROM ${t.name}')).single['n']
              as int;
      expect(counts[t.name], greaterThan(0), reason: t.name);
    }
    await h.close();
    final again = await ModuleHarness.create(path: file, mediaDirectory: dir);
    final reports2 = SqliteReportsDatabase(
      again.context,
      MemoryReportsStorage()..value = 'poison',
    );
    SqliteServicesDatabase(
      again.context,
      MemoryReportsStorage()..value = 'poison',
    );
    final donations2 = SqliteDonationsDatabase(
      again.context,
      MemoryReportsStorage()..value = 'poison',
    );
    final events2 = SqliteEventsDatabase(
      again.context,
      MemoryReportsStorage()..value = 'poison',
    );
    await again.context.ensure('events');
    expect(await reports2.read((d) => d.toJson()), snapshots[0]);
    expect(await donations2.read((d) => d.toJson()), snapshots[1]);
    expect(await events2.read((d) => d.toJson()), snapshots[2]);
    await again.close();
    oldReportsDb.dispose();
    donor.dispose();
    event.dispose();
    await Directory('output/database').create(recursive: true);
    await File(file).copy('output/database/animora-8b-demo.db');
  });

  test('Actual Sembast all services fields media import durable reopen and no reimport', () async {
    final dir = await Directory.systemTemp.createTemp('animora-persist8b-');
    final file = '${dir.path}/animora.db';
    final oldDb = await sembast.databaseFactoryMemory.openDatabase('care');
    final old = SembastReportsStorage(
      database: Future.value(oldDb),
      namespace: 'care_services',
    );
    final photo = await old.savePhoto(Uint8List.fromList([9, 8, 7, 6]));
    final source = servicesFixture8();
    (source['updates'] as List).single['photo'] = photo;
    final raw = jsonEncode(source);
    await old.write(raw);
    final h = await ModuleHarness.create(path: file, mediaDirectory: dir);
    SqliteReportsDatabase(h.context, MemoryReportsStorage());
    final services = SqliteServicesDatabase(h.context, old);
    SqliteDonationsDatabase(h.context, MemoryReportsStorage());
    SqliteEventsDatabase(h.context, MemoryReportsStorage());
    await h.context.ensure('events');
    expect(await services.read((d) async => d.toJson()), source);
    expect(await old.read(), raw);
    expect(await old.readPhoto(photo), [9, 8, 7, 6]);
    expect(await services.storage.readPhoto(photo), [9, 8, 7, 6]);
    final db = await h.helper.database;
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect(
      (await db.rawQuery('PRAGMA integrity_check')).single.values.single,
      'ok',
    );
    expect(
      (await db.rawQuery('PRAGMA user_version')).single.values.single,
      DatabaseConstants.version,
    );
    await h.close();
    final h2 = await ModuleHarness.create(path: file, mediaDirectory: dir);
    SqliteReportsDatabase(h2.context, MemoryReportsStorage());
    final poison = MemoryReportsStorage()
      ..value = 'invalid legacy must never be reread';
    final again = SqliteServicesDatabase(h2.context, poison);
    SqliteDonationsDatabase(h2.context, MemoryReportsStorage());
    SqliteEventsDatabase(h2.context, MemoryReportsStorage());
    await h2.context.ensure('events');
    expect(await again.read((d) async => d.toJson()), source);
    expect(await again.storage.readPhoto(photo), [9, 8, 7, 6]);
    expect(
      (await (await h2.helper.database).query(
        'database_metadata',
        where: "key LIKE 'sembast_%'",
      )).length,
      4,
    );
    await h2.close();
  });
  test('Services missing foreign key rolls back entire import then retries exactly once', () async {
    final h = await ModuleHarness.create();
    SqliteReportsDatabase(h.context, MemoryReportsStorage());
    final legacy = MemoryReportsStorage();
    final raw = servicesFixture8();
    (raw['updates'] as List).single['photo'] = null;
    (raw['vaccinations'] as List).single['animalId'] = 99999;
    legacy.value = jsonEncode(raw);
    final services = SqliteServicesDatabase(h.context, legacy);
    await expectLater(
      h.context.ensure('care_services'),
      throwsA(isA<DatabaseException>()),
    );
    final sql = await h.helper.database;
    expect(await sql.query('veterinary_appointments'), isEmpty);
    expect(await h.catalog.dao.metadata(sql, services.sql.marker), isNull);
    (raw['vaccinations'] as List).single['animalId'] = 1;
    legacy.value = jsonEncode(raw);
    await h.context.ensure('care_services');
    await h.context.ensure('care_services');
    expect((await sql.query('vaccinations')).length, 1);
    expect(await services.read((d) async => d.toJson()), raw);
    await h.close();
  });
  test(
    'Existing v2 database upgrades append-only to v6 retains old rows',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('animora-upgrade8b-');
      final file = '${dir.path}/animora.db';
      final old = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, v) => DatabaseMigrations.upgrade(db, 0, 2),
        ),
      );
      await old.insert('database_metadata', {
        'key': 'legacy-proof',
        'value': 'keep',
      });
      await old.close();
      final helper = DatabaseHelper(
        factory: databaseFactoryFfi,
        pathOverride: file,
      );
      final db = await helper.database;
      expect(
        (await db.query(
          'database_metadata',
          where: 'key=?',
          whereArgs: ['legacy-proof'],
        )).single['value'],
        'keep',
      );
      expect(
        (await db.query(
          'sqlite_master',
          where: "type='table' AND name='event_reports'",
        )).length,
        1,
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await helper.close();
    },
  );
}
