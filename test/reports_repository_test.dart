import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/users/models/user.dart';
import 'package:animora/core/enums/account_status.dart';
import 'package:animora/core/enums/report_type.dart';
import 'package:animora/core/enums/report_status.dart';
import 'package:animora/core/enums/announcement_type.dart';
import 'package:animora/core/enums/announcement_status.dart';
import 'package:animora/core/enums/claim_status.dart';
import 'package:animora/core/enums/match_status.dart';
import 'package:animora/features/reports/models/signalement.dart';
import 'package:animora/features/reports/models/annonce.dart';
import 'package:animora/features/reports/repositories/local_reports_repository.dart';
import 'package:animora/features/reports/repositories/reports_database.dart';
import 'package:animora/features/reports/repositories/reports_storage.dart';
import 'package:animora/features/reports/services/report_privacy.dart';
import 'package:animora/features/reports/services/report_location_service.dart';
import 'package:animora/features/reports/services/animal_matching_service.dart';

import 'support/reports_test_support.dart';

Signalement reportDraft({
  String description = 'Un chien blessé près du parc.',
  double? lat,
  double? lon,
  int urgency = 2,
}) => Signalement(
  id: 999,
  userId: 'forged',
  type: ReportType.INJURED_ANIMAL,
  description: description,
  latitude: lat,
  longitude: lon,
  urgencyLevel: urgency,
  status: ReportStatus.RESOLVED,
  createdAt: DateTime(2000),
);
Annonce announcementDraft(
  AnnouncementType type, {
  double? lat = 36.8,
  double? lon = 10.18,
}) => Annonce(
  id: 999,
  userId: 'forged',
  type: type,
  species: 'Chat',
  breed: 'Européen',
  color: 'gris blanc',
  description: 'Chat gris avec un collier bleu observé près du jardin.',
  distinguishingSigns: 'collier bleu',
  latitude: lat,
  longitude: lon,
  date: DateTime(2026, 1),
  status: AnnouncementStatus.CLOSED,
);
const evidence =
    'Je dispose du carnet de santé et de photographies anciennes montrant sa tache sous la patte.';

class Gateway implements LocationGateway {
  bool available = true;
  LocationPermission permissionValue = LocationPermission.denied;
  int requests = 0, positions = 0;
  bool timeout = false;
  @override
  Future<bool> enabled() async => available;
  @override
  Future<LocationPermission> permission() async => permissionValue;
  @override
  Future<LocationPermission> request() async {
    requests++;
    return permissionValue;
  }

  @override
  Future<ReportPoint> position() async {
    positions++;
    if (timeout) throw StateError('timeout');
    return const ReportPoint(36.812345, 10.187654);
  }
}

