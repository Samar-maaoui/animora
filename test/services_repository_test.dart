import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:animora/core/enums/account_status.dart';
import 'package:animora/core/enums/adoption_status.dart';
import 'package:animora/core/enums/hebergement_status.dart';
import 'package:animora/core/enums/appointment_status.dart';
import 'package:animora/core/enums/pet_sitting_status.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/users/models/user.dart';
import 'package:animora/features/adoption/models/adoption.dart';
import 'package:animora/features/adoption/models/contrat_adoption.dart';
import 'package:animora/features/adoption/models/hebergement.dart';
import 'package:animora/features/adoption/repositories/local_catalog_database.dart';
import 'package:animora/features/animal_services/repositories/local_services_repository.dart';
import 'package:animora/features/animal_services/repositories/services_database.dart';
import 'package:animora/features/animal_services/services/services_failure.dart';
import 'package:animora/features/veterinary/models/availability.dart';
import 'package:animora/features/veterinary/models/vaccination.dart';
import 'package:animora/features/veterinary/models/care.dart';
import 'package:animora/features/pet_sitting/models/pet_sitter_settings.dart';

import 'support/catalog_test_support.dart';
import 'support/reports_test_support.dart';

final citizen = DemoAccounts.users.firstWhere((u) => u.id == 'demo-citizen');
final vet = DemoAccounts.users.firstWhere((u) => u.id == 'demo-veterinarian');
final sitter = DemoAccounts.users.firstWhere((u) => u.id == 'demo-pet-sitter');
final foster = DemoAccounts.users.firstWhere((u) => u.id == 'demo-foster');
final admin = DemoAccounts.users.firstWhere((u) => u.id == 'demo-admin');

class ServiceHarness {
  ServiceHarness() {
    catalog = LocalCatalogDatabase(MemoryCatalogStorage());
    db = ServicesDatabase(storage);
    repository = LocalServicesRepository(
      db,
      catalog,
      () => actor,
      () async => users,
      clock: () => now,
    );
  }
  User? actor = citizen;
  DateTime now = DateTime(2026, 11, 9, 12);
  List<User> users = List.of(DemoAccounts.users);
  final storage = MemoryReportsStorage();
  late final LocalCatalogDatabase catalog;
  late final ServicesDatabase db;
  late final LocalServicesRepository repository;
  Future<void> assign(int animalId, User owner, {bool signed = true}) =>
      catalog.mutate((d) {
        final id = d.workflow.nextId++;
        d.workflow.adoptions[id] = Adoption(
          id: id,
          userId: owner.id,
          animalId: animalId,
          applicationDate: now.subtract(const Duration(days: 30)),
          motivation: 'Fixture adoption',
          compatibilityScore: 80,
          status: AdoptionStatus.ACCEPTED,
          adoptionDate: signed ? now.subtract(const Duration(days: 10)) : null,
        );
        d.workflow.contracts[id] = ContratAdoption(
          id: d.workflow.nextId++,
          adoptionId: id,
          conditions: 'Fixture contrat',
          signed: signed,
          signatureDate: signed ? now.subtract(const Duration(days: 10)) : null,
        );
      });
  Future<int> slot({int start = 540, int end = 600, int days = 1}) async {
    actor = vet;
    await repository.saveAvailability(
      Availability(
        id: 0,
        veterinarianUserId: 'forged',
        date: now.add(Duration(days: days)),
        startTime: start,
        endTime: end,
        isFree: false,
      ),
      creating: true,
    );
    return (await repository.getAvailability(
      vet.id,
      includeReserved: true,
    )).last.id;
  }

  Future<int> book(int slot, {int animalId = 1}) async {
    actor = citizen;
    await repository.bookAppointment(
      slot,
      animalId,
      'Consultation de contrôle pour mon compagnon.',
    );
    return (await repository.getAppointments()).last.id;
  }

