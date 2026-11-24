import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/donations/models/donation_campaign.dart';
import 'package:animora/features/donations/models/material_need.dart';
import 'package:animora/features/donations/widgets/donation_widgets.dart';

import 'support/auth_test_support.dart';
import 'widget_test.dart' show mountApp;
import 'services_widget_test.dart' show flush, tapAction;

DonationsStore store(WidgetTester t) =>
    t.element(find.byType(DonationsPage).first).read<DonationsStore>();
Future<int> seedCampaign(WidgetTester t, DonationsStore s) async {
  final now = DateTime.now();
  final campaign = (await t.runAsync(
    () => s.campaigns.saveCampaign(
      DonationCampaign(
        id: 0,
        title: 'Campagne fictive de nourriture',
        description: 'Collecte locale de démonstration pour nourrir les animaux et suivre les contributions.',
        targetAmount: 100,
        collectedAmount: 999,
        startDate: now.subtract(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 90)),
        status: CampaignStatus.DRAFT,
      ),
      creating: true,
    ),
  ))!;
  await t.runAsync(
    () => s.campaigns.changeCampaignStatus(campaign.id, CampaignStatus.ACTIVE),
  );
  await flush(t);
  return campaign.id;
}

Future<void> confirm(WidgetTester t) =>
    tapAction(t, find.widgetWithText(FilledButton, 'Confirmer'));