void main() {
  final citizen = DemoAccounts.users.firstWhere((u) => u.id == 'demo-citizen');
  final other = DemoAccounts.users.firstWhere(
    (u) => u.id == 'demo-veterinarian',
  );
  final admin = DemoAccounts.users.firstWhere((u) => u.id == 'demo-admin');
  late User? actor;
  late MemoryReportsStorage storage;
  late ReportsDatabase db;
  late LocalReportsRepository r;
  setUp(() {
    actor = citizen;
    storage = MemoryReportsStorage();
    db = ReportsDatabase(storage);
    r = LocalReportsRepository(db, () => actor);
  });
  tearDown(() => db.dispose());
  final failure = throwsA(isA<ReportsFailure>());
  test('Report creation overrides forged identity and status and rounds consented location', () async {
    final v = await r.createReport(
      reportDraft(lat: 36.812345, lon: 10.187654),
      locationConsent: true,
    );
    expect(v.userId, citizen.id);
    expect(v.status, ReportStatus.NEW);
    expect(v.id, isNot(999));
    expect(v.latitude, 36.81);
    expect(v.longitude, 10.19);
    expect(v.createdAt.year, greaterThan(2000));
  });
  test(
    'Report validates description urgency coordinate pair bounds and consent',
    () async {
      for (final d in [
        reportDraft(description: 'x'),
        reportDraft(urgency: 4),
        reportDraft(lat: 91, lon: 10),
        reportDraft(lat: 1),
        reportDraft(lat: 1, lon: 2),
      ]) {
        await expectLater(r.createReport(d), failure);
      }
      expect(await r.getReports(), isEmpty);
    },
  );
  test(
    'One independent confirmation per account; no self or closed confirmation',
    () async {
      final v = await r.createReport(reportDraft());
      await expectLater(r.confirmReport(v.id), failure);
      actor = other;
      await r.confirmReport(v.id);
      await expectLater(r.confirmReport(v.id), failure);
      expect((await r.getConfirmations(v.id)).length, 1);
      expect((await r.getReport(v.id)).status, ReportStatus.NEW);
      actor = admin;
      await r.moderateReport(v.id, ReportStatus.IN_PROGRESS);
      await r.moderateReport(v.id, ReportStatus.RESOLVED);
      await expectLater(r.confirmReport(v.id), failure);
      await expectLater(r.moderateReport(v.id, ReportStatus.NEW), failure);
    },
  );
  test('Report moderation is admin-only and rejected content private to owner and admin', () async {
    final v = await r.createReport(reportDraft());
    await expectLater(r.moderateReport(v.id, ReportStatus.REJECTED), failure);
    actor = admin;
    await r.moderateReport(v.id, ReportStatus.REJECTED);
    actor = other;
    expect(await r.getReports(), isEmpty);
    await expectLater(r.getReport(v.id), failure);
    actor = citizen;
    expect((await r.getReports()).length, 1);
  });
  test(
    'LOST and FOUND creation editing ownership and immutable type',
    () async {
      final a = await r.saveAnnouncement(
        announcementDraft(AnnouncementType.LOST),
        creating: true,
        locationConsent: true,
      );
      final b = await r.saveAnnouncement(
        announcementDraft(AnnouncementType.FOUND),
        creating: true,
        locationConsent: true,
      );
      expect(a.status, AnnouncementStatus.ACTIVE);
      expect(b.type, AnnouncementType.FOUND);
      actor = other;
      await expectLater(
        r.saveAnnouncement(
          a.copyWith(description: 'Nouvelle description de ce chat.'),
          creating: false,
          locationConsent: true,
        ),
        failure,
      );
      await expectLater(r.closeAnnouncement(a.id), failure);
      actor = citizen;
      await expectLater(
        r.saveAnnouncement(
          a.copyWith(type: AnnouncementType.FOUND),
          creating: false,
          locationConsent: true,
        ),
        failure,
      );
      await r.closeAnnouncement(a.id);
      await expectLater(
        r.saveAnnouncement(a, creating: false, locationConsent: true),
        failure,
      );
    },
  );
  test(
    'Announcement validation future date and public location consent',
    () async {
      final a = announcementDraft(AnnouncementType.LOST);
      for (final draft in [
        a.copyWith(species: ''),
        a.copyWith(color: ''),
        a.copyWith(description: 'x'),
        a.copyWith(date: DateTime.now().add(const Duration(days: 1))),
      ]) {
        await expectLater(
          r.saveAnnouncement(draft, creating: true, locationConsent: true),
          failure,
        );
      }
      await expectLater(r.saveAnnouncement(a, creating: true), failure);
    },
  );
  test('Testimonies chronological and dates and consent validated', () async {
    final a = await r.saveAnnouncement(
      announcementDraft(AnnouncementType.LOST),
      creating: true,
      locationConsent: true,
    );
    actor = other;
    await r.addTestimony(
      a.id,
      'Observation près de la gare.',
      DateTime(2026, 2, 2),
    );
    await r.addTestimony(
      a.id,
      'Observation près du jardin.',
      DateTime(2026, 2, 1),
    );
    final list = await r.getTestimonies(a.id);
    expect(list.first.date, DateTime(2026, 2, 1));
    await expectLater(r.addTestimony(a.id, 'x', DateTime(2026)), failure);
    await expectLater(
      r.addTestimony(
        a.id,
        'Observation valide du chat.',
        DateTime.now().add(const Duration(days: 1)),
      ),
      failure,
    );
    await expectLater(
      r.addTestimony(
        a.id,
        'Observation valide du chat.',
        DateTime(2026),
        latitude: 1,
        longitude: 2,
      ),
      failure,
    );
  });
  test('Search circle author only LOST radius validated and persists by announcement id', () async {
    final a = await r.saveAnnouncement(
      announcementDraft(AnnouncementType.LOST),
      creating: true,
      locationConsent: true,
    );
    await r.saveSearchZone(a.id, 36.812345, 10.18765, 3000, consent: true);
    expect((await r.getSearchZone(a.id))!.latitude, 36.81);
    await r.saveSearchZone(a.id, 36.81, 10.19, 5000, consent: true);
    expect((await r.getSearchZone(a.id))!.radius, 5000);
    actor = other;
    await expectLater(
      r.saveSearchZone(a.id, 1, 2, 3000, consent: true),
      failure,
    );
    actor = citizen;
    await expectLater(r.saveSearchZone(a.id, 1, 2, 1, consent: true), failure);
  });
  test('Matching bounded configurable score active LOST FOUND only', () {
    final matcher = AnimalMatchingService();
    final a = announcementDraft(AnnouncementType.LOST)
        .copyWith(status: AnnouncementStatus.ACTIVE);
    final b = announcementDraft(AnnouncementType.FOUND)
        .copyWith(status: AnnouncementStatus.ACTIVE);
    expect(matcher.score(a, b), 100);
    expect(matcher.score(a, b.copyWith(latitude: 0, longitude: 0)), 80);
    expect(
      matcher.score(a, b.copyWith(status: AnnouncementStatus.CLOSED)),
      isNull,
    );
    expect(matcher.score(a, b.copyWith(hidden: true)), isNull);
    expect(
      () => AnimalMatchingService(weights: {'species': 100}),
      throwsArgumentError,
    );
  });
  test(
    'Refresh unique matches no automatic ownership; rejection preserved',
    () async {
      await r.saveAnnouncement(
        announcementDraft(AnnouncementType.LOST),
        creating: true,
        locationConsent: true,
      );
      actor = other;
      await r.saveAnnouncement(
        announcementDraft(AnnouncementType.FOUND),
        creating: true,
        locationConsent: true,
      );
      await r.refreshMatches();
      await r.refreshMatches();
      final matches = await r.getMatches();
      expect(matches.length, 1);
      expect(matches.single.status, MatchStatus.DETECTED);
      await expectLater(
        r.moderateMatch(matches.single.id, MatchStatus.CONFIRMED),
        failure,
      );
      actor = admin;
      await r.moderateMatch(matches.single.id, MatchStatus.REJECTED);
      await r.refreshMatches();
      expect((await r.getMatches()).single.status, MatchStatus.REJECTED);
      actor = citizen;
      expect(await r.getMatches(), isEmpty);
    },
  );
  test('Hidden and closed announcements excluded from matching and cannot unhide on owner edit', () async {
    final a = await r.saveAnnouncement(
      announcementDraft(AnnouncementType.LOST),
      creating: true,
      locationConsent: true,
    );
    actor = other;
    await r.saveAnnouncement(
      announcementDraft(AnnouncementType.FOUND),
      creating: true,
      locationConsent: true,
    );
    await r.refreshMatches();
    actor = admin;
    await r.moderateAnnouncement(a.id, true);
    expect(await r.getMatches(), isEmpty);
    actor = citizen;
    await r.saveAnnouncement(
      a.copyWith(hidden: false),
      creating: false,
      locationConsent: true,
    );
    expect((await r.getAnnouncement(a.id)).hidden, isTrue);
    actor = other;
    await expectLater(r.getAnnouncement(a.id), failure);
  });
  test('Claim evidence private author and admin only; ownership type duplicate rules', () async {
    final lost = await r.saveAnnouncement(
      announcementDraft(AnnouncementType.LOST),
      creating: true,
      locationConsent: true,
    );
    final found = await r.saveAnnouncement(
      announcementDraft(AnnouncementType.FOUND),
      creating: true,
      locationConsent: true,
    );
    await expectLater(r.createClaim(found.id, evidence), failure);
    actor = other;
    await expectLater(r.createClaim(lost.id, evidence), failure);
    await expectLater(r.createClaim(found.id, 'x'), failure);
    final claim = await r.createClaim(found.id, evidence);
    expect(claim.status, ClaimStatus.PENDING);
    await expectLater(r.createClaim(found.id, evidence), failure);
    actor = citizen;
    expect(await r.getClaims(), isEmpty);
    await expectLater(r.getClaim(claim.id), failure);
    await expectLater(r.decideClaim(claim.id, verified: true), failure);
    actor = admin;
    expect((await r.getClaim(claim.id)).evidence, evidence);
  });
  test('Admin cannot verify own claim', () async {
    final a = await r.saveAnnouncement(
      announcementDraft(AnnouncementType.FOUND),
      creating: true,
      locationConsent: true,
    );
    actor = admin;
    final claim = await r.createClaim(a.id, evidence);
    await expectLater(r.decideClaim(claim.id, verified: true), failure);
  });
  test('Human claim verification atomically closes found rejects rivals and gates reunion story', () async {
    final a = await r.saveAnnouncement(
      announcementDraft(AnnouncementType.FOUND),
      creating: true,
      locationConsent: true,
    );
    actor = other;
    final claim = await r.createClaim(a.id, evidence);
    await expectLater(r.publishStory(a.id, 'Enfin réunis !'), failure);
    actor = admin;
    final rival = await r.createClaim(a.id, evidence);
    await r.decideClaim(claim.id, verified: true);
    expect((await r.getAnnouncement(a.id)).status, AnnouncementStatus.CLOSED);
    expect((await r.getClaim(rival.id)).status, ClaimStatus.REJECTED);
    await expectLater(r.decideClaim(claim.id, verified: true), failure);
    actor = citizen;
    await expectLater(r.publishStory(a.id, 'Enfin réunis !'), failure);
    actor = other;
    await r.publishStory(a.id, 'Enfin réunis !');
    expect((await r.getStories()).length, 1);
    await expectLater(r.publishStory(a.id, 'Encore réunis !'), failure);
  });
  test(
    'Only human confirmed match can also close claimant lost announcement',
    () async {
      final lost = await r.saveAnnouncement(
        announcementDraft(AnnouncementType.LOST),
        creating: true,
        locationConsent: true,
      );
      actor = other;
      final found = await r.saveAnnouncement(
        announcementDraft(AnnouncementType.FOUND),
        creating: true,
        locationConsent: true,
      );
      await r.refreshMatches();
      actor = citizen;
      final claim = await r.createClaim(found.id, evidence);
      actor = admin;
      await r.moderateMatch(
        (await r.getMatches()).single.id,
        MatchStatus.CONFIRMED,
      );
      await r.decideClaim(claim.id, verified: true);
      expect(
        (await r.getAnnouncement(lost.id)).status,
        AnnouncementStatus.CLOSED,
      );
    },
  );
  test(
    'Closing announcement rejects pending claims, testimony locked',
    () async {
      final a = await r.saveAnnouncement(
        announcementDraft(AnnouncementType.FOUND),
        creating: true,
        locationConsent: true,
      );
      actor = other;
      final claim = await r.createClaim(a.id, evidence);
      actor = citizen;
      await r.closeAnnouncement(a.id);
      actor = other;
      expect((await r.getClaim(claim.id)).status, ClaimStatus.REJECTED);
      await expectLater(
        r.addTestimony(a.id, 'Dernière observation du chat.', DateTime(2026)),
        failure,
      );
    },
  );
  test(
    'Storage survives repository recreation and failed write rolls back',
    () async {
      final a = await r.createReport(reportDraft());
      final next = LocalReportsRepository(
        ReportsDatabase(storage),
        () => actor,
      );
      expect((await next.getReports()).single.id, a.id);
      next.database.dispose();
      storage.fail = true;
      await expectLater(r.createReport(reportDraft()), throwsStateError);
      expect((await r.getReports()).length, 1);
    },
  );
  test(
    'Sembast metadata and media survive reopening and are separate',
    () async {
      final factory = databaseFactoryMemory;
      final first = SembastReportsStorage(
        database: factory.openDatabase('reports-persistence'),
      );
      await first.write('metadata');
      final bytes = Uint8List.fromList([1, 2, 3]);
      final ref = await first.savePhoto(bytes);
      await first.close();
      final second = SembastReportsStorage(
        database: factory.openDatabase('reports-persistence'),
      );
      expect(await second.read(), 'metadata');
      expect(await second.readPhoto(ref), bytes);
      await second.close();
    },
  );
  test('Photos private when attached to hidden or rejected record', () async {
    final ref = await r.savePhoto(Uint8List.fromList([1, 2]));
    final a = await r.createReport(reportDraft().copyWith(photo: ref));
    actor = admin;
    await r.moderateReport(a.id, ReportStatus.REJECTED);
    actor = other;
    await expectLater(r.readPhoto(ref), failure);
    actor = citizen;
    expect(await r.readPhoto(ref), [1, 2]);
  });
  test('No session blocked pending accounts denied', () async {
    actor = null;
    await expectLater(r.getReports(), failure);
    actor = citizen.copyWith(status: AccountStatus.blocked);
    await expectLater(r.createReport(reportDraft()), failure);
    actor = citizen.copyWith(status: AccountStatus.pending);
    await expectLater(r.getAnnouncements(), failure);
  });
  test('Queued operation cannot cross account switch', () async {
    final pending = r.createReport(reportDraft());
    actor = other;
    await expectLater(pending, failure);
    expect(await r.getReports(), isEmpty);
  });
  test(
    'GPS denial does not request position and service off skips permission',
    () async {
      final gateway = Gateway();
      final service = DeviceReportLocationService(gateway: gateway);
      await expectLater(service.locate(), throwsA(isA<LocationFailure>()));
      expect(gateway.positions, 0);
      expect(gateway.requests, 1);
      gateway.available = false;
      await expectLater(service.locate(), throwsA(isA<LocationFailure>()));
      expect(gateway.requests, 1);
    },
  );
  test(
    'GPS deniedForever and failures nonfatal; allowed path returns location',
    () async {
      final gateway = Gateway()
        ..permissionValue = LocationPermission.deniedForever;
      final service = DeviceReportLocationService(gateway: gateway);
      await expectLater(service.locate(), throwsA(isA<LocationFailure>()));
      expect(gateway.requests, 0);
      gateway.permissionValue = LocationPermission.whileInUse;
      gateway.timeout = true;
      await expectLater(service.locate(), throwsA(isA<LocationFailure>()));
      gateway.timeout = false;
      expect((await service.locate()).latitude, 36.812345);
    },
  );
  test('Pending private photo read cannot cross account change', () async {
    final ref = await r.savePhoto(Uint8List.fromList([1, 2]));
    final a = await r.createReport(reportDraft().copyWith(photo: ref));
    actor = admin;
    await r.moderateReport(a.id, ReportStatus.REJECTED);
    actor = citizen;
    storage.photoGate = Completer<void>();
    final pending = r.readPhoto(ref);
    await Future<void>.delayed(Duration.zero);
    actor = other;
    final check = expectLater(pending, failure);
    storage.photoGate!.complete();
    await check;
  });
}