  Future<void> configure({double rate = 25}) async {
    actor = sitter;
    await repository.savePetSitterSettings(
      PetSitterSettings(
        userId: 'forged',
        available: true,
        dailyRate: rate,
        availableFrom: DateTime(now.year, now.month, now.day),
        availableUntil: now.add(const Duration(days: 30)),
      ),
    );
  }

  Future<int> sitting({
    int animalId = 1,
    DateTime? start,
    DateTime? end,
  }) async {
    actor = citizen;
    await repository.createPetSittingRequest(
      sitter.id,
      animalId,
      start ?? now.add(const Duration(days: 1)),
      end ?? now.add(const Duration(days: 2)),
      'Promenades et repas habituels à respecter.',
    );
    return (await repository.getPetSittingRequests())
        .map((r) => r.id)
        .reduce((a, b) => a > b ? a : b);
  }

  Future<int> startedSitting() async {
    await configure();
    final id = await sitting();
    actor = sitter;
    await repository.changePetSittingStatus(id, PetSittingStatus.ACCEPTED);
    now = now.add(const Duration(days: 1));
    await repository.changePetSittingStatus(id, PetSittingStatus.IN_PROGRESS);
    return id;
  }

  Future<int> completedSitting() async {
    final id = await startedSitting();
    now = now.add(const Duration(days: 1));
    await repository.changePetSittingStatus(id, PetSittingStatus.COMPLETED);
    return id;
  }

  void dispose() {
    db.dispose();
    catalog.dispose();
  }
}

