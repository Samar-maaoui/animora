import 'package:animora/features/donations/services/donation_rules.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:animora/features/reports/database/sqlite_reports_database.dart';
import 'package:animora/features/animal_services/database/sqlite_animal_services_database.dart';
import 'package:animora/features/donations/database/sqlite_donations_database.dart';
import 'package:animora/features/donations/repositories/local_donation_repository.dart';
import 'package:animora/core/enums/campaign_status.dart';

import 'donations_repository_test.dart' show DonationHarness;
import 'support/sql_module_test_support.dart';
import 'support/reports_test_support.dart';

void main() {
  late ModuleHarness h;
  late SqliteDonationsDatabase db;
  late MemoryReportsStorage legacy;
  late LocalDonationRepository r;
  setUp(() async {
    h = await ModuleHarness.create();
    SqliteReportsDatabase(h.context, MemoryReportsStorage());
    SqliteServicesDatabase(h.context, MemoryReportsStorage());
    legacy = MemoryReportsStorage();
    db = SqliteDonationsDatabase(h.context, legacy);
    r = LocalDonationRepository(
      db,
      () => h.actor,
      clock: () => DateTime(2026, 11, 9, 12),
    );
  });
  tearDown(() async {
    await h.close();
    db.dispose();
  });
  test('SQL donation confirmation receipt totals exact millimes idempotency rollback', () async {
    h.actor = h.admin;
    final c = await r.saveCampaign(DonationHarness().draft(), creating: true);
    await r.changeCampaignStatus(c.id, CampaignStatus.ACTIVE);
    h.actor = h.citizen;
    final x = await r.createFinancialDonation(c.id, 12.345, requestKey: 'once');
    await r.confirmFinancialDonation(x.id);
    await expectLater(
      r.confirmFinancialDonation(x.id),
      throwsA(isA<DonationFailure>()),
    );
    expect(
      (await r.createFinancialDonation(c.id, 12.345, requestKey: 'once')).id,
      x.id,
    );
    final sql = await h.helper.database;
    expect((await sql.query('donations')).single['amount'], 12345);
    expect(
      (await sql.query('donation_campaigns')).single['collectedAmount'],
      12345,
    );
    expect((await sql.query('donation_receipts')).length, 1);
    final row = (await sql.query('donation_receipts')).single;
    await expectLater(
      sql.insert('donation_receipts', {...row, 'id': 999}),
      throwsA(isA<DatabaseException>()),
    );
    await sql.execute(
      "CREATE TRIGGER fail_donation BEFORE INSERT ON donation_receipts BEGIN SELECT RAISE(ABORT,'forced'); END",
    );
    final pending = await r.createFinancialDonation(c.id, 0.111);
    await expectLater(
      r.confirmFinancialDonation(pending.id),
      throwsA(isA<DatabaseException>()),
    );
    expect((await r.getDonation(pending.id)).status.name, 'PENDING');
    expect((await r.getCampaign(c.id)).collectedAmount, 12.345);
    await sql.execute('DROP TRIGGER fail_donation');
    await r.confirmFinancialDonation(pending.id);
    expect((await r.getCampaign(c.id)).collectedAmount, 12.456);
  });
  test('Old donation store image receipts and identifiers migrate once source retained', () async {
    final old = DonationHarness();
    final id = await old.campaign();
    final c = await old.repo.getCampaign(id);
    await old.repo.saveCampaign(
      c,
      creating: false,
      imageBytes: Uint8List.fromList([7, 8, 9]),
    );
    final x = await old.repo.createFinancialDonation(
      id,
      1.001,
      confirmSimulation: true,
    );
    legacy.value = old.storage.value;
    legacy.photos.addAll(old.storage.photos);
    final source = jsonDecode(legacy.value!);
    h.actor = h.admin;
    expect((await r.getCampaign(id)).collectedAmount, 1.001);
    expect(await r.readCampaignImage(id), [7, 8, 9]);
    expect((await r.getReceiptForDonation(x.id))!.donationId, x.id);
    await h.context.ensure('donations');
    expect((await (await h.helper.database).query('donations')).length, 1);
    expect(jsonDecode(legacy.value!), source);
    old.dispose();
  });
}