void main() {
  setUpAll(seedDatabase);
  testWidgets(
    'Admin creates and publishes campaign public catalogue finds it and hides drafts',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'admin',
        path: '/admin/donations/campaigns/new',
      );
      await flush(tester);
      final s = store(tester);
      await tester.enterText(
        find.byType(TextField).at(0),
        'Campagne locale pour les animaux',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'Une campagne de démonstration pour soutenir les besoins alimentaires des animaux.',
      );
      await tester.enterText(find.byType(TextField).at(2), '100');
      await tapAction(tester, find.text('Enregistrer le brouillon'));
      await flush(tester);
      expect(find.text('Brouillon'), findsOneWidget);
      await tapAction(tester, find.text('Publier la campagne'));
      await confirm(tester);
      await flush(tester);
      expect(find.text('Active'), findsOneWidget);
      final now = DateTime.now();
      await tester.runAsync(
        () => s.campaigns.saveCampaign(
          DonationCampaign(
            id: 0,
            title: 'Brouillon privé non publié',
            description:
                'Description de campagne encore privée de démonstration.',
            targetAmount: 50,
            collectedAmount: 0,
            startDate: now,
            endDate: now.add(const Duration(days: 30)),
            status: CampaignStatus.DRAFT,
          ),
          creating: true,
        ),
      );
      await tester.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      router.go('/donations');
      await flush(tester);
      expect(find.text('Campagne locale pour les animaux'), findsOneWidget);
      expect(find.text('Brouillon privé non publié'), findsNothing);
      await tester.enterText(find.byType(TextField), 'introuvable');
      await flush(tester);
      expect(
        find.textContaining('Aucune campagne pour ces critères.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Invalid campaign form stays editable and does not create data', (
    tester,
  ) async {
    await mountApp(
      tester,
      account: 'admin',
      path: '/admin/donations/campaigns/new',
    );
    await flush(tester);
    final s = store(tester);
    await tapAction(tester, find.text('Enregistrer le brouillon'));
    await flush(tester);
    expect((await tester.runAsync(() => s.campaigns.getCampaigns()))!, isEmpty);
    expect(
      find.textContaining('Saisissez un objectif numérique.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'Financial confirmation produces demo receipt and correct public total no other donors history',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'admin',
        path: '/admin/donations',
      );
      await flush(tester);
      final s = store(tester);
      final id = await seedCampaign(tester, s);
      await tester.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      router.go('/donations/financial/$id');
      await flush(tester);
      expect(find.text(donationNotice), findsOneWidget);
      await tester.enterText(find.byType(TextField), '20,125');
      await tapAction(tester, find.text('Confirmer la simulation'));
      await confirm(tester);
      await flush(tester);
      expect(find.text('20,125 TND'), findsOneWidget);
      await tapAction(tester, find.text('Consulter mon don'));
      await flush(tester);
      await tapAction(tester, find.text('Consulter le reçu de démonstration'));
      await flush(tester);
      expect(find.text(receiptNotice), findsOneWidget);
      expect(
        find.text('Exporter le reçu PDF de démonstration'),
        findsOneWidget,
      );
      expect(
        (await tester.runAsync(() => s.campaigns.getCampaign(id)))!
            .collectedAmount,
        20.125,
      );
      await tester.runAsync(
        () => session.login('foster@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      expect(find.text(receiptNotice), findsNothing);
      expect(find.text('Ce don est privé ou introuvable.'), findsOneWidget);
      router.go('/donations/my');
      await flush(tester);
      expect(
        find.text('Vous n’avez pas encore de contribution.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Material proposal pending admin receives exactly once and need increases only then',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'admin',
        path: '/admin/donations',
      );
      await flush(tester);
      final s = store(tester);
      final id = await seedCampaign(tester, s);
      await tester.runAsync(
        () => s.needs.saveMaterialNeed(
          MaterialNeed(
            id: 0,
            campaignId: id,
            description: 'Sacs de croquettes de démonstration',
            requestedQuantity: 10,
            receivedQuantity: 0,
            status: MaterialNeedStatus.OPEN,
            itemType: MaterialType.FOOD,
          ),
          creating: true,
        ),
      );
      await tester.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      router.go('/donations/material/$id');
      await flush(tester);
      await tapAction(tester, find.byType(DropdownButtonFormField<int>));
      await tapAction(
        tester,
        find.text('Sacs de croquettes de démonstration').last,
      );
      await tester.enterText(find.byType(TextField).at(0), '4');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Quatre sacs de nourriture fictifs pour les animaux.',
      );
      await tapAction(tester, find.text('Soumettre la proposition'));
      await confirm(tester);
      await flush(tester);
      expect(
        (await tester.runAsync(() => s.needs.getMaterialNeeds(id)))!
            .single
            .receivedQuantity,
        0,
      );
      await tester.runAsync(
        () => session.login('admin@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      router.go('/admin/donations/material');
      await flush(tester);
      await tapAction(tester, find.text('Confirmer la réception'));
      await flush(tester);
      await tapAction(tester, find.text('Matériel réceptionné'));
      await flush(tester);
      expect(
        (await tester.runAsync(() => s.needs.getMaterialNeeds(id)))!
            .single
            .receivedQuantity,
        4,
      );
      expect(
        (await tester.runAsync(() => s.campaigns.getCampaign(id)))!
            .collectedAmount,
        0,
      );
      expect(find.text('Confirmer la réception'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Recurring form creates plan only can pause and cancel without recorded donation',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'admin',
        path: '/admin/donations',
      );
      await flush(tester);
      final s = store(tester);
      final id = await seedCampaign(tester, s);
      await tester.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      router.go('/donations/financial/$id');
      await flush(tester);
      await tapAction(tester, find.text('Programme récurrent simulé'));
      await tapAction(tester, find.text('Créer le programme simulé'));
      await confirm(tester);
      await flush(tester);
      expect(find.text('Actif'), findsOneWidget);
      expect(
        (await tester.runAsync(() => s.donations.getDonations()))!,
        isEmpty,
      );
      await tapAction(tester, find.text('Suspendre'));
      await confirm(tester);
      await flush(tester);
      expect(find.text('Suspendu'), findsOneWidget);
      await tapAction(tester, find.text('Annuler le programme'));
      await confirm(tester);
      await flush(tester);
      expect(find.text('Annulé'), findsOneWidget);
      expect(
        (await tester.runAsync(() => s.donations.getDonations()))!,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Due recurrence prepares pending contribution and still requires explicit confirmation',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'admin',
        path: '/admin/donations',
      );
      await flush(tester);
      final s = store(tester);
      final id = await seedCampaign(tester, s);
      await tester.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      await tester.runAsync(
        () => s.recurring.createRecurringDonation(
          id,
          10,
          DonationFrequency.WEEKLY,
          DateTime.now().add(const Duration(days: 1)),
        ),
      );
      final plan = (await tester.runAsync(
        () => s.recurring.getRecurringDonations(),
      ))!.single;
      await tester.runAsync(
        () => s.database.mutate((d) {
          d.recurring[plan.id] = plan.copyWith(
            nextDonationDate: DateTime.now().subtract(
              const Duration(minutes: 1),
            ),
          );
        }),
      );
      router.go('/donations/recurring');
      await flush(tester);
      await tapAction(tester, find.text('Préparer cette occurrence'));
      await confirm(tester);
      await flush(tester);
      expect(
        (await tester.runAsync(() => s.donations.getDonations()))!
            .single
            .status,
        DonationStatus.PENDING,
      );
      expect(
        (await tester.runAsync(() => s.campaigns.getCampaign(id)))!
            .collectedAmount,
        0,
      );
      await tapAction(tester, find.text('Confirmer cette simulation'));
      await confirm(tester);
      await flush(tester);
      expect(
        (await tester.runAsync(() => s.campaigns.getCampaign(id)))!
            .collectedAmount,
        10,
      );
      expect(find.text('Consulter le reçu de démonstration'), findsOneWidget);
    },
  );
  testWidgets(
    'Admin publishes declared report and user sees calculated publication snapshot',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'admin',
        path: '/admin/donations',
      );
      await flush(tester);
      final s = store(tester);
      final id = await seedCampaign(tester, s);
      router.go('/admin/donations/reports?campaignId=$id');
      await flush(tester);
      await tester.enterText(
        find.byType(TextField).at(0),
        'Premier rapport de démonstration',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'Aucune dépense n’a encore été déclarée dans cette démonstration locale.',
      );
      await tapAction(tester, find.text('Publier le rapport'));
      await confirm(tester);
      await flush(tester);
      await tester.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      router.go('/donations/campaigns/$id');
      await flush(tester);
      expect(find.text('Premier rapport de démonstration'), findsOneWidget);
      expect(
        find.text(
          'Aucune dépense n’a encore été déclarée dans cette démonstration locale.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final path in [
    '/admin/donations',
    '/admin/donations/campaigns',
    '/admin/donations/campaigns/new',
    '/admin/donations/material',
    '/admin/donations/reports',
  ]) {
    testWidgets('Donation admin route protected $path', (tester) async {
      final (_, router) = await mountApp(
        tester,
        account: 'citizen',
        path: path,
      );
      await flush(tester);
      expect(router.routeInformationProvider.value.uri.path, '/access-denied');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Campaign details forms and admin dashboard fit narrow layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (session, router) = await mountApp(
      tester,
      account: 'admin',
      path: '/admin/donations',
    );
    await flush(tester);
    final s = store(tester);
    final id = await seedCampaign(tester, s);
    for (final path in [
      '/admin/donations',
      '/admin/donations/campaigns',
      '/admin/donations/campaigns/new',
      '/admin/donations/reports?campaignId=$id',
    ]) {
      router.go(path);
      await flush(tester);
      expect(tester.takeException(), isNull);
    }
    await tester.runAsync(
      () => session.login('citizen@animora.test', DemoAccounts.password),
    );
    await flush(tester);
    for (final path in [
      '/donations',
      '/donations/campaigns/$id',
      '/donations/financial/$id',
      '/donations/material/$id',
      '/donations/my',
      '/donations/recurring',
    ]) {
      router.go(path);
      await flush(tester);
      expect(tester.takeException(), isNull);
    }
  });
}
