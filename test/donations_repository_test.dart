import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:animora/core/enums/account_status.dart';
import 'package:animora/core/enums/campaign_status.dart';
import 'package:animora/core/enums/donation_type.dart';
import 'package:animora/core/enums/donation_status.dart';
import 'package:animora/core/enums/material_type.dart';
import 'package:animora/core/enums/material_donation_status.dart';
import 'package:animora/core/enums/donation_frequency.dart';
import 'package:animora/core/enums/recurring_donation_status.dart';
import 'package:animora/core/enums/material_need_status.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/users/models/user.dart';
import 'package:animora/features/donations/models/donation_campaign.dart';
import 'package:animora/features/donations/models/material_need.dart';
import 'package:animora/features/donations/repositories/local_donation_repository.dart';
import 'package:animora/features/donations/repositories/donations_database.dart';
import 'package:animora/features/donations/services/donation_rules.dart';

import 'support/reports_test_support.dart';

final admin = DemoAccounts.users.firstWhere((u) => u.id == 'demo-admin');
final citizen = DemoAccounts.users.firstWhere((u) => u.id == 'demo-citizen');
final other = DemoAccounts.users.firstWhere((u) => u.id == 'demo-foster');

class DonationHarness {
  DonationHarness() {
    db = DonationsDatabase(storage);
    repo = LocalDonationRepository(db, () => actor, clock: () => now);
  }
  DateTime now = DateTime(2026, 11, 9, 12);
  User? actor = admin;
  final storage = MemoryReportsStorage();
  late final DonationsDatabase db;
  late final LocalDonationRepository repo;
  DonationCampaign draft() => DonationCampaign(
    id: 0,
    title: 'Croquettes pour les animaux',
    description:
        'Collecte de démonstration pour les besoins alimentaires des animaux.',
    targetAmount: 100,
    collectedAmount: 9999,
    startDate: now.subtract(const Duration(days: 1)),
    endDate: now.add(const Duration(days: 180)),
    status: CampaignStatus.ACTIVE,
  );
  Future<int> campaign({bool publish = true}) async {
    actor = admin;
    final c = await repo.saveCampaign(draft(), creating: true);
    if (publish) await repo.changeCampaignStatus(c.id, CampaignStatus.ACTIVE);
    return c.id;
  }

  Future<int> need(
    int campaign, {
    MaterialType type = MaterialType.FOOD,
    int quantity = 10,
  }) async {
    actor = admin;
    await repo.saveMaterialNeed(
      MaterialNeed(
        id: 0,
        campaignId: campaign,
        description: 'Sacs de nourriture pour les animaux.',
        requestedQuantity: quantity,
        receivedQuantity: 999,
        status: MaterialNeedStatus.FULFILLED,
        itemType: type,
      ),
      creating: true,
    );
    return (await repo.getMaterialNeeds(campaign)).last.id;
  }

  void dispose() {
    db.dispose();
  }
}

