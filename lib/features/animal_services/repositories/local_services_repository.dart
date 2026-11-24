import 'dart:typed_data';

import '../../../core/enums/account_status.dart';
import '../../../core/enums/user_profile.dart';
import '../../../core/enums/adoption_status.dart';
import '../../../core/enums/hebergement_status.dart';
import '../../../core/enums/appointment_status.dart';
import '../../../core/enums/pet_sitting_status.dart';
import '../../users/models/user.dart';
import '../../adoption/models/animal.dart';
import '../../adoption/repositories/local_catalog_database.dart';
import '../../veterinary/models/availability.dart';
import '../../veterinary/models/veterinary_appointment.dart';
import '../../veterinary/models/vaccination.dart';
import '../../veterinary/models/care.dart';
import '../../veterinary/models/reminder.dart';
import '../../pet_sitting/models/pet_sitter_settings.dart';
import '../../pet_sitting/models/pet_sitting_request.dart';
import '../../pet_sitting/models/pet_sitting_update.dart';
import '../../pet_sitting/models/review.dart';
import '../../veterinary/repositories/veterinary_repository.dart';
import '../../veterinary/repositories/availability_repository.dart';
import '../../veterinary/repositories/veterinary_appointment_repository.dart';
import '../../veterinary/repositories/vaccination_repository.dart';
import '../../veterinary/repositories/care_repository.dart';
import '../../veterinary/repositories/reminder_repository.dart';
import '../../pet_sitting/repositories/pet_sitting_repository.dart';
import '../../pet_sitting/repositories/pet_sitting_update_repository.dart';
import '../../pet_sitting/repositories/review_repository.dart';
import '../services/services_failure.dart';
import 'services_database.dart';

class _Context {
  const _Context(this.user, this.catalog, this.providers);
  final User user;
  final CatalogData catalog;
  final List<User> providers;
}

