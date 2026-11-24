import 'dart:typed_data';

import '../../../core/enums/account_status.dart';
import '../../../core/enums/user_profile.dart';
import '../../../core/enums/report_status.dart';
import '../../../core/enums/announcement_type.dart';
import '../../../core/enums/announcement_status.dart';
import '../../../core/enums/claim_status.dart';
import '../../../core/enums/match_status.dart';
import '../../users/models/user.dart';
import '../services/report_privacy.dart';
import '../services/animal_matching_service.dart';
import '../models/signalement.dart';
import '../models/confirmation_signalement.dart';
import '../models/annonce.dart';
import '../models/temoignage.dart';
import '../models/zone_recherche.dart';
import '../models/correspondance.dart';
import '../models/reclamation.dart';
import '../models/histoire_retrouvailles.dart';
import 'reports_database.dart';
import 'report_repository.dart';
import 'announcement_repository.dart';
import 'testimony_repository.dart';
import 'matching_repository.dart';
import 'claim_repository.dart';

class LocalReportsRepository
    implements
        ReportRepository,
        AnnouncementRepository,
        TestimonyRepository,
        MatchingRepository,
        ClaimRepository {
  LocalReportsRepository(
    this.database,
    this.currentUser, {
    AnimalMatchingService? matching,
  }) : matching = matching ?? AnimalMatchingService();
  final ReportsDatabase database;
  final User? Function() currentUser;
  final AnimalMatchingService matching;
  Never fail(String s) => throw ReportsFailure(s);
  User actor() {
    final u = currentUser();
    if (u == null || u.status != AccountStatus.active) {
      fail('Un compte actif est nécessaire.');
    }
    return u;
  }

  bool admin(User u) => u.profile == UserProfile.admin;
  void requireAdmin(User u) {
    if (!admin(u)) fail('Accès réservé à l’administration.');
  }

  void text(String s, int min) {
    if (s.trim().length < min || s.length > 10000) {
      fail('Saisissez entre $min et 10 000 caractères.');
    }
  }

  Future<T> read<T>(T Function(ReportsData, User) f) async {
    final u = actor();
    return database.read((d) {
      final now = actor();
      if (now.id != u.id) fail('La session a changé.');
      return f(d, now);
    });
  }

  Future<T> write<T>(T Function(ReportsData, User) f) async {
    final u = actor();
    return database.mutate((d) {
      final now = actor();
      if (now.id != u.id) fail('La session a changé.');
      return f(d, now);
    });
  }

  Signalement report(ReportsData d, int id, User u) {
    final r = d.reports[id];
    if (r == null ||
        (r.status == ReportStatus.REJECTED && r.userId != u.id && !admin(u))) {
      fail('Signalement inaccessible.');
    }
    return r;
  }

  Annonce announcement(ReportsData d, int id, User u) {
    final a = d.announcements[id];
    if (a == null || (a.hidden && a.userId != u.id && !admin(u))) {
      fail('Annonce inaccessible.');
    }
    return a;
  }

  void owner(Annonce a, User u) {
    if (a.userId != u.id) fail('Seul l’auteur peut modifier cette annonce.');
    if (a.status != AnnouncementStatus.ACTIVE) {
      fail('Cette annonce est clôturée.');
    }
  }

  void active(Annonce a) {
    if (a.status != AnnouncementStatus.ACTIVE || a.hidden) {
      fail('Cette annonce n’est plus disponible.');
    }
  }

  @override
  Future<List<Signalement>> getReports() => read(
    (d, u) =>
        d.reports.values
            .where(
              (r) =>
                  r.status != ReportStatus.REJECTED ||
                  r.userId == u.id ||
                  admin(u),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );
  @override
  Future<Signalement> getReport(int id) => read((d, u) => report(d, id, u));
  @override
  Future<Signalement> createReport(
    Signalement draft, {
    bool locationConsent = false,
  }) => write((d, u) {
    text(draft.description, 10);
    if (draft.urgencyLevel < 1 || draft.urgencyLevel > 3) {
      fail('Urgence de 1 à 3.');
    }
    final p = ReportPrivacy.publish(
      draft.latitude,
      draft.longitude,
      consent: locationConsent,
    );
    final r = draft.copyWith(
      id: d.nextId++,
      userId: u.id,
      status: ReportStatus.NEW,
      createdAt: DateTime.now(),
      latitude: p?.latitude,
      longitude: p?.longitude,
    );
    d.reports[r.id] = r;
    return r;
  });
  @override
  Future<List<ConfirmationSignalement>> getConfirmations(int id) =>
      read((d, u) {
        report(d, id, u);
        return d.confirmations.values.where((c) => c.reportId == id).toList();
      });
  @override
  Future<void> confirmReport(int id, {String? comment}) => write((d, u) {
    final r = report(d, id, u);
    if (r.userId == u.id) {
      fail('Vous ne pouvez pas confirmer votre propre signalement.');
    }
    if ([ReportStatus.RESOLVED, ReportStatus.REJECTED].contains(r.status)) {
      fail('Ce signalement est clôturé.');
    }
    if (d.confirmations.values.any(
      (c) => c.reportId == id && c.userId == u.id,
    )) {
      fail('Votre confirmation est déjà enregistrée.');
    }
    if (comment != null && comment.length > 10000) {
      fail('Commentaire trop long.');
    }
    final c = ConfirmationSignalement(
      id: d.nextId++,
      reportId: id,
      userId: u.id,
      date: DateTime.now(),
      comment: comment?.trim(),
    );
    d.confirmations[c.id] = c;
  });
  @override
  Future<void> moderateReport(int id, ReportStatus status) => write((d, u) {
    requireAdmin(u);
    final r = report(d, id, u);
    final allowed = switch (r.status) {
      ReportStatus.NEW => [
        ReportStatus.CONFIRMED,
        ReportStatus.IN_PROGRESS,
        ReportStatus.REJECTED,
      ],
      ReportStatus.CONFIRMED => [
        ReportStatus.IN_PROGRESS,
        ReportStatus.RESOLVED,
        ReportStatus.REJECTED,
      ],
      ReportStatus.IN_PROGRESS => [
        ReportStatus.RESOLVED,
        ReportStatus.REJECTED,
      ],
      _ => <ReportStatus>[],
    };
    if (!allowed.contains(status)) fail('Transition de statut interdite.');
    d.reports[id] = r.copyWith(status: status);
  });
  @override
  Future<List<Annonce>> getAnnouncements() => read(
    (d, u) =>
        d.announcements.values
            .where((a) => !a.hidden || a.userId == u.id || admin(u))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date)),
  );
  @override
  Future<Annonce> getAnnouncement(int id) =>
      read((d, u) => announcement(d, id, u));
  void invalidate(ReportsData d, int id) {
    for (final m in d.matches.values.toList()) {
      if ((m.lostAnnouncementId == id || m.foundAnnouncementId == id) &&
          m.status == MatchStatus.CONFIRMED) {
        d.matches[m.id] = m.copyWith(status: MatchStatus.DETECTED);
      }
    }
  }

  @override
  Future<Annonce> saveAnnouncement(
    Annonce draft, {
    required bool creating,
    bool locationConsent = false,
  }) => write((d, u) {
    text(draft.species, 2);
    text(draft.color, 2);
    text(draft.description, 10);
    if (draft.date.isAfter(DateTime.now())) {
      fail('La date ne peut pas être future.');
    }
    final p = ReportPrivacy.publish(
      draft.latitude,
      draft.longitude,
      consent: locationConsent,
    );
    final old = creating ? null : announcement(d, draft.id, u);
    if (old != null) {
      owner(old, u);
      if (old.type != draft.type) {
        fail('Le type d’une annonce publiée ne peut pas changer.');
      }
      invalidate(d, old.id);
    }
    final a = draft.copyWith(
      id: old?.id ?? d.nextId++,
      userId: u.id,
      status: AnnouncementStatus.ACTIVE,
      hidden: old?.hidden ?? false,
      latitude: p?.latitude,
      longitude: p?.longitude,
    );
    d.announcements[a.id] = a;
    return a;
  });
  void close(ReportsData d, Annonce a) {
    d.announcements[a.id] = a.copyWith(status: AnnouncementStatus.CLOSED);
    for (final c in d.claims.values.toList()) {
      if (c.announcementId == a.id && c.status == ClaimStatus.PENDING) {
        d.claims[c.id] = c.copyWith(status: ClaimStatus.REJECTED);
      }
    }
  }

  @override
  Future<void> closeAnnouncement(int id) => write((d, u) {
    final a = announcement(d, id, u);
    owner(a, u);
    close(d, a);
  });
  @override
  Future<void> moderateAnnouncement(int id, bool hidden) => write((d, u) {
    requireAdmin(u);
    final a = announcement(d, id, u);
    d.announcements[id] = a.copyWith(hidden: hidden);
    invalidate(d, id);
  });
  @override
  Future<ZoneRecherche?> getSearchZone(int id) => read((d, u) {
    announcement(d, id, u);
    return d.zones[id];
  });
  @override
  Future<void> saveSearchZone(
    int id,
    double latitude,
    double longitude,
    double radius, {
    required bool consent,
  }) => write((d, u) {
    final a = announcement(d, id, u);
    owner(a, u);
    if (a.type != AnnouncementType.LOST) {
      fail('Zone réservée aux animaux perdus.');
    }
    if (!radius.isFinite || radius < 1000 || radius > 20000) {
      fail('Rayon de 1 à 20 km.');
    }
    final p = ReportPrivacy.publish(latitude, longitude, consent: consent)!;
    d.zones[id] = ZoneRecherche(
      id: d.zones[id]?.id ?? d.nextId++,
      announcementId: id,
      latitude: p.latitude,
      longitude: p.longitude,
      radius: radius,
      createdAt: DateTime.now(),
    );
  });
  @override
  Future<List<Temoignage>> getTestimonies(int id) => read((d, u) {
    announcement(d, id, u);
    return d.testimonies.values.where((t) => t.announcementId == id).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  });
  @override
  Future<void> addTestimony(
    int id,
    String comment,
    DateTime date, {
    double? latitude,
    double? longitude,
    String? photo,
    bool locationConsent = false,
  }) => write((d, u) {
    active(announcement(d, id, u));
    text(comment, 10);
    if (date.isAfter(DateTime.now())) fail('La date ne peut pas être future.');
    final p = ReportPrivacy.publish(
      latitude,
      longitude,
      consent: locationConsent,
    );
    final t = Temoignage(
      id: d.nextId++,
      announcementId: id,
      userId: u.id,
      date: date,
      comment: comment.trim(),
      photo: photo,
      latitude: p?.latitude,
      longitude: p?.longitude,
    );
    d.testimonies[t.id] = t;
  });
  bool matchActive(ReportsData d, Correspondance m) =>
      [
        d.announcements[m.lostAnnouncementId],
        d.announcements[m.foundAnnouncementId],
      ].every(
        (a) => a != null && !a.hidden && a.status == AnnouncementStatus.ACTIVE,
      );
  @override
  Future<List<Correspondance>> getMatches() => read(
    (d, u) =>
        d.matches.values
            .where(
              (m) =>
                  matchActive(d, m) &&
                  (m.status != MatchStatus.REJECTED || admin(u)),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score)),
  );
  @override
  Future<void> refreshMatches() => write((d, u) {
    for (final lost in d.announcements.values.where(
      (a) => a.type == AnnouncementType.LOST,
    )) {
      for (final found in d.announcements.values.where(
        (a) => a.type == AnnouncementType.FOUND,
      )) {
        final score = matching.score(lost, found);
        if (score == null) continue;
        final previous = d.matches.values
            .where(
              (m) =>
                  m.lostAnnouncementId == lost.id &&
                  m.foundAnnouncementId == found.id,
            )
            .firstOrNull;
        if (previous?.status == MatchStatus.REJECTED) continue;
        if (previous != null) {
          d.matches[previous.id] = previous.copyWith(score: score);
          continue;
        }
        if (score < 40) continue;
        final m = Correspondance(
          id: d.nextId++,
          lostAnnouncementId: lost.id,
          foundAnnouncementId: found.id,
          score: score,
          status: MatchStatus.DETECTED,
          detectedAt: DateTime.now(),
        );
        d.matches[m.id] = m;
      }
    }
  });
  @override
  Future<void> moderateMatch(int id, MatchStatus status) => write((d, u) {
    requireAdmin(u);
    final m = d.matches[id];
    if (m == null || !matchActive(d, m)) fail('Correspondance indisponible.');
    if (status == MatchStatus.DETECTED || m.status != MatchStatus.DETECTED) {
      fail('Décision déjà prise.');
    }
    d.matches[id] = m.copyWith(status: status);
  });
  @override
  Future<List<Reclamation>> getClaims() => read(
    (d, u) =>
        d.claims.values
            .where((c) => admin(u) || c.claimantUserId == u.id)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );
  @override
  Future<Reclamation> getClaim(int id) => read((d, u) {
    final c = d.claims[id];
    if (c == null || (!admin(u) && c.claimantUserId != u.id)) {
      fail('Réclamation privée.');
    }
    return c;
  });
  @override
  Future<Reclamation> createClaim(int id, String evidence) => write((d, u) {
    final a = announcement(d, id, u);
    active(a);
    if (a.type != AnnouncementType.FOUND || a.userId == u.id) {
      fail('Réclamation réservée à un animal trouvé par un autre utilisateur.');
    }
    text(evidence, 20);
    if (d.claims.values.any(
      (c) =>
          c.announcementId == id &&
          c.claimantUserId == u.id &&
          c.status != ClaimStatus.REJECTED,
    )) {
      fail('Vous avez déjà une réclamation ouverte.');
    }
    final c = Reclamation(
      id: d.nextId++,
      announcementId: id,
      claimantUserId: u.id,
      evidence: evidence.trim(),
      status: ClaimStatus.PENDING,
      createdAt: DateTime.now(),
    );
    d.claims[c.id] = c;
    return c;
  });
  @override
  Future<void> decideClaim(int id, {required bool verified}) => write((d, u) {
    requireAdmin(u);
    final c = d.claims[id];
    if (c == null) fail('Réclamation introuvable.');
    if (c.claimantUserId == u.id) {
      fail('Vous ne pouvez pas vérifier votre propre réclamation.');
    }
    if (c.status != ClaimStatus.PENDING) fail('Décision déjà prise.');
    final a = announcement(d, c.announcementId, u);
    active(a);
    if (verified) {
      close(d, a);
      for (final m in d.matches.values.where(
        (m) =>
            m.foundAnnouncementId == a.id && m.status == MatchStatus.CONFIRMED,
      )) {
        final lost = d.announcements[m.lostAnnouncementId];
        if (lost != null &&
            lost.userId == c.claimantUserId &&
            lost.status == AnnouncementStatus.ACTIVE) {
          close(d, lost);
        }
      }
    }
    d.claims[id] = c.copyWith(
      status: verified ? ClaimStatus.VERIFIED : ClaimStatus.REJECTED,
    );
  });
  @override
  Future<List<HistoireRetrouvailles>> getStories() => read(
    (d, u) =>
        d.stories.values
            .where((s) => d.announcements[s.announcementId]?.hidden == false)
            .toList()
          ..sort((a, b) => b.publicationDate.compareTo(a.publicationDate)),
  );
  @override
  Future<void> publishStory(int id, String title, {String? photo}) => write((
    d,
    u,
  ) {
    final a = announcement(d, id, u);
    final verified = d.claims.values.any(
      (c) =>
          c.announcementId == id &&
          c.status == ClaimStatus.VERIFIED &&
          (c.claimantUserId == u.id || admin(u)),
    );
    if (a.status != AnnouncementStatus.CLOSED || !verified || a.hidden) {
      fail(
        'Une réclamation vérifiée et une annonce clôturée sont nécessaires.',
      );
    }
    if (d.stories.values.any((s) => s.announcementId == id)) {
      fail('Une histoire existe déjà pour cet animal.');
    }
    text(title, 5);
    final s = HistoireRetrouvailles(
      id: d.nextId++,
      announcementId: id,
      title: title.trim(),
      photo: photo ?? a.photo,
      publicationDate: DateTime.now(),
      authorUserId: u.id,
    );
    d.stories[s.id] = s;
  });
  @override
  Future<String> savePhoto(Uint8List bytes) async {
    final identity = actor().id;
    if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
      fail('Photo limitée à 2 Mo.');
    }
    final reference = await database.storage.savePhoto(bytes);
    if (actor().id != identity) fail('La session a changé.');
    return reference;
  }

  @override
  Future<Uint8List?> readPhoto(String reference) async {
    final identity = actor().id;
    final allowed = await read(
      (d, u) =>
          d.reports.values.any(
            (r) =>
                r.photo == reference &&
                (r.status != ReportStatus.REJECTED ||
                    r.userId == u.id ||
                    admin(u)),
          ) ||
          d.announcements.values.any(
            (a) =>
                a.photo == reference &&
                (!a.hidden || a.userId == u.id || admin(u)),
          ) ||
          d.testimonies.values.any(
            (t) =>
                t.photo == reference &&
                d.announcements[t.announcementId] != null &&
                (!d.announcements[t.announcementId]!.hidden ||
                    d.announcements[t.announcementId]!.userId == u.id ||
                    admin(u)),
          ) ||
          d.stories.values.any(
            (s) =>
                s.photo == reference &&
                d.announcements[s.announcementId]?.hidden == false,
          ),
    );
    if (!allowed) fail('Photo inaccessible.');
    final bytes = await database.storage.readPhoto(reference);
    if (actor().id != identity) fail('La session a changé.');
    return bytes;
  }
}
