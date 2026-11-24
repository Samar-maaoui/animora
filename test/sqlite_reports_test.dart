import 'package:animora/features/reports/services/report_privacy.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:animora/core/database/database_helper.dart';
import 'package:animora/core/enums/report_status.dart';
import 'package:animora/core/enums/announcement_type.dart';
import 'package:animora/features/reports/database/sqlite_reports_database.dart';
import 'package:animora/features/reports/repositories/sqlite_reports_repository.dart';
import 'package:animora/features/reports/repositories/local_reports_repository.dart';
import 'package:animora/features/reports/repositories/reports_database.dart';

import 'reports_repository_test.dart'
    show reportDraft, announcementDraft, evidence;
import 'support/sql_module_test_support.dart';
import 'support/reports_test_support.dart';

void main() {
  test(
    'Media-like free text is preserved without treating it as a photo',
    () async {
      final h = await ModuleHarness.create();
      final db = SqliteReportsDatabase(h.context, MemoryReportsStorage());
      final r = SqliteReportsRepository(db, () => h.actor);
      final draft = reportDraft(
        description:
            'media:un texte descriptif qui ne référence aucune photographie',
      );
      final report = await r.createReport(draft);
      expect((await r.getReport(report.id)).description, draft.description);
      expect(await db.storage.readPhoto('assets/images/example.png'), isNull);
      await h.close();
      db.dispose();
    },
  );

  late ModuleHarness h;
  late MemoryReportsStorage legacy;
  late SqliteReportsDatabase db;
  late SqliteReportsRepository r;
  setUp(() async {
    h = await ModuleHarness.create();
    legacy = MemoryReportsStorage();
    db = SqliteReportsDatabase(h.context, legacy);
    r = SqliteReportsRepository(db, () => h.actor);
  });
  tearDown(() async {
    await h.close();
    db.dispose();
  });
  test(
    'Reports CRUD confirmations SQL uniqueness and owner isolation',
    () async {
      final report = await r.createReport(reportDraft());
      h.actor = h.other;
      await r.confirmReport(report.id, comment: 'Vu au même endroit.');
      expect((await r.getConfirmations(report.id)).length, 1);
      await expectLater(
        r.confirmReport(report.id),
        throwsA(isA<ReportsFailure>()),
      );
      h.actor = h.admin;
      await r.moderateReport(report.id, ReportStatus.CONFIRMED);
      expect((await r.getReport(report.id)).status, ReportStatus.CONFIRMED);
      final sql = await h.helper.database;
      expect((await sql.query('reports')).length, 1);
      final row = (await sql.query('report_confirmations')).single;
      await expectLater(
        sql.insert('report_confirmations', {...row, 'id': 999}),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        sql.update('reports', {'userId': 'missing'}),
        throwsA(isA<DatabaseException>()),
      );
    },
  );
  test(
    'LOST FOUND matching claims and story remain atomic SQL operations',
    () async {
      final lost = await r.saveAnnouncement(
        announcementDraft(AnnouncementType.LOST),
        creating: true,
        locationConsent: true,
      );
      h.actor = h.other;
      final found = await r.saveAnnouncement(
        announcementDraft(AnnouncementType.FOUND),
        creating: true,
        locationConsent: true,
      );
      h.actor = h.citizen;
      await r.refreshMatches();
      expect((await r.getMatches()).length, 1);
      final claim = await r.createClaim(found.id, evidence);
      h.actor = h.admin;
      await r.decideClaim(claim.id, verified: true);
      h.actor = h.citizen;
      await r.publishStory(
        found.id,
        'Retrouvailles après une recherche attentive.',
      );
      expect((await r.getStories()).length, 1);
      final sql = await h.helper.database;
      expect((await sql.query('claims')).single['status'], 'VERIFIED');
      expect(
        (await sql.query(
          'announcements',
          where: 'id = ?',
          whereArgs: [found.id],
        )).single['status'],
        'CLOSED',
      );
      expect((await r.getAnnouncement(lost.id)).id, lost.id);
    },
  );
  test(
    'Sembast metadata photos GPS statuses and IDs migrate unchanged once',
    () async {
      final oldDb = ReportsDatabase(legacy);
      final old = LocalReportsRepository(oldDb, () => h.actor);
      final ref = await old.savePhoto(Uint8List.fromList([1, 2, 3]));
      final report = await old.createReport(
        reportDraft(lat: 36.8123, lon: 10.189).copyWith(photo: ref),
        locationConsent: true,
      );
      final raw = legacy.value;
      expect((await r.getReport(report.id)).photo, ref);
      expect(await r.readPhoto(ref), [1, 2, 3]);
      expect(legacy.value, raw);
      await db.initialize();
      expect((await (await h.helper.database).query('reports')).length, 1);
      expect((await h.helper.database).path, ':memory:');
      expect(
        await h.catalog.dao.metadata(await h.helper.database, db.sql.marker),
        isNotNull,
      );
      oldDb.dispose();
    },
  );
  test(
    'Missing media and duplicate source IDs fail without marker and can retry',
    () async {
      final oldDb = ReportsDatabase(legacy);
      final old = LocalReportsRepository(oldDb, () => h.actor);
      final report = await old.createReport(
        reportDraft().copyWith(photo: 'media:missing'),
      );
      final raw = legacy.value;
      await expectLater(db.initialize(), throwsA(isA<DatabaseFailure>()));
      expect(
        await h.catalog.dao.metadata(await h.helper.database, db.sql.marker),
        isNull,
      );
      legacy.photos['media:missing'] = Uint8List.fromList([4, 5]);
      await db.initialize();
      expect(await r.readPhoto('media:missing'), [4, 5]);
      expect(legacy.value, raw);
      expect((await r.getReport(report.id)).id, report.id);
      oldDb.dispose();
    },
  );
  test(
    'SQL failure rolls back moderation and retries without resetting data',
    () async {
      final report = await r.createReport(reportDraft());
      final sql = await h.helper.database;
      await sql.execute(
        "CREATE TRIGGER fail_report BEFORE UPDATE ON reports BEGIN SELECT RAISE(ABORT,'forced'); END",
      );
      h.actor = h.admin;
      await expectLater(
        r.moderateReport(report.id, ReportStatus.CONFIRMED),
        throwsA(isA<DatabaseException>()),
      );
      expect((await r.getReport(report.id)).status, ReportStatus.NEW);
      await sql.execute('DROP TRIGGER fail_report');
      await r.moderateReport(report.id, ReportStatus.CONFIRMED);
    },
  );
  test(
    'Duplicate raw source records are rejected without silent map overwrite',
    () async {
      final oldDb = ReportsDatabase(legacy);
      final old = LocalReportsRepository(oldDb, () => h.actor);
      await old.createReport(reportDraft());
      final j = jsonDecode(legacy.value!) as Map<String, dynamic>;
      j['reports'].add(j['reports'].first);
      legacy.value = jsonEncode(j);
      await expectLater(db.initialize(), throwsA(isA<DatabaseFailure>()));
      expect(await (await h.helper.database).query('reports'), isEmpty);
      oldDb.dispose();
    },
  );
}
