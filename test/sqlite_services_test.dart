import 'package:animora/features/veterinary/models/vaccination.dart';
import 'package:animora/features/veterinary/models/care.dart';
import 'package:animora/features/animal_services/services/services_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:animora/features/reports/database/sqlite_reports_database.dart';
import 'package:animora/features/animal_services/database/sqlite_animal_services_database.dart';
import 'package:animora/features/animal_services/repositories/local_services_repository.dart';
import 'package:animora/core/enums/appointment_status.dart';
import 'package:animora/core/enums/pet_sitting_status.dart';
import 'package:animora/features/veterinary/models/availability.dart';
import 'package:animora/features/pet_sitting/models/pet_sitter_settings.dart';

import 'services_repository_test.dart' show vet, sitter;
import 'sqlite_catalog_test.dart' show legacyFixture8;
import 'support/sql_module_test_support.dart';
import 'support/reports_test_support.dart';

void main() {
  late ModuleHarness h;
  late SqliteServicesDatabase db;
  late LocalServicesRepository r;
  var now = DateTime(2026, 11, 9, 12);
  setUp(() async {
    h = await ModuleHarness.create(legacyCatalog: await legacyFixture8());
    SqliteReportsDatabase(h.context, MemoryReportsStorage());
    db = SqliteServicesDatabase(h.context, MemoryReportsStorage());
    r = LocalServicesRepository(
      db,
      h.catalog,
      () => h.actor,
      () async => h.users.values.toList(),
      clock: () => now,
    );
    now = DateTime(2026, 11, 9, 12);
  });
  tearDown(() async {
    await h.close();
    db.dispose();
  });
  test('Medical SQLite access atomic vaccination reminder replacement and rollback', () async {
    h.actor = vet;
    await r.saveAvailability(
      Availability(
        id: 0,
        veterinarianUserId: vet.id,
        date: DateTime(2026, 11, 10),
        startTime: 540,
        endTime: 600,
        isFree: true,
      ),
      creating: true,
    );
    final slot = (await r.getAvailability(vet.id)).single;
    h.actor = h.citizen;
    await r.bookAppointment(slot.id, 1, 'Consultation de contrôle de santé.');
    final a = (await r.getAppointments()).single;
    h.actor = vet;
    await r.changeAppointmentStatus(a.id, AppointmentStatus.CONFIRMED);
    final draft = Vaccination(
      id: 0,
      animalId: 1,
      veterinarianUserId: vet.id,
      vaccineName: 'Rage',
      vaccinationDate: now,
      nextDoseDate: now.add(const Duration(days: 365)),
      veterinarianName: vet.fullName,
    );
    await r.saveVaccination(draft, creating: true);
    final v = (await r.getVaccinations(1)).single;
    await r.addCare(
      Care(
        id: 0,
        animalId: 1,
        veterinarianUserId: vet.id,
        type: 'Examen',
        date: now,
        description: 'Examen de santé et surveillance.',
        cost: 42.1234,
        veterinarianName: vet.fullName,
      ),
    );
    final sql = await h.helper.database;
    expect((await sql.query('health_reminders')).single['vaccinationId'], v.id);
    await sql.execute(
      "CREATE TRIGGER fail_reminder BEFORE INSERT ON health_reminders BEGIN SELECT RAISE(ABORT,'forced'); END",
    );
    await expectLater(
      r.saveVaccination(
        v.copyWith(nextDoseDate: now.add(const Duration(days: 400))),
        creating: false,
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect((await r.getVaccinations(1)).single.nextDoseDate, v.nextDoseDate);
    expect((await sql.query('health_reminders')).length, 1);
    await sql.execute('DROP TRIGGER fail_reminder');
    await r.saveVaccination(
      v.copyWith(nextDoseDate: now.add(const Duration(days: 400))),
      creating: false,
    );
    expect((await sql.query('health_reminders')).length, 1);
    final row = (await sql.query('veterinary_appointments')).single;
    await expectLater(
      sql.insert('veterinary_appointments', {...row, 'id': 999}),
      throwsA(isA<DatabaseException>()),
    );
    h.actor = h.other;
    await expectLater(r.getVaccinations(1), throwsA(isA<ServicesFailure>()));
    h.actor = h.citizen;
    expect((await r.getCare(1)).single.cost, 42.1234);
  });
  test('SQLite services nested catalog reads book cancel and historical slot deletion', () async {
    h.actor = vet;
    await r
        .saveAvailability(
          Availability(
            id: 0,
            veterinarianUserId: vet.id,
            date: DateTime(2026, 11, 10),
            startTime: 540,
            endTime: 600,
            isFree: true,
          ),
          creating: true,
        )
        .timeout(const Duration(seconds: 10));
    final slot = (await r.getAvailability(vet.id)).single;
    h.actor = h.citizen;
    await r.bookAppointment(slot.id, 1, 'Consultation de contrôle de santé.');
    final appointment = (await r.getAppointments()).single;
    final sql = await h.helper.database;
    expect(
      (await sql.query('veterinary_appointments')).single['availabilityLinkId'],
      slot.id,
    );
    await expectLater(
      sql.update('veterinary_appointments', {'animalId': 99999}),
      throwsA(isA<DatabaseException>()),
    );
    await r.changeAppointmentStatus(
      appointment.id,
      AppointmentStatus.CANCELLED,
    );
    h.actor = vet;
    await r.deleteAvailability(slot.id);
    expect(
      (await sql.query('veterinary_appointments')).single['availabilityId'],
      slot.id,
    );
    expect(
      (await sql.query('veterinary_appointments')).single['availabilityLinkId'],
      isNull,
    );
  });
  test(
    'SQLite pet sitting complete workflow review owner and unique guards',
    () async {
      h.actor = sitter;
      await r.savePetSitterSettings(
        PetSitterSettings(
          userId: sitter.id,
          available: true,
          dailyRate: 25,
          availableFrom: DateTime(2026, 11, 9),
          availableUntil: DateTime(2026, 12, 9),
        ),
      );
      h.actor = h.citizen;
      await r.createPetSittingRequest(
        sitter.id,
        1,
        DateTime(2026, 11, 10, 12),
        DateTime(2026, 11, 11, 12),
        'Promenades et repas habituels à respecter.',
      );
      final id = (await r.getPetSittingRequests()).single.id;
      h.actor = sitter;
      await r.changePetSittingStatus(id, PetSittingStatus.ACCEPTED);
      now = DateTime(2026, 11, 10, 12);
      await r.changePetSittingStatus(id, PetSittingStatus.IN_PROGRESS);
      await r.addUpdate(id, 'Tout se passe bien pour votre compagnon.');
      now = DateTime(2026, 11, 11, 12);
      await r.changePetSittingStatus(id, PetSittingStatus.COMPLETED);
      h.actor = h.citizen;
      await r.addReview(id, 5, 'Un accueil attentif et très rassurant.');
      final sql = await h.helper.database;
      final review = (await sql.query('reviews')).single;
      await expectLater(
        sql.insert('reviews', {...review, 'id': 999}),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        sql.update('reviews', {'reviewerUserId': sitter.id}),
        throwsA(isA<DatabaseException>()),
      );
      expect((await sql.query('pet_sitting_updates')).length, 1);
    },
  );
}