void main() {
  late ServiceHarness h;
  late LocalServicesRepository r;
  final failure = throwsA(isA<ServicesFailure>());
  setUp(() async {
    h = ServiceHarness();
    r = h.repository;
    await h.assign(1, citizen);
    await h.assign(2, foster);
    await h.assign(3, vet);
  });
  tearDown(() => h.dispose());
  test('Only active professional users listed, model remains User', () async {
    h.users = [
      ...h.users,
      vet.copyWith(status: AccountStatus.pending),
      sitter.copyWith(status: AccountStatus.blocked),
    ];
    expect((await r.getVeterinarians()).length, 1);
    expect((await r.getPetSitters()).length, 1);
    expect((await r.getVeterinarians()).first, isA<User>());
  });
  test('Responsibility requires signed adoption or current active foster placement', () async {
    await h.assign(4, citizen, signed: false);
    expect((await r.getResponsibleAnimals()).map((a) => a.id), [1]);
    await h.catalog.mutate((d) {
      d.workflow.placements[100] = Hebergement(
        id: 100,
        animalId: 5,
        fosterFamilyUserId: citizen.id,
        startDate: h.now.subtract(const Duration(days: 1)),
        status: HebergementStatus.ACTIVE,
        remarks: 'Fixture',
      );
    });
    expect((await r.getResponsibleAnimals()).map((a) => a.id), contains(5));
    await h.catalog.mutate((d) {
      d.workflow.placements[100] = d.workflow.placements[100]!.copyWith(
        status: HebergementStatus.COMPLETED,
      );
    });
    expect(
      (await r.getResponsibleAnimals()).map((a) => a.id),
      isNot(contains(5)),
    );
  });
  test(
    'Availability create update delete, forced identity and free state',
    () async {
      final id = await h.slot();
      final a = (await r.getAvailability(vet.id, includeReserved: true)).single;
      expect(a.veterinarianUserId, vet.id);
      expect(a.isFree, isTrue);
      expect(a.startTime, 540);
      await r.saveAvailability(
        a.copyWith(startTime: 600, endTime: 660),
        creating: false,
      );
      expect((await r.getAvailability(vet.id)).single.startTime, 600);
      await r.deleteAvailability(id);
      expect(await r.getAvailability(vet.id, includeReserved: true), isEmpty);
    },
  );
  test('Availability validates dates times overlap and adjacency', () async {
    await h.slot();
    for (final times in [(570, 630), (600, 600), (-1, 600), (540, 1500)]) {
      await expectLater(
        r.saveAvailability(
          Availability(
            id: 0,
            veterinarianUserId: '',
            date: h.now.add(const Duration(days: 1)),
            startTime: times.$1,
            endTime: times.$2,
            isFree: true,
          ),
          creating: true,
        ),
        failure,
      );
    }
    await h.slot(start: 600, end: 660);
    expect((await r.getAvailability(vet.id)).length, 2);
    await expectLater(h.slot(days: -1), failure);
  });
  test(
    'Citizen and admin cannot publish availability; reserved details private',
    () async {
      final id = await h.slot();
      h.actor = citizen;
      await expectLater(h.repository.deleteAvailability(id), failure);
      await expectLater(
        r.getAvailability(vet.id, includeReserved: true),
        failure,
      );
      h.actor = admin;
      await expectLater(
        r.saveAvailability(
          Availability(
            id: 0,
            veterinarianUserId: vet.id,
            date: h.now.add(const Duration(days: 1)),
            startTime: 700,
            endTime: 800,
            isFree: true,
          ),
          creating: true,
        ),
        failure,
      );
    },
  );
  test(
    'Booking reserves atomically and duplicate race cannot win twice',
    () async {
      final id = await h.slot();
      h.actor = citizen;
      final results = await Future.wait([
        r
            .bookAppointment(id, 1, 'Motif valide pour la consultation.')
            .then((_) => true, onError: (Object e) => false),
        r
            .bookAppointment(id, 1, 'Motif valide pour la consultation.')
            .then((_) => true, onError: (Object e) => false),
      ]);
      expect(results.where((v) => v).length, 1);
      expect(
        (await r.getAppointments()).single.status,
        AppointmentStatus.PENDING,
      );
      expect(await r.getAvailability(vet.id), isEmpty);
      h.actor = vet;
      await expectLater(r.deleteAvailability(id), failure);
      final a = (await r.getAvailability(vet.id, includeReserved: true)).single;
      await expectLater(
        r.saveAvailability(
          a.copyWith(startTime: 700, endTime: 800),
          creating: false,
        ),
        failure,
      );
    },
  );
  test('Booking denies foreign animal self booking inactive provider and invalid reason', () async {
    final id = await h.slot();
    h.actor = citizen;
    await expectLater(
      r.bookAppointment(id, 2, 'Motif valide de consultation.'),
      failure,
    );
    await expectLater(r.bookAppointment(id, 1, 'x'), failure);
    h.actor = vet;
    await expectLater(
      r.bookAppointment(id, 3, 'Motif valide de consultation.'),
      failure,
    );
    h.actor = citizen;
    h.users = h.users
        .map(
          (u) => u.id == vet.id ? u.copyWith(status: AccountStatus.blocked) : u,
        )
        .toList();
    await expectLater(
      r.bookAppointment(id, 1, 'Motif valide de consultation.'),
      failure,
    );
  });
  test('Only assigned vet accepts/refuses and rejection frees slot', () async {
    final slot = await h.slot();
    final id = await h.book(slot);
    await expectLater(
      r.changeAppointmentStatus(id, AppointmentStatus.CONFIRMED),
      failure,
    );
    h.actor = admin;
    await expectLater(
      r.changeAppointmentStatus(id, AppointmentStatus.CONFIRMED),
      failure,
    );
    h.actor = vet;
    await r.changeAppointmentStatus(id, AppointmentStatus.REJECTED);
    expect((await r.getAvailability(vet.id)).single.id, slot);
    await expectLater(
      r.changeAppointmentStatus(id, AppointmentStatus.CONFIRMED),
      failure,
    );
  });
  test('Cancellation permitted before appointment releases slot; late cancel denied', () async {
    final slot = await h.slot();
    final id = await h.book(slot);
    await r.changeAppointmentStatus(id, AppointmentStatus.CANCELLED);
    expect((await r.getAvailability(vet.id)).single.isFree, isTrue);
    final second = await h.book(slot);
    h.actor = vet;
    await r.changeAppointmentStatus(second, AppointmentStatus.CONFIRMED);
    h.now = h.now.add(const Duration(days: 2));
    h.actor = citizen;
    await expectLater(
      r.changeAppointmentStatus(second, AppointmentStatus.CANCELLED),
      failure,
    );
  });
  test(
    'Confirmed consultation notes and completion enforce actor and time',
    () async {
      final slot = await h.slot();
      final id = await h.book(slot);
      h.actor = vet;
      await r.changeAppointmentStatus(id, AppointmentStatus.CONFIRMED);
      await expectLater(
        r.changeAppointmentStatus(id, AppointmentStatus.COMPLETED),
        failure,
      );
      await r.saveConsultationNotes(
        id,
        'Contrôle effectué, observations locales.',
      );
      h.now = h.now.add(const Duration(days: 2));
      await r.changeAppointmentStatus(id, AppointmentStatus.COMPLETED);
      expect(
        (await r.getAppointments()).single.notes,
        'Contrôle effectué, observations locales.',
      );
      h.actor = citizen;
      await expectLater(
        r.saveConsultationNotes(id, 'Texte non autorisé'),
        failure,
      );
    },
  );
  test(
    'Health data inaccessible to other citizen sitter or unassigned vet',
    () async {
      expect((await r.getHealthAnimals()).map((a) => a.id), [1]);
      h.actor = foster;
      await expectLater(r.getVaccinations(1), failure);
      await expectLater(r.getCare(1), failure);
      h.actor = sitter;
      await expectLater(r.getHealthAnimal(1), failure);
      h.actor = vet;
      await expectLater(r.getHealthAnimal(1), failure);
      expect(await r.canTreatAnimal(1), isFalse);
      h.actor = admin;
      expect((await r.getHealthAnimal(1)).id, 1);
    },
  );
  test(
    'Vaccination creates one internal reminder and edits replace or remove it',
    () async {
      final slot = await h.slot();
      final id = await h.book(slot);
      h.actor = vet;
      await r.changeAppointmentStatus(id, AppointmentStatus.CONFIRMED);
      final draft = Vaccination(
        id: 0,
        animalId: 1,
        veterinarianUserId: 'forged',
        veterinarianName: 'forged',
        vaccineName: 'Vaccin de test',
        vaccinationDate: h.now,
        nextDoseDate: h.now.add(const Duration(days: 30)),
        notes: 'Saisie de démonstration',
      );
      await r.saveVaccination(draft, creating: true);
      var vaccine = (await r.getVaccinations(1)).single;
      expect(vaccine.veterinarianUserId, vet.id);
      expect((await r.getReminders(1)).single.isSent, isFalse);
      await r.saveVaccination(
        vaccine.copyWith(nextDoseDate: h.now.add(const Duration(days: 60))),
        creating: false,
      );
      expect((await r.getReminders(1)).length, 1);
      expect(
        (await r.getReminders(1)).single.scheduledDate,
        h.now.add(const Duration(days: 60)),
      );
      vaccine = (await r.getVaccinations(1)).single;
      await r.saveVaccination(
        vaccine.copyWith(nextDoseDate: null),
        creating: false,
      );
      expect(await r.getReminders(1), isEmpty);
      h.actor = citizen;
      await expectLater(r.saveVaccination(draft, creating: true), failure);
    },
  );
  test(
    'Vaccination future dates next dose and author editing restrictions',
    () async {
      final slot = await h.slot();
      final id = await h.book(slot);
      h.actor = vet;
      await r.changeAppointmentStatus(id, AppointmentStatus.CONFIRMED);
      final draft = Vaccination(
        id: 0,
        animalId: 1,
        veterinarianUserId: '',
        veterinarianName: '',
        vaccineName: 'Test',
        vaccinationDate: h.now.add(const Duration(days: 1)),
      );
      await expectLater(r.saveVaccination(draft, creating: true), failure);
      await expectLater(
        r.saveVaccination(
          draft.copyWith(
            vaccinationDate: h.now,
            nextDoseDate: h.now.subtract(const Duration(days: 1)),
          ),
          creating: true,
        ),
        failure,
      );
      await r.saveVaccination(
        draft.copyWith(vaccinationDate: h.now),
        creating: true,
      );
      h.actor = admin;
      await expectLater(
        r.saveVaccination((await r.getVaccinations(1)).single, creating: false),
        failure,
      );
    },
  );
  test(
    'Care validates costs type description and author, owner reads',
    () async {
      final slot = await h.slot();
      final id = await h.book(slot);
      h.actor = vet;
      await r.changeAppointmentStatus(id, AppointmentStatus.CONFIRMED);
      final care = Care(
        id: 0,
        animalId: 1,
        veterinarianUserId: '',
        veterinarianName: '',
        type: 'Contrôle',
        date: h.now,
        description: 'Contrôle de routine de démonstration.',
        cost: 25,
      );
      await r.addCare(care);
      expect((await r.getCare(1)).single.cost, 25);
      for (final bad in [
        care.copyWith(cost: -1),
        care.copyWith(cost: double.nan),
        care.copyWith(description: 'x'),
        care.copyWith(date: h.now.add(const Duration(days: 1))),
      ]) {
        await expectLater(r.addCare(bad), failure);
      }
      h.actor = citizen;
      expect((await r.getCare(1)).single.veterinarianUserId, vet.id);
      await expectLater(r.addCare(care), failure);
    },
  );
  test(
    'Responsible user plans internal care reminder, foreign user cannot',
    () async {
      await r.addReminder(
        1,
        'Soin planifié de démonstration',
        h.now.add(const Duration(days: 1)),
      );
      expect((await r.getReminders(1)).single.isSent, isFalse);
      await expectLater(
        r.addReminder(1, 'Soin passé', h.now.subtract(const Duration(days: 1))),
        failure,
      );
      h.actor = foster;
      await expectLater(
        r.addReminder(
          1,
          'Soin non autorisé',
          h.now.add(const Duration(days: 1)),
        ),
        failure,
      );
    },
  );
  test('Pet-sitter settings only correct active profile, valid rate period, identity imposed', () async {
    await expectLater(
      r.savePetSitterSettings(
        PetSitterSettings(
          userId: sitter.id,
          available: true,
          dailyRate: 20,
          availableFrom: h.now,
          availableUntil: h.now.add(const Duration(days: 10)),
        ),
      ),
      failure,
    );
    await h.configure();
    expect((await r.getPetSitterSettings(sitter.id))!.userId, sitter.id);
    await expectLater(h.configure(rate: -1), failure);
    await expectLater(h.configure(rate: double.infinity), failure);
    h.actor = sitter.copyWith(status: AccountStatus.blocked);
    await expectLater(
      r.savePetSitterSettings(
        PetSitterSettings(
          userId: sitter.id,
          available: true,
          dailyRate: 20,
          availableFrom: h.now,
          availableUntil: h.now.add(const Duration(days: 10)),
        ),
      ),
      failure,
    );
    h.actor = sitter.copyWith(status: AccountStatus.pending);
    await expectLater(r.getPetSitters(), failure);
  });
  test('Pet-sitting request enforces dates ownership no self booking and estimates frozen price', () async {
    await h.configure();
    final start = h.now.add(const Duration(days: 1)),
        end = h.now.add(const Duration(days: 2, hours: 1));
    final id = await h.sitting(start: start, end: end);
    expect((await r.getPetSittingRequest(id)).totalPrice, 50);
    await expectLater(h.sitting(start: start, end: end), failure);
    await expectLater(
      h.sitting(start: h.now.subtract(const Duration(days: 1))),
      failure,
    );
    await expectLater(h.sitting(start: start, end: start), failure);
    await expectLater(h.sitting(animalId: 2), failure);
    h.actor = sitter;
    await expectLater(
      r.createPetSittingRequest(
        sitter.id,
        1,
        start,
        end,
        'Instructions valides pour la garde.',
      ),
      failure,
    );
    await h.configure(rate: 40);
    h.actor = citizen;
    expect((await r.getPetSittingRequest(id)).totalPrice, 50);
  });
  test(
    'Accepted guards overlap for sitter and animal, adjacency permitted',
    () async {
      await h.configure();
      final id = await h.sitting();
      h.actor = sitter;
      await r.changePetSittingStatus(id, PetSittingStatus.ACCEPTED);
      expect(
        await r.isPetSitterAvailable(
          sitter.id,
          h.now.add(const Duration(days: 1)),
          h.now.add(const Duration(days: 2)),
        ),
        isFalse,
      );
      await expectLater(
        h.sitting(
          start: h.now.add(const Duration(days: 1, hours: 2)),
          end: h.now.add(const Duration(days: 2, hours: 2)),
        ),
        failure,
      );
      final next = await h.sitting(
        start: h.now.add(const Duration(days: 2)),
        end: h.now.add(const Duration(days: 3)),
      );
      h.actor = sitter;
      await r.changePetSittingStatus(next, PetSittingStatus.ACCEPTED);
      expect(
        (await r.getPetSittingRequests())
            .where((r) => r.status == PetSittingStatus.ACCEPTED)
            .length,
        2,
      );
    },
  );
  test(
    'Competing pending requests rechecked at acceptance capacity one',
    () async {
      await h.configure();
      final id = await h.sitting();
      await h.assign(4, citizen);
      final second = await h.sitting(animalId: 4);
      h.actor = sitter;
      await r.changePetSittingStatus(id, PetSittingStatus.ACCEPTED);
      await expectLater(
        r.changePetSittingStatus(second, PetSittingStatus.ACCEPTED),
        failure,
      );
      await r.changePetSittingStatus(second, PetSittingStatus.REJECTED);
    },
  );
  test('Only assigned sitter accepts; owner and admin cannot impersonate professional', () async {
    await h.configure();
    final id = await h.sitting();
    await expectLater(
      r.changePetSittingStatus(id, PetSittingStatus.ACCEPTED),
      failure,
    );
    h.actor = admin;
    await expectLater(
      r.changePetSittingStatus(id, PetSittingStatus.ACCEPTED),
      failure,
    );
    h.actor = sitter;
    await r.changePetSittingStatus(id, PetSittingStatus.REJECTED);
    await expectLater(
      r.changePetSittingStatus(id, PetSittingStatus.IN_PROGRESS),
      failure,
    );
  });
  test(
    'Cancellation releases period and cancelled request cannot start',
    () async {
      await h.configure();
      final id = await h.sitting();
      h.actor = sitter;
      await r.changePetSittingStatus(id, PetSittingStatus.ACCEPTED);
      h.actor = citizen;
      await r.changePetSittingStatus(id, PetSittingStatus.CANCELLED);
      h.actor = sitter;
      await expectLater(
        r.changePetSittingStatus(id, PetSittingStatus.IN_PROGRESS),
        failure,
      );
      expect(
        await r.isPetSitterAvailable(
          sitter.id,
          h.now.add(const Duration(days: 1)),
          h.now.add(const Duration(days: 2)),
        ),
        isTrue,
      );
    },
  );
  test('Start and completion respect time and transitions, updates private participants admin only', () async {
    await h.configure();
    final id = await h.sitting();
    h.actor = sitter;
    await r.changePetSittingStatus(id, PetSittingStatus.ACCEPTED);
    await expectLater(
      r.changePetSittingStatus(id, PetSittingStatus.IN_PROGRESS),
      failure,
    );
    await expectLater(r.addUpdate(id, 'Nouvelle avant le démarrage'), failure);
    h.now = h.now.add(const Duration(days: 1));
    await r.changePetSittingStatus(id, PetSittingStatus.IN_PROGRESS);
    await r.addUpdate(
      id,
      'Promenade et repas terminés.',
      photo: Uint8List.fromList([1, 2, 3]),
    );
    await expectLater(
      r.changePetSittingStatus(id, PetSittingStatus.COMPLETED),
      failure,
    );
    h.actor = citizen;
    final update = (await r.getUpdates(id)).single;
    expect(await r.readUpdatePhoto(update.id), [1, 2, 3]);
    await expectLater(r.addUpdate(id, 'Message du propriétaire'), failure);
    h.actor = foster;
    await expectLater(r.getUpdates(id), failure);
    await expectLater(r.readUpdatePhoto(update.id), failure);
    expect(await r.getPetSittingRequests(), isEmpty);
    h.actor = admin;
    expect((await r.getUpdates(id)).length, 1);
    h.actor = sitter;
    h.now = h.now.add(const Duration(days: 1));
    await r.changePetSittingStatus(id, PetSittingStatus.COMPLETED);
    await expectLater(r.addUpdate(id, 'Nouvelle après clôture'), failure);
  });
  test('Review requires completed request owner rating and one review only; public mean data', () async {
    await h.configure();
    final pending = await h.sitting();
    await expectLater(r.addReview(pending, 5, 'Très bonne garde'), failure);
    h.actor = sitter;
    await r.changePetSittingStatus(pending, PetSittingStatus.REJECTED);
    final id = await h.completedSitting();
    await expectLater(r.addReview(id, 5, 'Très bonne garde'), failure);
    h.actor = citizen;
    await expectLater(r.addReview(id, 0, 'Très bonne garde'), failure);
    await r.addReview(
      id,
      4,
      'Une garde attentive et des nouvelles régulières.',
    );
    await expectLater(r.addReview(id, 5, 'Second avis'), failure);
    h.actor = foster;
    expect((await r.getReviews(sitter.id)).single.rating, 4);
  });
  test('Changing availability cannot exclude commitments and disabling service does not cancel accepted care', () async {
    await h.configure();
    final id = await h.sitting();
    h.actor = sitter;
    await r.changePetSittingStatus(id, PetSittingStatus.ACCEPTED);
    final settings = (await r.getPetSitterSettings(sitter.id))!;
    await expectLater(
      r.savePetSitterSettings(
        settings.copyWith(availableUntil: h.now.add(const Duration(hours: 1))),
      ),
      failure,
    );
    await r.savePetSitterSettings(settings.copyWith(available: false));
    h.now = h.now.add(const Duration(days: 1));
    await r.changePetSittingStatus(id, PetSittingStatus.IN_PROGRESS);
  });
  test('Persistence after restart, private updates and review survive with rollback on failure', () async {
    final id = await h.completedSitting();
    h.actor = citizen;
    await r.addReview(id, 5, 'Très bonne garde de notre compagnon.');
    final nextDb = ServicesDatabase(h.storage);
    final next = LocalServicesRepository(
      nextDb,
      h.catalog,
      () => h.actor,
      () async => h.users,
      clock: () => h.now,
    );
    expect(
      (await next.getPetSittingRequest(id)).status,
      PetSittingStatus.COMPLETED,
    );
    expect((await next.getReviews(sitter.id)).single.rating, 5);
    nextDb.dispose();
    final slot = await h.slot(days: 2);
    h.actor = citizen;
    h.storage.fail = true;
    await expectLater(
      r.bookAppointment(slot, 1, 'Motif valide de consultation.'),
      throwsStateError,
    );
    expect((await r.getAvailability(vet.id)).single.isFree, isTrue);
  });
  test(
    'Queued mutations and deferred private photo reads cannot cross accounts',
    () async {
      final slot = await h.slot();
      h.actor = citizen;
      final pending = r.bookAppointment(
        slot,
        1,
        'Motif valide de consultation.',
      );
      h.actor = foster;
      await expectLater(pending, failure);
      final id = await h.startedSitting();
      await r.addUpdate(
        id,
        'Tout va bien pendant la garde.',
        photo: Uint8List.fromList([1]),
      );
      final photo = (await r.getUpdates(id)).single;
      h.storage.photoGate = Completer<void>();
      final read = r.readUpdatePhoto(photo.id);
      await Future<void>.delayed(Duration.zero);
      h.actor = foster;
      final check = expectLater(read, failure);
      h.storage.photoGate!.complete();
      await check;
    },
  );
  test('Missing suspended and pending accounts denied even direct repository calls', () async {
    for (final user in [
      null,
      citizen.copyWith(status: AccountStatus.blocked),
      vet.copyWith(status: AccountStatus.pending),
    ]) {
      h.actor = user;
      await expectLater(r.getAppointments(), failure);
      await expectLater(r.getPetSittingRequests(), failure);
    }
  });
  test(
    'Corrupt service data never silently resets existing snapshot',
    () async {
      final storage = MemoryReportsStorage()..value = '{"version":88}';
      final db = ServicesDatabase(storage);
      await expectLater(db.read((d) async => d.nextId), throwsFormatException);
      expect(storage.value, '{"version":88}');
      db.dispose();
    },
  );
  test(
    'Price rounds each started 24-hour interval including sub-minute remainder',
    () {
      final start = h.now;
      expect(
        r.estimatePrice(25, start, start.add(const Duration(days: 1))),
        25,
      );
      expect(
        r.estimatePrice(
          25,
          start,
          start.add(const Duration(days: 1, microseconds: 1)),
        ),
        50,
      );
      expect(
        r.estimatePrice(25, start, start.add(const Duration(seconds: 1))),
        25,
      );
      expect(
        () => r.estimatePrice(25, start, start),
        throwsA(isA<ServicesFailure>()),
      );
    },
  );
  test('Expired accepted request remains cancellable until it has actually started', () async {
    await h.configure();
    final id = await h.sitting();
    h.actor = sitter;
    await r.changePetSittingStatus(id, PetSittingStatus.ACCEPTED);
    h.now = h.now.add(const Duration(days: 3));
    await expectLater(
      r.changePetSittingStatus(id, PetSittingStatus.IN_PROGRESS),
      failure,
    );
    await r.changePetSittingStatus(id, PetSittingStatus.CANCELLED);
    expect(
      (await r.getPetSittingRequest(id)).status,
      PetSittingStatus.CANCELLED,
    );
  });
  test(
    'Only one guard can actually run even when previous scheduled period ended',
    () async {
      await h.configure();
      final first = await h.sitting();
      final second = await h.sitting(
        start: h.now.add(const Duration(days: 2)),
        end: h.now.add(const Duration(days: 3)),
      );
      h.actor = sitter;
      await r.changePetSittingStatus(first, PetSittingStatus.ACCEPTED);
      await r.changePetSittingStatus(second, PetSittingStatus.ACCEPTED);
      h.now = h.now.add(const Duration(days: 1));
      await r.changePetSittingStatus(first, PetSittingStatus.IN_PROGRESS);
      h.now = h.now.add(const Duration(days: 1));
      await expectLater(
        r.changePetSittingStatus(second, PetSittingStatus.IN_PROGRESS),
        failure,
      );
      await r.changePetSittingStatus(first, PetSittingStatus.COMPLETED);
      await r.changePetSittingStatus(second, PetSittingStatus.IN_PROGRESS);
    },
  );
}