void main() {
  late DonationHarness h;
  late LocalDonationRepository r;
  final failure = throwsA(isA<DonationFailure>());
  setUp(() {
    h = DonationHarness();
    r = h.repo;
  });
  tearDown(() => h.dispose());
  test('Campaign created DRAFT collected field ignored editing and publication controlled', () async {
    final id = await h.campaign(publish: false);
    var c = await r.getCampaign(id);
    expect(c.status, CampaignStatus.DRAFT);
    expect(c.collectedAmount, 0);
    c = await r.saveCampaign(
      c.copyWith(title: 'Nouveau titre de campagne', collectedAmount: 500),
      creating: false,
    );
    expect(c.title, 'Nouveau titre de campagne');
    expect(c.collectedAmount, 0);
    await r.changeCampaignStatus(id, CampaignStatus.ACTIVE);
    expect((await r.getCampaign(id)).status, CampaignStatus.ACTIVE);
    h.actor = citizen;
    await expectLater(r.saveCampaign(c, creating: false), failure);
    await expectLater(
      r.changeCampaignStatus(id, CampaignStatus.CANCELLED),
      failure,
    );
  });
  test(
    'Campaign validation target amounts title description and date ordering',
    () async {
      for (final value in [
        0.0,
        -1.0,
        double.nan,
        double.infinity,
        0.000000001,
        1.2345,
      ]) {
        await expectLater(
          r.saveCampaign(
            h.draft().copyWith(targetAmount: value),
            creating: true,
          ),
          failure,
        );
      }
      for (final c in [
        h.draft().copyWith(title: 'x'),
        h.draft().copyWith(description: 'court'),
        h.draft().copyWith(endDate: h.now.subtract(const Duration(days: 2))),
        h.draft().copyWith(startDate: h.now.add(const Duration(days: 200))),
      ]) {
        await expectLater(r.saveCampaign(c, creating: true), failure);
      }
      expect(await r.getCampaigns(), isEmpty);
    },
  );
  test('Draft campaigns and their needs/images are not public', () async {
    final id = await h.campaign(publish: false);
    await h.need(id);
    h.actor = citizen;
    expect(await r.getCampaigns(), isEmpty);
    await expectLater(r.getCampaign(id), failure);
    await expectLater(r.getMaterialNeeds(id), failure);
    await expectLater(r.getTransparencyReports(id), failure);
  });
  test('Financial simulation pending versus explicit confirmation totals and single receipt', () async {
    final id = await h.campaign();
    h.actor = citizen;
    final x = await r.createFinancialDonation(id, 20);
    expect(x.status, DonationStatus.PENDING);
    expect((await r.getCampaign(id)).collectedAmount, 0);
    expect(await r.getReceiptForDonation(x.id), isNull);
    await r.confirmFinancialDonation(x.id);
    expect((await r.getCampaign(id)).collectedAmount, 20);
    final receipt = (await r.getReceiptForDonation(x.id))!;
    expect(receipt.donorName, citizen.fullName);
    expect(receipt.amount, 20);
    expect(receipt.reference, startsWith('DEMO-RECU-'));
    expect(receipt.filePath, isNull);
    await expectLater(r.confirmFinancialDonation(x.id), failure);
    expect((await r.getReceiptForDonation(x.id))!.id, receipt.id);
    expect((await r.getCampaign(id)).collectedAmount, 20);
  });
  test('Immediate explicit demo confirmation and exact millime totals support multiple legitimate donations', () async {
    final id = await h.campaign();
    h.actor = citizen;
    for (final amount in [0.1, 0.2, 0.001]) {
      await r.createFinancialDonation(id, amount, confirmSimulation: true);
    }
    expect((await r.getCampaign(id)).collectedAmount, 0.301);
    expect((await r.getDonations()).length, 3);
    expect(DonationMoney.format(0.301), '0,301 TND');
  });
  test('Idempotent retry and concurrent same key never count twice different keys remain distinct', () async {
    final id = await h.campaign();
    h.actor = citizen;
    final rows = await Future.wait([
      r.createFinancialDonation(
        id,
        20,
        confirmSimulation: true,
        requestKey: 'same',
      ),
      r.createFinancialDonation(
        id,
        20,
        confirmSimulation: true,
        requestKey: 'same',
      ),
    ]);
    expect(rows[0].id, rows[1].id);
    expect((await r.getCampaign(id)).collectedAmount, 20);
    await r.createFinancialDonation(
      id,
      20,
      confirmSimulation: true,
      requestKey: 'new',
    );
    expect((await r.getCampaign(id)).collectedAmount, 40);
    await expectLater(
      r.createFinancialDonation(id, 30, requestKey: 'same'),
      failure,
    );
  });
  test('Financial validation inactive future expired and closed campaigns prevent contributions', () async {
    final draftId = await h.campaign(publish: false);
    h.actor = citizen;
    await expectLater(r.createFinancialDonation(draftId, 10), failure);
    h.actor = admin;
    final c = await r.saveCampaign(
      h.draft().copyWith(startDate: h.now.add(const Duration(days: 10))),
      creating: true,
    );
    await r.changeCampaignStatus(c.id, CampaignStatus.ACTIVE);
    h.actor = citizen;
    await expectLater(r.createFinancialDonation(c.id, 10), failure);
    h.actor = admin;
    final id = await h.campaign();
    h.actor = citizen;
    for (final value in [0.0, -1.0, double.nan, double.infinity, 0.1234]) {
      await expectLater(r.createFinancialDonation(id, value), failure);
    }
    h.now = h.now.add(const Duration(days: 200));
    await expectLater(r.createFinancialDonation(id, 10), failure);
  });
  test('Pending donation cancellation never counts or generates receipt confirmed cannot be cancelled', () async {
    final id = await h.campaign();
    h.actor = citizen;
    final pending = await r.createFinancialDonation(id, 20);
    await r.cancelDonation(pending.id);
    await expectLater(r.confirmFinancialDonation(pending.id), failure);
    expect(await r.getReceiptForDonation(pending.id), isNull);
    final confirmed = await r.createFinancialDonation(
      id,
      10,
      confirmSimulation: true,
    );
    await expectLater(r.cancelDonation(confirmed.id), failure);
    expect((await r.getCampaign(id)).collectedAmount, 10);
  });
  test('Material pending receipt confirmation counts only linked need and never money', () async {
    final id = await h.campaign(), need = await h.need(id);
    h.actor = citizen;
    await r.createMaterialDonation(
      id,
      MaterialType.FOOD,
      4,
      'Quatre sacs de nourriture en démonstration.',
      needId: need,
    );
    final m = (await r.getMaterialDonations()).single;
    expect(m.status, MaterialDonationStatus.PENDING);
    expect((await r.getMaterialNeeds(id)).single.receivedQuantity, 0);
    expect(await r.getReceiptForDonation(m.donationId), isNull);
    await expectLater(r.receiveMaterialDonation(m.id), failure);
    h.actor = admin;
    await r.receiveMaterialDonation(m.id);
    final n = (await r.getMaterialNeeds(id)).single;
    expect(n.receivedQuantity, 4);
    expect(n.status, MaterialNeedStatus.PARTIALLY_FULFILLED);
    expect((await r.getCampaign(id)).collectedAmount, 0);
    expect((await r.getDonation(m.donationId)).amount, isNull);
    expect(
      (await r.getReceiptForDonation(m.donationId))!.type,
      DonationType.MATERIAL,
    );
    await expectLater(r.receiveMaterialDonation(m.id), failure);
    await expectLater(r.rejectMaterialDonation(m.id), failure);
    expect((await r.getMaterialNeeds(id)).single.receivedQuantity, 4);
  });
  test(
    'Overfulfilled needs retain exact received quantity with FULFILLED status',
    () async {
      final id = await h.campaign(), need = await h.need(id, quantity: 3);
      h.actor = citizen;
      await r.createMaterialDonation(
        id,
        MaterialType.FOOD,
        5,
        'Cinq sacs fictifs pour les animaux.',
        needId: need,
      );
      h.actor = admin;
      await r.receiveMaterialDonation(
        (await r.getMaterialDonations()).single.id,
      );
      final n = (await r.getMaterialNeeds(id)).single;
      expect(n.receivedQuantity, 5);
      expect(n.status, MaterialNeedStatus.FULFILLED);
    },
  );
  test('Material association validates campaign and type free proposals do not invent need fulfilment', () async {
    final id = await h.campaign(),
        need = await h.need(id),
        otherId = await h.campaign();
    h.actor = citizen;
    await expectLater(
      r.createMaterialDonation(
        otherId,
        MaterialType.FOOD,
        1,
        'Proposition de démonstration.',
        needId: need,
      ),
      failure,
    );
    await expectLater(
      r.createMaterialDonation(
        id,
        MaterialType.MEDICINE,
        1,
        'Proposition de démonstration.',
        needId: need,
      ),
      failure,
    );
    await r.createMaterialDonation(
      id,
      MaterialType.FOOD,
      1,
      'Proposition libre sans affectation.',
    );
    h.actor = admin;
    await r.receiveMaterialDonation((await r.getMaterialDonations()).single.id);
    expect((await r.getMaterialNeeds(id)).single.receivedQuantity, 0);
  });
  test(
    'Admin assigns compatible free proposal to one need at receipt',
    () async {
      final id = await h.campaign(), n = await h.need(id);
      h.actor = citizen;
      await r.createMaterialDonation(
        id,
        MaterialType.FOOD,
        3,
        'Trois sacs fictifs en proposition libre.',
      );
      h.actor = admin;
      await r.receiveMaterialDonation(
        (await r.getMaterialDonations()).single.id,
        needId: n,
      );
      expect((await r.getMaterialNeeds(id)).single.receivedQuantity, 3);
    },
  );
  test('Material rejection or donor cancellation never increases quantities and no receipt', () async {
    final id = await h.campaign(), need = await h.need(id);
    h.actor = citizen;
    await r.createMaterialDonation(
      id,
      MaterialType.FOOD,
      2,
      'Deux sacs de nourriture fictifs.',
      needId: need,
    );
    final m = (await r.getMaterialDonations()).single;
    h.actor = admin;
    await r.rejectMaterialDonation(m.id);
    expect(
      (await r.getDonation(m.donationId)).status,
      DonationStatus.CANCELLED,
    );
    expect(await r.getReceiptForDonation(m.donationId), isNull);
    expect((await r.getMaterialNeeds(id)).single.receivedQuantity, 0);
    h.actor = citizen;
    await r.createMaterialDonation(
      id,
      MaterialType.FOOD,
      2,
      'Deux autres sacs de nourriture.',
      needId: need,
    );
    final second = (await r.getMaterialDonations()).first;
    await r.cancelDonation(second.donationId);
    expect(
      (await r.getMaterialForDonation(second.donationId))!.status,
      MaterialDonationStatus.REJECTED,
    );
  });
  test('Material validates integer positive quantity description and idempotent retries', () async {
    final id = await h.campaign();
    h.actor = citizen;
    await expectLater(
      r.createMaterialDonation(
        id,
        MaterialType.FOOD,
        0,
        'Description de démonstration.',
      ),
      failure,
    );
    await expectLater(
      r.createMaterialDonation(id, MaterialType.FOOD, 1, 'x'),
      failure,
    );
    await r.createMaterialDonation(
      id,
      MaterialType.FOOD,
      1,
      'Description de démonstration.',
      requestKey: 'material',
    );
    await r.createMaterialDonation(
      id,
      MaterialType.FOOD,
      1,
      'Description de démonstration.',
      requestKey: 'material',
    );
    expect((await r.getDonations()).length, 1);
    await expectLater(
      r.createFinancialDonation(id, 10, requestKey: 'material'),
      failure,
    );
  });
  test('Need received and status fields cannot be manually forged edits preserve calculated quantities', () async {
    final id = await h.campaign(), need = await h.need(id);
    var n = (await r.getMaterialNeeds(id)).single;
    expect(n.receivedQuantity, 0);
    expect(n.status, MaterialNeedStatus.OPEN);
    await r.saveMaterialNeed(
      n.copyWith(
        receivedQuantity: 999,
        status: MaterialNeedStatus.FULFILLED,
        requestedQuantity: 20,
      ),
      creating: false,
    );
    n = (await r.getMaterialNeeds(id)).single;
    expect(n.receivedQuantity, 0);
    h.actor = citizen;
    await r.createMaterialDonation(
      id,
      MaterialType.FOOD,
      1,
      'Un sac fictif pour les animaux.',
      needId: need,
    );
    h.actor = admin;
    await expectLater(
      r.saveMaterialNeed(
        n.copyWith(itemType: MaterialType.OTHER),
        creating: false,
      ),
      failure,
    );
  });
  test('Recurring creation is plan only no donation even when scheduled date reached', () async {
    final id = await h.campaign();
    h.actor = citizen;
    final next = h.now.add(const Duration(days: 7));
    await r.createRecurringDonation(
      id,
      20,
      DonationFrequency.WEEKLY,
      next,
      requestKey: 'plan',
    );
    await r.createRecurringDonation(
      id,
      20,
      DonationFrequency.WEEKLY,
      next,
      requestKey: 'plan',
    );
    expect((await r.getRecurringDonations()).length, 1);
    expect(await r.getDonations(), isEmpty);
    h.now = next;
    expect(await r.getDonations(), isEmpty);
    expect((await r.getCampaign(id)).collectedAmount, 0);
  });
  test('Due occurrence manual preparation creates only one PENDING then explicit confirmation advances weekly plan', () async {
    final id = await h.campaign();
    h.actor = citizen;
    final due = h.now.add(const Duration(days: 7));
    await r.createRecurringDonation(id, 20, DonationFrequency.WEEKLY, due);
    final plan = (await r.getRecurringDonations()).single;
    await expectLater(r.prepareRecurringOccurrence(plan.id), failure);
    h.now = due;
    final x = await r.prepareRecurringOccurrence(plan.id);
    final again = await r.prepareRecurringOccurrence(plan.id);
    expect(x.id, again.id);
    expect(x.status, DonationStatus.PENDING);
    expect((await r.getCampaign(id)).collectedAmount, 0);
    expect(await r.getReceiptForDonation(x.id), isNull);
    await r.confirmFinancialDonation(x.id);
    expect((await r.getCampaign(id)).collectedAmount, 20);
    expect(
      (await r.getRecurringDonations()).single.nextDonationDate,
      due.add(const Duration(days: 7)),
    );
    await expectLater(r.confirmFinancialDonation(x.id), failure);
  });
  test('Monthly day anchor handles January31 February28 March31', () async {
    h.now = DateTime(2027, 1, 1, 12);
    final id = await h.campaign();
    h.actor = citizen;
    final due = DateTime(2027, 1, 31, 12);
    await r.createRecurringDonation(id, 10, DonationFrequency.MONTHLY, due);
    final plan = (await r.getRecurringDonations()).single;
    h.now = due;
    var x = await r.prepareRecurringOccurrence(plan.id);
    await r.confirmFinancialDonation(x.id);
    expect(
      (await r.getRecurringDonations()).single.nextDonationDate,
      DateTime(2027, 2, 28, 12),
    );
    h.now = DateTime(2027, 2, 28, 12);
    x = await r.prepareRecurringOccurrence(plan.id);
    await r.confirmFinancialDonation(x.id);
    expect(
      (await r.getRecurringDonations()).single.nextDonationDate,
      DateTime(2027, 3, 31, 12),
    );
  });
  test('Late recurring confirmation skips missed dates without creating catch-up donations', () async {
    final id = await h.campaign();
    h.actor = citizen;
    final due = h.now.add(const Duration(days: 1));
    await r.createRecurringDonation(id, 10, DonationFrequency.WEEKLY, due);
    final plan = (await r.getRecurringDonations()).single;
    h.now = due.add(const Duration(days: 30));
    final x = await r.prepareRecurringOccurrence(plan.id);
    await r.confirmFinancialDonation(x.id);
    expect((await r.getDonations()).length, 1);
    expect(
      (await r.getRecurringDonations()).single.nextDonationDate.isAfter(h.now),
      isTrue,
    );
    expect((await r.getCampaign(id)).collectedAmount, 10);
  });
  test('Pause and cancellation cancel pending occurrences resume requires explicit user action', () async {
    final id = await h.campaign();
    h.actor = citizen;
    final due = h.now.add(const Duration(days: 1));
    await r.createRecurringDonation(id, 10, DonationFrequency.WEEKLY, due);
    final plan = (await r.getRecurringDonations()).single;
    h.now = due;
    final x = await r.prepareRecurringOccurrence(plan.id);
    await r.changeRecurringStatus(plan.id, RecurringDonationStatus.PAUSED);
    expect((await r.getDonation(x.id)).status, DonationStatus.CANCELLED);
    await expectLater(r.prepareRecurringOccurrence(plan.id), failure);
    await r.changeRecurringStatus(plan.id, RecurringDonationStatus.ACTIVE);
    final next = await r.prepareRecurringOccurrence(plan.id);
    expect(next.id, isNot(x.id));
    expect(next.status, DonationStatus.PENDING);
    await r.changeRecurringStatus(plan.id, RecurringDonationStatus.CANCELLED);
    await expectLater(
      r.changeRecurringStatus(plan.id, RecurringDonationStatus.ACTIVE),
      failure,
    );
    expect((await r.getCampaign(id)).collectedAmount, 0);
  });
  test('Recurring validation dates amounts and participant isolation admin cannot manage another donor plan', () async {
    final id = await h.campaign();
    h.actor = citizen;
    await expectLater(
      r.createRecurringDonation(
        id,
        0,
        DonationFrequency.MONTHLY,
        h.now.add(const Duration(days: 1)),
      ),
      failure,
    );
    await expectLater(
      r.createRecurringDonation(id, 10, DonationFrequency.MONTHLY, h.now),
      failure,
    );
    await r.createRecurringDonation(
      id,
      10,
      DonationFrequency.MONTHLY,
      h.now.add(const Duration(days: 1)),
    );
    final p = (await r.getRecurringDonations()).single;
    h.actor = other;
    expect(await r.getRecurringDonations(), isEmpty);
    await expectLater(
      r.changeRecurringStatus(p.id, RecurringDonationStatus.CANCELLED),
      failure,
    );
    h.actor = admin;
    await expectLater(
      r.changeRecurringStatus(p.id, RecurringDonationStatus.CANCELLED),
      failure,
    );
  });
  test('Campaign closure atomically cancels pending/material/recurring but preserves confirmed totals and receipts', () async {
    final id = await h.campaign(), need = await h.need(id);
    h.actor = citizen;
    final confirmed = await r.createFinancialDonation(
      id,
      10,
      confirmSimulation: true,
    );
    final pending = await r.createFinancialDonation(id, 20);
    await r.createMaterialDonation(
      id,
      MaterialType.FOOD,
      2,
      'Deux sacs fictifs en attente.',
      needId: need,
    );
    await r.createRecurringDonation(
      id,
      10,
      DonationFrequency.MONTHLY,
      h.now.add(const Duration(days: 1)),
    );
    h.actor = admin;
    await r.changeCampaignStatus(id, CampaignStatus.COMPLETED);
    expect((await r.getDonation(pending.id)).status, DonationStatus.CANCELLED);
    expect(
      (await r.getMaterialDonations()).single.status,
      MaterialDonationStatus.REJECTED,
    );
    expect(
      (await r.getRecurringDonations()).single.status,
      RecurringDonationStatus.CANCELLED,
    );
    expect((await r.getCampaign(id)).collectedAmount, 10);
    expect(await r.getReceiptForDonation(confirmed.id), isNotNull);
    await expectLater(r.createFinancialDonation(id, 10), failure);
    await expectLater(
      r.receiveMaterialDonation((await r.getMaterialDonations()).single.id),
      failure,
    );
    await expectLater(
      r.changeCampaignStatus(id, CampaignStatus.ACTIVE),
      failure,
    );
  });
  test('Campaign period locked once contributions or recurring plans exist titles editable and receipts retain snapshot', () async {
    final id = await h.campaign();
    h.actor = citizen;
    final x = await r.createFinancialDonation(id, 10, confirmSimulation: true);
    h.actor = admin;
    final c = await r.getCampaign(id);
    await expectLater(
      r.saveCampaign(
        c.copyWith(endDate: c.endDate.add(const Duration(days: 1))),
        creating: false,
      ),
      failure,
    );
    await r.saveCampaign(
      c.copyWith(title: 'Titre de campagne modifié'),
      creating: false,
    );
    expect((await r.getReceiptForDonation(x.id))!.campaignTitle, c.title);
    expect((await r.getCampaign(id)).collectedAmount, 10);
  });
  test('Transparency captures computed totals and received material at publication no invented spending', () async {
    final id = await h.campaign();
    h.actor = citizen;
    await r.createFinancialDonation(id, 20, confirmSimulation: true);
    await r.createFinancialDonation(id, 100);
    await r.createMaterialDonation(
      id,
      MaterialType.FOOD,
      2,
      'Deux sacs fictifs réceptionnés.',
    );
    h.actor = admin;
    await r.receiveMaterialDonation((await r.getMaterialDonations()).single.id);
    await r.publishTransparencyReport(
      id,
      'Point de transparence local',
      'Aucune dépense ni pièce justificative n’a été déclarée dans cette démonstration.',
    );
    h.actor = other;
    final report = (await r.getTransparencyReports(id)).single;
    expect(report.financialTotal, 20);
    expect(report.receivedMaterialCount, 1);
    expect(report.receivedMaterialSummary, contains('Nourriture : 2'));
    await r.createFinancialDonation(id, 5, confirmSimulation: true);
    expect((await r.getTransparencyReports(id)).single.financialTotal, 20);
    expect((await r.getCampaign(id)).collectedAmount, 25);
    await expectLater(
      r.publishTransparencyReport(
        id,
        'Description valide de rapport',
        'Contenu déclaré suffisamment long pour le rapport.',
      ),
      failure,
    );
  });
  test('Donation details materials receipts and recurring private to owner or admin', () async {
    final id = await h.campaign();
    h.actor = citizen;
    final x = await r.createFinancialDonation(id, 10, confirmSimulation: true);
    final receipt = (await r.getReceiptForDonation(x.id))!;
    h.actor = other;
    expect(await r.getDonations(), isEmpty);
    expect(await r.getMaterialDonations(), isEmpty);
    await expectLater(r.getDonation(x.id), failure);
    await expectLater(r.getReceipt(receipt.id), failure);
    await expectLater(r.confirmFinancialDonation(x.id), failure);
    h.actor = admin;
    expect((await r.getReceipt(receipt.id)).donorName, citizen.fullName);
  });
  test('Snapshot reload preserves receipts plans and calculated totals; failed write rolls back receipt and aggregate', () async {
    final id = await h.campaign();
    h.actor = citizen;
    await r.createFinancialDonation(id, 10, confirmSimulation: true);
    final db = DonationsDatabase(h.storage);
    final next = LocalDonationRepository(db, () => h.actor, clock: () => h.now);
    expect((await next.getCampaign(id)).collectedAmount, 10);
    expect((await next.getDonations()).length, 1);
    db.dispose();
    h.storage.fail = true;
    await expectLater(
      r.createFinancialDonation(id, 20, confirmSimulation: true),
      throwsStateError,
    );
    expect((await r.getCampaign(id)).collectedAmount, 10);
    expect((await r.getDonations()).length, 1);
  });
  test(
    'Concurrent double material confirmation has one winner and one receipt',
    () async {
      final id = await h.campaign(), need = await h.need(id);
      h.actor = citizen;
      await r.createMaterialDonation(
        id,
        MaterialType.FOOD,
        3,
        'Trois sacs fictifs pour les animaux.',
        needId: need,
      );
      h.actor = admin;
      final m = (await r.getMaterialDonations()).single;
      final results = await Future.wait([
        r
            .receiveMaterialDonation(m.id)
            .then((_) => true, onError: (Object e) => false),
        r
            .receiveMaterialDonation(m.id)
            .then((_) => true, onError: (Object e) => false),
      ]);
      expect(results.where((v) => v).length, 1);
      expect((await r.getMaterialNeeds(id)).single.receivedQuantity, 3);
      expect((await h.db.read((d) => d.receipts.length)), 1);
    },
  );
  test('No session suspended or pending accounts denied; queued identity change cannot create contribution', () async {
    final id = await h.campaign();
    h.actor = citizen;
    final pending = r.createFinancialDonation(id, 10, confirmSimulation: true);
    h.actor = other;
    await expectLater(pending, failure);
    for (final u in [
      null,
      citizen.copyWith(status: AccountStatus.blocked),
      citizen.copyWith(status: AccountStatus.pending),
    ]) {
      h.actor = u;
      await expectLater(r.getCampaigns(), failure);
      await expectLater(r.createFinancialDonation(id, 10), failure);
    }
  });
  test('Campaign media authorization survives delayed account switch and no corrupt snapshot reset', () async {
    final c = await r.saveCampaign(
      h.draft(),
      creating: true,
      imageBytes: Uint8List.fromList([1, 2, 3]),
    );
    h.storage.photoGate = Completer<void>();
    final reading = r.readCampaignImage(c.id);
    await Future<void>.delayed(Duration.zero);
    h.actor = citizen;
    final check = expectLater(reading, failure);
    h.storage.photoGate!.complete();
    await check;
    final storage = MemoryReportsStorage()..value = '{"version":99}';
    final db = DonationsDatabase(storage);
    await expectLater(db.read((d) => d.nextId), throwsFormatException);
    expect(storage.value, '{"version":99}');
    db.dispose();
  });
}