class LocalServicesRepository
    implements
        VeterinaryRepository,
        AvailabilityRepository,
        VeterinaryAppointmentRepository,
        VaccinationRepository,
        CareRepository,
        ReminderRepository,
        PetSittingRepository,
        PetSittingUpdateRepository,
        ReviewRepository {
  LocalServicesRepository(
    this.database,
    this.catalog,
    this.currentUser,
    this.listProviders, {
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final ServicesDatabase database;
  final LocalCatalogDatabase catalog;
  final User? Function() currentUser;
  final Future<List<User>> Function() listProviders;
  final DateTime Function() clock;
  Never _fail(String s) => throw ServicesFailure(s);
  User _actor() {
    final u = currentUser();
    if (u == null || u.status != AccountStatus.active) {
      _fail('Un compte actif est nécessaire.');
    }
    return u;
  }

  bool _admin(User u) => u.profile == UserProfile.admin;
  void _role(User u, UserProfile profile) {
    if (u.profile != profile) {
      _fail('Cet espace est réservé au profil professionnel concerné.');
    }
  }

  void _text(String s, int min) {
    if (s.trim().length < min || s.length > 10000) {
      _fail('Saisissez entre $min et 10 000 caractères.');
    }
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime slotStart(Availability s) =>
      _day(s.date).add(Duration(minutes: s.startTime));
  DateTime slotEnd(Availability s) =>
      _day(s.date).add(Duration(minutes: s.endTime));
  bool _overlap(DateTime a, DateTime b, DateTime c, DateTime d) =>
      a.isBefore(d) && c.isBefore(b);
  Future<_Context> _contextFor(String identity) async {
    final snapshot = await catalog.read((d) => d.clone());
    final users = await listProviders();
    final u = _actor();
    if (u.id != identity) {
      _fail('La session a changé. Réessayez avec votre compte.');
    }
    return _Context(u, snapshot, users);
  }

  Future<T> _read<T>(T Function(ServicesData, _Context) f) async {
    final identity = _actor().id;
    return database.read((d) async => f(d, await _contextFor(identity)));
  }

  Future<T> _write<T>(T Function(ServicesData, _Context) f) async {
    final identity = _actor().id;
    return database.mutate((d) async => f(d, await _contextFor(identity)));
  }

  bool _responsible(_Context c, int id, {String? userId}) {
    final uid = userId ?? c.user.id;
    return c.catalog.workflow.adoptions.values.any(
          (a) =>
              a.userId == uid &&
              a.animalId == id &&
              a.status == AdoptionStatus.ACCEPTED &&
              a.adoptionDate != null &&
              c.catalog.workflow.contracts[a.id]?.signed == true,
        ) ||
        c.catalog.workflow.placements.values.any(
          (p) =>
              p.animalId == id &&
              p.fosterFamilyUserId == uid &&
              p.status == HebergementStatus.ACTIVE &&
              !p.startDate.isAfter(clock()) &&
              (p.endDate == null || p.endDate!.isAfter(clock())),
        );
  }

  Animal _animal(_Context c, int id) {
    final a = c.catalog.animals[id];
    if (a == null) _fail('Cet animal n’est plus disponible dans le catalogue.');
    return a;
  }

  bool _patient(ServicesData d, _Context c, int id) =>
      c.user.profile == UserProfile.veterinarian &&
      d.appointments.values.any(
        (a) =>
            a.animalId == id &&
            a.veterinarianUserId == c.user.id &&
            [
              AppointmentStatus.CONFIRMED,
              AppointmentStatus.COMPLETED,
            ].contains(a.status),
      );
  void _health(ServicesData d, _Context c, int id) {
    _animal(c, id);
    if (!_admin(c.user) && !_responsible(c, id) && !_patient(d, c, id)) {
      _fail('Vous n’êtes pas autorisé à consulter ce carnet de santé.');
    }
  }

  void _vetPatient(ServicesData d, _Context c, int id) {
    _role(c.user, UserProfile.veterinarian);
    _animal(c, id);
    if (!_patient(d, c, id)) {
      _fail(
        'Un rendez-vous confirmé ou terminé avec cet animal est nécessaire.',
      );
    }
  }

  User _provider(_Context c, String id, UserProfile profile) {
    final u = c.providers
        .where(
          (u) =>
              u.id == id &&
              u.status == AccountStatus.active &&
              u.profile == profile,
        )
        .firstOrNull;
    if (u == null) {
      _fail(
        'Ce professionnel n’est pas disponible ou son compte n’est plus actif.',
      );
    }
    return u;
  }

  @override
  Future<bool> canTreatAnimal(int id) =>
      _read((d, c) => c.catalog.animals.containsKey(id) && _patient(d, c, id));
  @override
  Future<List<User>> getVeterinarians() => _read(
    (d, c) => c.providers
        .where(
          (u) =>
              u.profile == UserProfile.veterinarian &&
              u.status == AccountStatus.active,
        )
        .toList(),
  );
  @override
  Future<bool> isPetSitterAvailable(String id, DateTime start, DateTime end) =>
      _read((d, c) {
        _provider(c, id, UserProfile.petSitter);
        final config = d.settings[id];
        return start.isAfter(clock()) &&
            end.isAfter(start) &&
            config != null &&
            config.available &&
            !start.isBefore(config.availableFrom) &&
            !end.isAfter(config.availableUntil) &&
            !_busy(d, id, start, end);
      });
  @override
  Future<List<User>> getPetSitters() => _read(
    (d, c) => c.providers
        .where(
          (u) =>
              u.profile == UserProfile.petSitter &&
              u.status == AccountStatus.active,
        )
        .toList(),
  );
  @override
  Future<List<Animal>> getResponsibleAnimals() => _read(
    (d, c) =>
        c.catalog.animals.values.where((a) => _responsible(c, a.id)).toList(),
  );
  @override
  Future<List<Animal>> getHealthAnimals() => _read(
    (d, c) => c.catalog.animals.values
        .where(
          (a) =>
              _admin(c.user) || _responsible(c, a.id) || _patient(d, c, a.id),
        )
        .toList(),
  );
  @override
  Future<Animal> getHealthAnimal(int id) => _read((d, c) {
    _health(d, c, id);
    return _animal(c, id);
  });
  @override
  Future<List<Availability>> getAvailability(
    String id, {
    bool includeReserved = false,
  }) => _read((d, c) {
    _provider(c, id, UserProfile.veterinarian);
    if (includeReserved && c.user.id != id && !_admin(c.user)) {
      _fail('Les créneaux réservés sont privés.');
    }
    return d.availability.values
        .where(
          (s) =>
              s.veterinarianUserId == id &&
              (includeReserved || (s.isFree && slotStart(s).isAfter(clock()))),
        )
        .toList()
      ..sort((a, b) => slotStart(a).compareTo(slotStart(b)));
  });
  bool _held(ServicesData d, int id) => d.appointments.values.any(
    (a) =>
        a.availabilityId == id &&
        [
          AppointmentStatus.PENDING,
          AppointmentStatus.CONFIRMED,
          AppointmentStatus.COMPLETED,
        ].contains(a.status),
  );
  @override
  Future<void> saveAvailability(Availability draft, {required bool creating}) =>
      _write((d, c) {
        _role(c.user, UserProfile.veterinarian);
        final start = slotStart(draft), end = slotEnd(draft);
        if (draft.startTime < 0 ||
            draft.startTime >= 1440 ||
            draft.endTime >= 1440 ||
            draft.endTime <= draft.startTime ||
            !end.isAfter(start) ||
            !start.isAfter(clock())) {
          _fail(
            'Choisissez un créneau futur avec une heure de fin supérieure au début.',
          );
        }
        final old = creating ? null : d.availability[draft.id];
        if (!creating && (old == null || old.veterinarianUserId != c.user.id)) {
          _fail('Créneau inaccessible.');
        }
        if (old != null && _held(d, old.id)) {
          _fail('Traitez le rendez-vous associé avant de modifier ce créneau.');
        }
        if (d.availability.values.any(
          (s) =>
              s.id != old?.id &&
              s.veterinarianUserId == c.user.id &&
              _overlap(start, end, slotStart(s), slotEnd(s)),
        )) {
          _fail('Ce créneau chevauche une disponibilité existante.');
        }
        final a = draft.copyWith(
          id: old?.id ?? d.nextId++,
          veterinarianUserId: c.user.id,
          date: _day(draft.date),
          isFree: true,
        );
        d.availability[a.id] = a;
      });
  @override
  Future<void> deleteAvailability(int id) => _write((d, c) {
    _role(c.user, UserProfile.veterinarian);
    final a = d.availability[id];
    if (a == null || a.veterinarianUserId != c.user.id) {
      _fail('Créneau inaccessible.');
    }
    if (_held(d, id)) {
      _fail(
        'Un rendez-vous est associé à ce créneau. Annulez ou refusez d’abord le rendez-vous ; les consultations terminées restent archivées.',
      );
    }
    d.availability.remove(id);
  });
  @override
  Future<List<VeterinaryAppointment>> getAppointments() => _read(
    (d, c) =>
        d.appointments.values
            .where(
              (a) =>
                  _admin(c.user) ||
                  a.clientUserId == c.user.id ||
                  a.veterinarianUserId == c.user.id,
            )
            .toList()
          ..sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate)),
  );
  @override
  Future<void> bookAppointment(
    int availabilityId,
    int animalId,
    String reason,
  ) => _write((d, c) {
    final s = d.availability[availabilityId];
    if (s == null ||
        !s.isFree ||
        _held(d, availabilityId) ||
        !slotStart(s).isAfter(clock())) {
      _fail('Ce créneau n’est plus disponible.');
    }
    final vet = _provider(c, s.veterinarianUserId, UserProfile.veterinarian);
    if (vet.id == c.user.id) {
      _fail('Vous ne pouvez pas prendre rendez-vous avec vous-même.');
    }
    final pet = _animal(c, animalId);
    if (!_responsible(c, animalId)) {
      _fail(
        'Choisissez un animal dont vous êtes responsable (adoption signée ou accueil actif).',
      );
    }
    _text(reason, 10);
    final a = VeterinaryAppointment(
      id: d.nextId++,
      veterinarianUserId: vet.id,
      clientUserId: c.user.id,
      animalId: animalId,
      availabilityId: s.id,
      appointmentDate: slotStart(s),
      reason: reason.trim(),
      status: AppointmentStatus.PENDING,
      clientName: c.user.fullName,
      veterinarianName: vet.fullName,
      animalName: pet.name,
    );
    d.appointments[a.id] = a;
    d.availability[s.id] = s.copyWith(isFree: false);
  });
  VeterinaryAppointment _appointment(ServicesData d, _Context c, int id) {
    final a = d.appointments[id];
    if (a == null ||
        (!_admin(c.user) &&
            a.clientUserId != c.user.id &&
            a.veterinarianUserId != c.user.id)) {
      _fail('Rendez-vous privé ou introuvable.');
    }
    return a;
  }

  @override
  Future<void> changeAppointmentStatus(
    int id,
    AppointmentStatus status, {
    String? notes,
  }) => _write((d, c) {
    final a = _appointment(d, c, id);
    final s = d.availability[a.availabilityId];
    if (s == null) _fail('Créneau associé introuvable.');
    if (status == AppointmentStatus.CANCELLED) {
      if (c.user.id != a.clientUserId && c.user.id != a.veterinarianUserId) {
        _fail('Seuls les participants peuvent annuler.');
      }
      if (![
            AppointmentStatus.PENDING,
            AppointmentStatus.CONFIRMED,
          ].contains(a.status) ||
          !a.appointmentDate.isAfter(clock())) {
        _fail('Annulation impossible pour ce statut ou cette date.');
      }
    } else {
      _role(c.user, UserProfile.veterinarian);
      if (a.veterinarianUserId != c.user.id) {
        _fail('Ce rendez-vous appartient à un autre vétérinaire.');
      }
      if (status == AppointmentStatus.CONFIRMED ||
          status == AppointmentStatus.REJECTED) {
        if (a.status != AppointmentStatus.PENDING) {
          _fail('Seule une demande en attente peut être acceptée ou refusée.');
        }
        if (status == AppointmentStatus.CONFIRMED) {
          if (!a.appointmentDate.isAfter(clock())) {
            _fail('Le créneau est passé.');
          }
          if (!_responsible(c, a.animalId, userId: a.clientUserId)) {
            _fail('Le demandeur n’est plus responsable de cet animal.');
          }
          _animal(c, a.animalId);
        }
      } else if (status == AppointmentStatus.COMPLETED) {
        if (a.status != AppointmentStatus.CONFIRMED ||
            clock().isBefore(a.appointmentDate)) {
          _fail(
            'Une consultation confirmée peut être terminée à partir de son heure prévue.',
          );
        }
      } else {
        _fail('Transition de rendez-vous interdite.');
      }
    }
    if (notes != null &&
        (c.user.id != a.veterinarianUserId || notes.length > 10000)) {
      _fail(
        'Notes réservées au vétérinaire concerné (10 000 caractères maximum).',
      );
    }
    d.appointments[id] = a.copyWith(status: status, notes: notes ?? a.notes);
    d.availability[s.id] = s.copyWith(
      isFree: ![
        AppointmentStatus.PENDING,
        AppointmentStatus.CONFIRMED,
        AppointmentStatus.COMPLETED,
      ].contains(status),
    );
  });
  @override
  Future<void> saveConsultationNotes(int id, String notes) => _write((d, c) {
    _role(c.user, UserProfile.veterinarian);
    final a = _appointment(d, c, id);
    if (a.veterinarianUserId != c.user.id ||
        ![
          AppointmentStatus.CONFIRMED,
          AppointmentStatus.COMPLETED,
        ].contains(a.status)) {
      _fail(
        'Notes réservées à une consultation confirmée ou terminée dont vous avez la charge.',
      );
    }
    if (notes.length > 10000) _fail('Notes limitées à 10 000 caractères.');
    d.appointments[id] = a.copyWith(notes: notes.trim());
  });
  @override
  Future<List<Vaccination>> getVaccinations(int id) => _read((d, c) {
    _health(d, c, id);
    return d.vaccinations.values.where((v) => v.animalId == id).toList()
      ..sort((a, b) => b.vaccinationDate.compareTo(a.vaccinationDate));
  });
  @override
  Future<void> saveVaccination(Vaccination draft, {required bool creating}) =>
      _write((d, c) {
        _vetPatient(d, c, draft.animalId);
        _text(draft.vaccineName, 2);
        if (draft.vaccinationDate.isAfter(clock()) ||
            (draft.nextDoseDate != null &&
                !draft.nextDoseDate!.isAfter(draft.vaccinationDate))) {
          _fail(
            'La vaccination doit être passée ou du jour, et la prochaine dose postérieure.',
          );
        }
        if (draft.notes != null && draft.notes!.length > 10000) {
          _fail('Notes trop longues.');
        }
        final old = creating ? null : d.vaccinations[draft.id];
        if (!creating &&
            (old == null ||
                old.veterinarianUserId != c.user.id ||
                old.animalId != draft.animalId)) {
          _fail('Seul le vétérinaire auteur peut modifier sa vaccination.');
        }
        final v = draft.copyWith(
          id: old?.id ?? d.nextId++,
          veterinarianUserId: c.user.id,
          veterinarianName: c.user.fullName,
        );
        d.vaccinations[v.id] = v;
        d.reminders.removeWhere((id, r) => r.vaccinationId == v.id);
        if (v.nextDoseDate != null) {
          final r = Reminder(
            id: d.nextId++,
            animalId: v.animalId,
            type: 'Prochaine dose : ${v.vaccineName}',
            scheduledDate: v.nextDoseDate!,
            isSent: false,
            vaccinationId: v.id,
            authorUserId: c.user.id,
          );
          d.reminders[r.id] = r;
        }
      });
  @override
  Future<List<Care>> getCare(int id) => _read((d, c) {
    _health(d, c, id);
    return d.care.values.where((v) => v.animalId == id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  });
  @override
  Future<void> addCare(Care draft) => _write((d, c) {
    _vetPatient(d, c, draft.animalId);
    _text(draft.type, 2);
    _text(draft.description, 10);
    if (draft.date.isAfter(clock())) {
      _fail(
        'Un soin réalisé ne peut pas avoir une date future. Utilisez un rappel pour planifier un soin.',
      );
    }
    if (draft.cost != null &&
        (!draft.cost!.isFinite || draft.cost! < 0 || draft.cost! > 1000000)) {
      _fail('Coût invalide.');
    }
    final v = draft.copyWith(
      id: d.nextId++,
      veterinarianUserId: c.user.id,
      veterinarianName: c.user.fullName,
    );
    d.care[v.id] = v;
  });
  @override
  Future<List<Reminder>> getReminders(int id) => _read((d, c) {
    _health(d, c, id);
    return d.reminders.values.where((v) => v.animalId == id).toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  });
  @override
  Future<void> addReminder(int id, String type, DateTime date) =>
      _write((d, c) {
        _health(d, c, id);
        if (!_responsible(c, id) && !_patient(d, c, id)) {
          _fail(
            'Seul le responsable ou le vétérinaire traitant peut planifier un rappel.',
          );
        }
        _text(type, 3);
        if (!date.isAfter(clock())) _fail('Choisissez une date future.');
        final r = Reminder(
          id: d.nextId++,
          animalId: id,
          type: type.trim(),
          scheduledDate: date,
          isSent: false,
          authorUserId: c.user.id,
        );
        d.reminders[r.id] = r;
      });
  @override
  Future<PetSitterSettings?> getPetSitterSettings(String id) => _read((d, c) {
    _provider(c, id, UserProfile.petSitter);
    return d.settings[id];
  });
  @override
  Future<void> savePetSitterSettings(PetSitterSettings draft) => _write((d, c) {
    _role(c.user, UserProfile.petSitter);
    if (!draft.dailyRate.isFinite ||
        draft.dailyRate <= 0 ||
        draft.dailyRate > 10000 ||
        !draft.availableUntil.isAfter(draft.availableFrom) ||
        !draft.availableUntil.isAfter(clock())) {
      _fail(
        'Indiquez un tarif positif (maximum 10 000 TND/jour) et une période valide.',
      );
    }
    if (draft.availableFrom.isBefore(_day(clock()))) {
      _fail('Le début de disponibilité ne peut pas être passé.');
    }
    final commitments = d.requests.values.where(
      (r) =>
          r.petSitterUserId == c.user.id &&
          [
            PetSittingStatus.ACCEPTED,
            PetSittingStatus.IN_PROGRESS,
          ].contains(r.status),
    );
    if (commitments.any(
      (r) =>
          r.startDate.isBefore(draft.availableFrom) ||
          r.endDate.isAfter(draft.availableUntil),
    )) {
      _fail(
        'La nouvelle période doit couvrir les gardes déjà acceptées ou en cours.',
      );
    }
    d.settings[c.user.id] = draft.copyWith(userId: c.user.id);
  });
  bool _busy(
    ServicesData d,
    String sitter,
    DateTime start,
    DateTime end, {
    int? except,
  }) => d.requests.values.any(
    (r) =>
        r.id != except &&
        r.petSitterUserId == sitter &&
        [
          PetSittingStatus.ACCEPTED,
          PetSittingStatus.IN_PROGRESS,
        ].contains(r.status) &&
        _overlap(start, end, r.startDate, r.endDate),
  );
  bool _animalBusy(
    ServicesData d,
    int id,
    DateTime start,
    DateTime end, {
    int? except,
  }) => d.requests.values.any(
    (r) =>
        r.id != except &&
        r.animalId == id &&
        [
          PetSittingStatus.ACCEPTED,
          PetSittingStatus.IN_PROGRESS,
        ].contains(r.status) &&
        _overlap(start, end, r.startDate, r.endDate),
  );
  @override
  double estimatePrice(double dailyRate, DateTime start, DateTime end) {
    final days =
        (end.difference(start).inMicroseconds / Duration.microsecondsPerDay)
            .ceil();
    if (!dailyRate.isFinite || dailyRate <= 0 || days < 1 || days > 366) {
      _fail('Durée ou tarif invalide (maximum 366 jours).');
    }
    return (days * dailyRate * 100).round() / 100;
  }

  PetSittingRequest _request(ServicesData d, _Context c, int id) {
    final r = d.requests[id];
    if (r == null ||
        (!_admin(c.user) &&
            r.ownerUserId != c.user.id &&
            r.petSitterUserId != c.user.id)) {
      _fail('Cette garde est privée ou introuvable.');
    }
    return r;
  }

  @override
  Future<List<PetSittingRequest>> getPetSittingRequests() => _read(
    (d, c) =>
        d.requests.values
            .where(
              (r) =>
                  _admin(c.user) ||
                  r.ownerUserId == c.user.id ||
                  r.petSitterUserId == c.user.id,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );
  @override
  Future<PetSittingRequest> getPetSittingRequest(int id) =>
      _read((d, c) => _request(d, c, id));
  @override
  Future<void> createPetSittingRequest(
    String id,
    int animalId,
    DateTime start,
    DateTime end,
    String instructions,
  ) => _write((d, c) {
    if (start.isBefore(clock()) || !end.isAfter(start)) {
      _fail('Choisissez une période future avec une fin supérieure au début.');
    }
    final sitter = _provider(c, id, UserProfile.petSitter);
    if (id == c.user.id) {
      _fail('Vous ne pouvez pas demander une garde à vous-même.');
    }
    final pet = _animal(c, animalId);
    if (!_responsible(c, animalId)) {
      _fail('Choisissez un animal dont vous êtes responsable.');
    }
    final settings = d.settings[id];
    if (settings == null ||
        !settings.available ||
        start.isBefore(settings.availableFrom) ||
        end.isAfter(settings.availableUntil)) {
      _fail('Le pet-sitter n’est pas disponible sur cette période.');
    }
    if (_busy(d, id, start, end) || _animalBusy(d, animalId, start, end)) {
      _fail('Cette période est déjà réservée.');
    }
    if (d.requests.values.any(
      (r) =>
          r.ownerUserId == c.user.id &&
          r.animalId == animalId &&
          r.petSitterUserId == id &&
          r.startDate == start &&
          r.endDate == end &&
          r.status == PetSittingStatus.PENDING,
    )) {
      _fail('Cette demande est déjà en attente.');
    }
    _text(instructions, 10);
    final total = estimatePrice(settings.dailyRate, start, end);
    final r = PetSittingRequest(
      id: d.nextId++,
      ownerUserId: c.user.id,
      petSitterUserId: id,
      animalId: animalId,
      startDate: start,
      endDate: end,
      status: PetSittingStatus.PENDING,
      totalPrice: total,
      createdAt: clock(),
      instructions: instructions.trim(),
      ownerName: c.user.fullName,
      petSitterName: sitter.fullName,
      animalName: pet.name,
    );
    d.requests[r.id] = r;
  });
  @override
  Future<void> changePetSittingStatus(
    int id,
    PetSittingStatus status,
  ) => _write((d, c) {
    final r = _request(d, c, id);
    if (status == PetSittingStatus.CANCELLED) {
      if (c.user.id != r.ownerUserId && c.user.id != r.petSitterUserId) {
        _fail('Seuls les participants peuvent annuler.');
      }
      if (![
        PetSittingStatus.PENDING,
        PetSittingStatus.ACCEPTED,
      ].contains(r.status)) {
        _fail(
          'Annulation impossible pour une garde déjà démarrée ou clôturée.',
        );
      }
    } else {
      _role(c.user, UserProfile.petSitter);
      if (r.petSitterUserId != c.user.id) {
        _fail('Cette demande appartient à un autre pet-sitter.');
      }
      if ([
        PetSittingStatus.ACCEPTED,
        PetSittingStatus.REJECTED,
      ].contains(status)) {
        if (r.status != PetSittingStatus.PENDING) {
          _fail('Décision réservée aux demandes en attente.');
        }
        if (status == PetSittingStatus.ACCEPTED) {
          if (!r.startDate.isAfter(clock())) _fail('Cette période a commencé.');
          final settings = d.settings[c.user.id];
          if (settings == null ||
              !settings.available ||
              r.startDate.isBefore(settings.availableFrom) ||
              r.endDate.isAfter(settings.availableUntil)) {
            _fail('Votre disponibilité ne couvre plus cette garde.');
          }
          _animal(c, r.animalId);
          if (!_responsible(c, r.animalId, userId: r.ownerUserId)) {
            _fail('Le demandeur n’est plus responsable de cet animal.');
          }
          if (_busy(d, c.user.id, r.startDate, r.endDate, except: r.id) ||
              _animalBusy(
                d,
                r.animalId,
                r.startDate,
                r.endDate,
                except: r.id,
              )) {
            _fail('Une garde acceptée ou en cours chevauche cette période.');
          }
        }
      } else if (status == PetSittingStatus.IN_PROGRESS) {
        if (r.status != PetSittingStatus.ACCEPTED ||
            clock().isBefore(r.startDate) ||
            !clock().isBefore(r.endDate)) {
          _fail(
            'La garde doit être acceptée et sa période en cours pour démarrer.',
          );
        }
        if (d.requests.values.any(
          (other) =>
              other.id != r.id &&
              other.status == PetSittingStatus.IN_PROGRESS &&
              (other.petSitterUserId == r.petSitterUserId ||
                  other.animalId == r.animalId),
        )) {
          _fail(
            'Une autre garde est encore en cours pour ce pet-sitter ou cet animal. Clôturez-la avant de démarrer.',
          );
        }
      } else if (status == PetSittingStatus.COMPLETED) {
        if (r.status != PetSittingStatus.IN_PROGRESS ||
            clock().isBefore(r.endDate)) {
          _fail('Une garde en cours peut être terminée à sa date de fin.');
        }
      } else {
        _fail('Transition de garde interdite.');
      }
    }
    d.requests[id] = r.copyWith(status: status);
  });
  @override
  Future<List<PetSittingUpdate>> getUpdates(int id) => _read((d, c) {
    _request(d, c, id);
    return d.updates.values.where((u) => u.petSittingRequestId == id).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  });
  @override
  Future<void> addUpdate(int id, String message, {Uint8List? photo}) async {
    final identity = _actor().id;
    // Authorize before persisting any private media; authorize again in the atomic write.
    await _read((d, c) {
      final r = _request(d, c, id);
      _role(c.user, UserProfile.petSitter);
      if (r.petSitterUserId != c.user.id ||
          r.status != PetSittingStatus.IN_PROGRESS) {
        _fail(
          'Les nouvelles sont réservées au pet-sitter pendant une garde démarrée.',
        );
      }
      _text(message, 2);
    });
    if (photo != null && (photo.isEmpty || photo.length > 2 * 1024 * 1024)) {
      _fail('Photo limitée à 2 Mo.');
    }
    final ref = photo == null ? null : await database.storage.savePhoto(photo);
    if (_actor().id != identity) _fail('La session a changé.');
    await _write((d, c) {
      final r = _request(d, c, id);
      _role(c.user, UserProfile.petSitter);
      if (r.petSitterUserId != c.user.id ||
          r.status != PetSittingStatus.IN_PROGRESS) {
        _fail('Cette garde n’est plus en cours.');
      }
      _text(message, 2);
      final u = PetSittingUpdate(
        id: d.nextId++,
        petSittingRequestId: id,
        message: message.trim(),
        photo: ref,
        createdAt: clock(),
      );
      d.updates[u.id] = u;
    });
  }

  @override
  Future<Uint8List?> readUpdatePhoto(int id) async {
    final identity = _actor().id;
    final reference = await _read((d, c) {
      final u = d.updates[id];
      if (u == null) _fail('Photo introuvable.');
      _request(d, c, u.petSittingRequestId);
      return u.photo;
    });
    if (reference == null) return null;
    final bytes = await database.storage.readPhoto(reference);
    if (_actor().id != identity) _fail('La session a changé.');
    return bytes;
  }

  @override
  Future<List<Review>> getReviews(String id) => _read((d, c) {
    _provider(c, id, UserProfile.petSitter);
    return d.reviews.values
        .where((v) => d.requests[v.petSittingRequestId]?.petSitterUserId == id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });
  @override
  Future<void> addReview(int id, int rating, String comment) => _write((d, c) {
    final r = _request(d, c, id);
    if (r.ownerUserId != c.user.id || r.status != PetSittingStatus.COMPLETED) {
      _fail('Seul le responsable peut évaluer une garde terminée.');
    }
    if (d.reviews.values.any((v) => v.petSittingRequestId == id)) {
      _fail('Un avis existe déjà pour cette garde.');
    }
    if (rating < 1 || rating > 5) {
      _fail('La note doit être comprise entre 1 et 5.');
    }
    _text(comment, 5);
    final v = Review(
      id: d.nextId++,
      petSittingRequestId: id,
      reviewerUserId: c.user.id,
      rating: rating,
      comment: comment.trim(),
      createdAt: clock(),
    );
    d.reviews[v.id] = v;
  });
}
