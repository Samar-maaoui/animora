import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../../../core/enums/account_status.dart';
import '../../../core/enums/user_profile.dart';
import '../../../core/enums/event_status.dart';
import '../../../core/enums/registration_type.dart';
import '../../../core/enums/registration_status.dart';
import '../../../core/enums/volunteer_task_status.dart';
import '../models/event.dart';
import '../models/event_registration.dart';
import '../models/event_ticket.dart';
import '../models/event_activity.dart';
import '../models/volunteer_task.dart';
import '../models/event_report.dart';

import '../../users/models/user.dart';

import '../services/event_rules.dart';
import 'events_database.dart';
import 'event_repository.dart';
import 'event_registration_repository.dart';
import 'event_ticket_repository.dart';
import 'event_activity_repository.dart';
import 'volunteer_task_repository.dart';
import 'event_report_repository.dart';

class LocalEventRepository
    implements
        EventRepository,
        EventRegistrationRepository,
        EventTicketRepository,
        EventActivityRepository,
        VolunteerTaskRepository,
        EventReportRepository {
  LocalEventRepository(
    this.database,
    this.currentUser,
    this.isUserActive, {
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final EventsDatabase database;
  final User? Function() currentUser;
  final Future<bool> Function(String) isUserActive;
  final DateTime Function() clock;
  Never _fail(String message) => throw EventFailure(message);
  User _actor() {
    final u = currentUser();
    if (u == null || u.status != AccountStatus.active) {
      _fail('Un compte actif est nécessaire.');
    }
    return u;
  }

  bool _admin(User u) => u.profile == UserProfile.admin;
  void _requireAdmin(User u) {
    if (!_admin(u)) _fail('Action réservée à ADMIN.');
  }

  void _text(String text, int min, {int max = 10000}) {
    if (text.trim().length < min || text.length > max) {
      _fail('Saisissez entre $min et $max caractères.');
    }
  }

  Future<T> _read<T>(FutureOr<T> Function(EventsData, User) f) async {
    final id = _actor().id;
    return database.read((d) async {
      final u = _actor();
      if (u.id != id) _fail('La session a changé.');
      final result = await f(d, u);
      if (_actor().id != id) _fail('La session a changé.');
      return result;
    });
  }

  Future<T> _write<T>(FutureOr<T> Function(EventsData, User) f) async {
    final id = _actor().id;
    return database.mutate((d) async {
      final u = _actor();
      if (u.id != id) _fail('La session a changé.');
      final result = await f(d, u);
      if (_actor().id != id) _fail('La session a changé.');
      return result;
    });
  }

  Event _event(EventsData d, User u, int id) {
    final e = d.events[id];
    if (e == null || (e.status == EventStatus.DRAFT && !_admin(u))) {
      _fail('Événement inaccessible.');
    }
    return e;
  }

  Event _upcoming(EventsData d, User u, int id) {
    final e = _event(d, u, id);
    if (e.status != EventStatus.PUBLISHED || !clock().isBefore(e.startDate)) {
      _fail('Les inscriptions sont fermées pour cet événement.');
    }
    return e;
  }

  Event _editable(EventsData d, User u, int id) {
    _requireAdmin(u);
    final e = _event(d, u, id);
    if (e.status == EventStatus.COMPLETED ||
        e.status == EventStatus.CANCELLED) {
      _fail('Cet événement est archivé.');
    }
    return e;
  }

  EventRegistration _registration(EventsData d, User u, int id) {
    final r = d.registrations[id];
    if (r == null || (!_admin(u) && r.userId != u.id)) {
      _fail('Inscription privée ou introuvable.');
    }
    return r;
  }

  bool _occupies(EventRegistration r) =>
      r.status == RegistrationStatus.CONFIRMED ||
      r.status == RegistrationStatus.ATTENDED;
  int _occupied(EventsData d, int id) => d.registrations.values
      .where((r) => r.eventId == id && _occupies(r))
      .length;
  EventTicket _issue(EventsData d, EventRegistration r) {
    if (r.status != RegistrationStatus.CONFIRMED) {
      _fail('Inscription non confirmée.');
    }
    final existing = d.tickets.values.where((t) => t.registrationId == r.id);
    if (existing.isNotEmpty) return existing.single;
    String code;
    do {
      code =
          'ANIMORA-${List.generate(24, (_) => Random.secure().nextInt(16).toRadixString(16)).join().toUpperCase()}';
    } while (d.tickets.values.any((t) => t.code == code));
    final t = EventTicket(
      id: d.nextId++,
      registrationId: r.id,
      code: code,
      issueDate: clock(),
      used: false,
    );
    d.tickets[t.id] = t;
    return t;
  }

  void _releaseTasks(EventsData d, EventRegistration r) {
    for (final t in d.tasks.values.toList()) {
      if (t.eventId == r.eventId &&
          t.assignedUserId == r.userId &&
          t.status != VolunteerTaskStatus.COMPLETED) {
        d.tasks[t.id] = t.copyWith(
          assignedUserId: null,
          status: VolunteerTaskStatus.AVAILABLE,
        );
      }
    }
  }

  Future<void> _promote(EventsData d, Event e) async {
    if (e.status != EventStatus.PUBLISHED || !clock().isBefore(e.startDate)) {
      return;
    }
    var places = e.capacity - _occupied(d, e.id);
    final waiting =
        d.registrations.values
            .where(
              (r) =>
                  r.eventId == e.id &&
                  r.status == RegistrationStatus.WAITLISTED,
            )
            .toList()
          ..sort((a, b) {
            final order = a.registrationDate.compareTo(b.registrationDate);
            return order == 0 ? a.id.compareTo(b.id) : order;
          });
    for (final r in waiting) {
      if (places <= 0) break;
      if (!await isUserActive(r.userId)) continue;
      final promoted = r.copyWith(status: RegistrationStatus.CONFIRMED);
      d.registrations[r.id] = promoted;
      _issue(d, promoted);
      places--;
    }
  }

  @override
  Future<int> availablePlaces(int id) => _read((d, u) {
    final e = _event(d, u, id);
    return e.capacity - _occupied(d, id);
  });
  @override
  Future<List<Event>> getEvents() => _read(
    (d, u) =>
        d.events.values
            .where((e) => e.status != EventStatus.DRAFT || _admin(u))
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate)),
  );
  @override
  Future<Event> getEvent(int id) => _read((d, u) => _event(d, u, id));
  @override
  Future<Event> saveEvent(
    Event v, {
    required bool creating,
    Uint8List? imageBytes,
  }) => _write((d, u) async {
    _requireAdmin(u);
    final old = creating ? null : _editable(d, u, v.id);
    _text(v.title, 5, max: 150);
    _text(v.description, 20);
    _text(v.location, 3, max: 300);
    _text(v.city, 2, max: 100);
    if (!v.endDate.isAfter(v.startDate)) {
      _fail('La fin doit être postérieure au début.');
    }
    if (v.capacity < 1 || v.capacity > 1000000) {
      _fail('Capacité entière entre 1 et 1 000 000 attendue.');
    }
    if ((v.latitude == null) != (v.longitude == null) ||
        (v.latitude != null &&
            (!v.latitude!.isFinite ||
                v.latitude! < -90 ||
                v.latitude! > 90 ||
                !v.longitude!.isFinite ||
                v.longitude! < -180 ||
                v.longitude! > 180))) {
      _fail('Coordonnées géographiques invalides.');
    }
    if (old != null) {
      if (v.capacity < _occupied(d, old.id)) {
        _fail('La capacité ne peut pas être inférieure aux places occupées.');
      }
      if (d.registrations.values.any((r) => r.eventId == old.id) &&
          (v.startDate != old.startDate || v.endDate != old.endDate)) {
        _fail('Les dates sont figées dès la première inscription.');
      }
      for (final a in d.activities.values.where((a) => a.eventId == old.id)) {
        if (a.startTime.isBefore(v.startDate) || a.endTime.isAfter(v.endDate)) {
          _fail('Les activités doivent rester dans la période.');
        }
      }
    }
    if (old?.status == EventStatus.PUBLISHED &&
        !clock().isBefore(v.startDate)) {
      _fail('Un événement commencé ne peut plus être modifié.');
    }
    String? image = old?.image;
    if (imageBytes != null) {
      _photoBytes(imageBytes);
      image = await database.storage.savePhoto(imageBytes);
    }
    final e = v.copyWith(
      id: old?.id ?? d.nextId++,
      title: v.title.trim(),
      description: v.description.trim(),
      city: v.city.trim(),
      location: v.location.trim(),
      status: old?.status ?? EventStatus.DRAFT,
      image: image,
      organizerUserId: old?.organizerUserId ?? u.id,
    );
    d.events[e.id] = e;
    await _promote(d, e);
    return e;
  });
  @override
  Future<void> changeEventStatus(int id, EventStatus status) =>
      _write((d, u) async {
        _requireAdmin(u);
        final e = _editable(d, u, id);
        if (status == EventStatus.PUBLISHED &&
            e.status == EventStatus.DRAFT &&
            clock().isBefore(e.startDate)) {
          d.events[id] = e.copyWith(status: status);
          return;
        }
        if (status == EventStatus.COMPLETED &&
            e.status == EventStatus.PUBLISHED &&
            !clock().isBefore(e.endDate)) {
          d.events[id] = e.copyWith(status: status);
          for (final r in d.registrations.values.toList()) {
            if (r.eventId == id && r.status == RegistrationStatus.WAITLISTED) {
              d.registrations[r.id] = r.copyWith(
                status: RegistrationStatus.CANCELLED,
              );
            }
          }
          return;
        }
        if (status == EventStatus.CANCELLED) {
          d.events[id] = e.copyWith(status: status);
          for (final r in d.registrations.values.toList()) {
            if (r.eventId == id &&
                (r.status == RegistrationStatus.CONFIRMED ||
                    r.status == RegistrationStatus.WAITLISTED)) {
              d.registrations[r.id] = r.copyWith(
                status: RegistrationStatus.CANCELLED,
              );
              _releaseTasks(d, r);
            }
          }
          return;
        }
        _fail('Transition de statut non autorisée ou période incorrecte.');
      });
  void _photoBytes(Uint8List b) {
    if (b.isEmpty || b.length > 2 * 1024 * 1024) {
      _fail('Image de 2 Mo maximum attendue.');
    }
  }

  @override
  Future<Uint8List?> eventPhoto(int id) async {
    final uid = _actor().id;
    final ref = await _read((d, u) => _event(d, u, id).image);
    if (ref == null) return null;
    final bytes = await database.storage.readPhoto(ref);
    await _read((d, u) {
      if (u.id != uid) _fail('La session a changé.');
      _event(d, u, id);
    });
    return bytes;
  }

  @override
  Future<List<EventRegistration>> getRegistrations({int? eventId}) =>
      _read((d, u) {
        if (eventId != null) _event(d, u, eventId);
        return d.registrations.values
            .where(
              (r) =>
                  (eventId == null || r.eventId == eventId) &&
                  (_admin(u) || r.userId == u.id),
            )
            .toList()
          ..sort((a, b) => a.registrationDate.compareTo(b.registrationDate));
      });
  @override
  Future<EventRegistration> register(
    int eventId,
    RegistrationType type, {
    bool acceptWaitlist = false,
  }) => _write((d, u) async {
    final e = _upcoming(d, u, eventId);
    if (d.registrations.values.any(
      (r) =>
          r.eventId == eventId &&
          r.userId == u.id &&
          r.status != RegistrationStatus.CANCELLED,
    )) {
      _fail('Vous avez déjà une inscription active pour cet événement.');
    }
    await _promote(d, e);
    final full = _occupied(d, eventId) >= e.capacity;
    if (full && !acceptWaitlist) {
      _fail('Événement complet. Vous pouvez choisir la liste d’attente.');
    }
    final r = EventRegistration(
      id: d.nextId++,
      eventId: eventId,
      userId: u.id,
      userName: u.fullName,
      registrationDate: clock(),
      type: type,
      status: full
          ? RegistrationStatus.WAITLISTED
          : RegistrationStatus.CONFIRMED,
    );
    d.registrations[r.id] = r;
    if (!full) _issue(d, r);
    return r;
  });
  @override
  Future<void> cancelRegistration(int id) => _write((d, u) async {
    final r = _registration(d, u, id);
    final e = _upcoming(d, u, r.eventId);
    if (r.status != RegistrationStatus.CONFIRMED &&
        r.status != RegistrationStatus.WAITLISTED) {
      _fail('Cette inscription ne peut pas être annulée.');
    }
    d.registrations[id] = r.copyWith(status: RegistrationStatus.CANCELLED);
    _releaseTasks(d, r);
    await _promote(d, e);
  });
  @override
  Future<List<EventRegistration>> eligibleVolunteers(int eventId) =>
      _read((d, u) async {
        _requireAdmin(u);
        _event(d, u, eventId);
        final result = <EventRegistration>[];
        for (final r in d.registrations.values) {
          if (r.eventId == eventId &&
              r.type == RegistrationType.VOLUNTEER &&
              (r.status == RegistrationStatus.CONFIRMED ||
                  r.status == RegistrationStatus.ATTENDED) &&
              await isUserActive(r.userId)) {
            result.add(r);
          }
        }
        return result;
      });
  @override
  Future<EventTicket?> ticketForRegistration(int registrationId) =>
      _read((d, u) {
        final r = _registration(d, u, registrationId);
        final e = _event(d, u, r.eventId);
        if (r.status != RegistrationStatus.CONFIRMED ||
            e.status == EventStatus.CANCELLED ||
            e.status == EventStatus.COMPLETED ||
            !clock().isBefore(e.endDate)) {
          return null;
        }
        return d.tickets.values
            .where((t) => t.registrationId == r.id && !t.used)
            .firstOrNull;
      });
  @override
  Future<EventTicket> getTicket(int id) => _read((d, u) {
    final t = d.tickets[id];
    if (t == null) _fail('Billet introuvable.');
    final r = _registration(d, u, t.registrationId);
    final e = _event(d, u, r.eventId);
    if (t.used ||
        r.status != RegistrationStatus.CONFIRMED ||
        e.status != EventStatus.PUBLISHED ||
        !clock().isBefore(e.endDate)) {
      _fail('Ce billet est utilisé, annulé ou expiré.');
    }
    return t;
  });
  @override
  Future<EventRegistration> checkIn(int eventId, String code) => _write((
    d,
    u,
  ) async {
    _requireAdmin(u);
    final e = _event(d, u, eventId);
    if (e.status != EventStatus.PUBLISHED ||
        clock().isBefore(e.startDate) ||
        !clock().isBefore(e.endDate)) {
      _fail('Pointage disponible uniquement pendant l’événement publié.');
    }
    final t = d.tickets.values.where((t) => t.code == code.trim()).firstOrNull;
    if (t == null) _fail('Code de billet inconnu.');
    final r = d.registrations[t.registrationId]!;
    if (r.eventId != eventId) {
      _fail('Ce billet appartient à un autre événement.');
    }
    if (t.used || r.status != RegistrationStatus.CONFIRMED) {
      _fail('Billet déjà utilisé ou inscription invalide.');
    }
    if (!await isUserActive(r.userId)) {
      _fail('Le compte du participant n’est plus actif.');
    }
    d.tickets[t.id] = t.copyWith(used: true);
    final attended = r.copyWith(status: RegistrationStatus.ATTENDED);
    d.registrations[r.id] = attended;
    return attended;
  });
  @override
  Future<List<EventActivity>> getActivities(int eventId) => _read((d, u) {
    _event(d, u, eventId);
    return d.activities.values.where((a) => a.eventId == eventId).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  });
  @override
  Future<void> saveActivity(EventActivity v, {required bool creating}) =>
      _write((d, u) {
        final e = _editable(d, u, v.eventId);
        _text(v.title, 3, max: 150);
        _text(v.description, 10);
        if (!v.endTime.isAfter(v.startTime) ||
            v.startTime.isBefore(e.startDate) ||
            v.endTime.isAfter(e.endDate)) {
          _fail('L’activité doit se dérouler dans la période de l’événement.');
        }
        final old = d.activities[v.id];
        if (!creating && (old == null || old.eventId != v.eventId)) {
          _fail('Activité introuvable.');
        }
        final a = v.copyWith(
          id: creating ? d.nextId++ : v.id,
          title: v.title.trim(),
          description: v.description.trim(),
        );
        d.activities[a.id] = a;
      });
  @override
  Future<void> deleteActivity(int id) => _write((d, u) {
    final a = d.activities[id];
    if (a == null) _fail('Activité introuvable.');
    _editable(d, u, a.eventId);
    d.activities.remove(id);
  });
  @override
  Future<List<VolunteerTask>> getTasks({int? eventId}) => _read((d, u) {
    if (eventId != null) _event(d, u, eventId);
    return d.tasks.values
        .where(
          (t) =>
              (eventId == null || t.eventId == eventId) &&
              (_admin(u) || t.assignedUserId == u.id),
        )
        .toList();
  });
  @override
  Future<void> saveTask(VolunteerTask v, {required bool creating}) =>
      _write((d, u) async {
        _editable(d, u, v.eventId);
        _text(v.title, 3, max: 150);
        _text(v.description, 10);
        final old = d.tasks[v.id];
        if (!creating && (old == null || old.eventId != v.eventId)) {
          _fail('Tâche introuvable.');
        }
        if (old != null &&
            (old.status == VolunteerTaskStatus.IN_PROGRESS ||
                old.status == VolunteerTaskStatus.COMPLETED) &&
            (old.assignedUserId != v.assignedUserId)) {
          _fail('Une tâche commencée ne peut plus être réattribuée.');
        }
        if (v.assignedUserId != null) {
          if (!d.registrations.values.any(
                (r) =>
                    r.eventId == v.eventId &&
                    r.userId == v.assignedUserId &&
                    r.type == RegistrationType.VOLUNTEER &&
                    (r.status == RegistrationStatus.CONFIRMED ||
                        r.status == RegistrationStatus.ATTENDED),
              ) ||
              !await isUserActive(v.assignedUserId!)) {
            _fail('Choisissez un bénévole confirmé avec un compte actif.');
          }
        }
        final status = old != null && old.assignedUserId == v.assignedUserId
            ? old.status
            : v.assignedUserId == null
            ? VolunteerTaskStatus.AVAILABLE
            : VolunteerTaskStatus.ASSIGNED;
        final t = v.copyWith(
          id: creating ? d.nextId++ : v.id,
          status: status,
          title: v.title.trim(),
          description: v.description.trim(),
        );
        d.tasks[t.id] = t;
      });
  @override
  Future<void> advanceTask(int id, VolunteerTaskStatus status) =>
      _write((d, u) {
        final t = d.tasks[id];
        if (t == null || t.assignedUserId != u.id) {
          _fail('Cette tâche ne vous est pas attribuée.');
        }
        final e = _event(d, u, t.eventId);
        if (e.status != EventStatus.PUBLISHED || !clock().isBefore(e.endDate)) {
          _fail('Cet événement ne permet plus de modifier les tâches.');
        }
        if (!d.registrations.values.any(
          (r) =>
              r.eventId == e.id &&
              r.userId == u.id &&
              r.type == RegistrationType.VOLUNTEER &&
              (r.status == RegistrationStatus.CONFIRMED ||
                  r.status == RegistrationStatus.ATTENDED),
        )) {
          _fail('Inscription bénévole confirmée requise.');
        }
        if (!((t.status == VolunteerTaskStatus.ASSIGNED &&
                status == VolunteerTaskStatus.IN_PROGRESS) ||
            (t.status == VolunteerTaskStatus.IN_PROGRESS &&
                status == VolunteerTaskStatus.COMPLETED))) {
          _fail('Transition de tâche non autorisée.');
        }
        d.tasks[id] = t.copyWith(status: status);
      });
  @override
  Future<EventReport?> getReport(int eventId) => _read((d, u) {
    _event(d, u, eventId);
    final r = d.reports.values.where((r) => r.eventId == eventId).firstOrNull;
    return r != null && (r.published || _admin(u)) ? r : null;
  });
  @override
  Future<void> saveReport(
    int eventId,
    String description, {
    List<Uint8List> photos = const [],
    bool publish = false,
  }) => _write((d, u) async {
    _requireAdmin(u);
    final e = _event(d, u, eventId);
    if (e.status != EventStatus.COMPLETED) {
      _fail(
        'Terminez l’événement après sa date de fin avant de rédiger le bilan.',
      );
    }
    _text(description, 20);
    final old = d.reports.values.where((r) => r.eventId == eventId).firstOrNull;
    if (old?.published == true) _fail('Le bilan publié est figé.');
    if (photos.length + (old?.photos.length ?? 0) > 6) {
      _fail('Six photos maximum par bilan.');
    }
    for (final b in photos) {
      _photoBytes(b);
    }
    final refs = <String>[...?old?.photos];
    for (final b in photos) {
      refs.add(await database.storage.savePhoto(b));
    }
    final present = d.registrations.values.where(
      (r) => r.eventId == eventId && r.status == RegistrationStatus.ATTENDED,
    );
    final report = EventReport(
      id: old?.id ?? d.nextId++,
      eventId: eventId,
      participantCount: present
          .where((r) => r.type == RegistrationType.PARTICIPANT)
          .length,
      volunteerCount: present
          .where((r) => r.type == RegistrationType.VOLUNTEER)
          .length,
      description: description.trim(),
      createdAt: clock(),
      published: publish,
      photos: List.unmodifiable(refs),
    );
    d.reports[report.id] = report;
  });
  @override
  Future<Uint8List?> reportPhoto(int eventId, String reference) async {
    final uid = _actor().id;
    final r = await getReport(eventId);
    if (r == null || !r.photos.contains(reference)) {
      _fail('Photo inaccessible.');
    }
    final bytes = await database.storage.readPhoto(reference);
    final latest = await getReport(eventId);
    if (_actor().id != uid ||
        latest == null ||
        !latest.photos.contains(reference)) {
      _fail('Photo inaccessible.');
    }
    return bytes;
  }
}
