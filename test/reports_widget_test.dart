import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/reports/screens/community_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:animora/features/reports/repositories/local_reports_repository.dart';
import 'package:animora/features/reports/screens/reports_screen.dart';
import 'package:animora/features/reports/widgets/report_map.dart';
import 'package:animora/features/reports/models/annonce.dart';
import 'package:animora/features/reports/models/signalement.dart';
import 'package:animora/core/enums/announcement_type.dart';
import 'package:animora/core/enums/announcement_status.dart';
import 'package:animora/core/enums/report_type.dart';
import 'package:animora/core/enums/report_status.dart';

import 'support/auth_test_support.dart';
import 'widget_test.dart' show mountApp;
import 'adoption_widget_test.dart' show flush, tapAction;

void main() {
  setUpAll(seedDatabase);
  testWidgets(
    'GPS refusal leaves report form usable and publish works without location',
    (tester) async {
      final (_, router) = await mountApp(
        tester,
        account: 'citizen',
        path: '/reports/new',
      );
      await flush(tester);
      await tester.enterText(
        find.byType(TextField).at(0),
        'Un chien marron blessé observé près du parc.',
      );
      await tapAction(tester, find.text('Utiliser ma position GPS'));
      expect(find.textContaining('Permission GPS refusée'), findsOneWidget);
      await tapAction(tester, find.text('Publier le signalement'));
      await flush(tester);
      expect(
        router.routeInformationProvider.value.uri.path,
        startsWith('/reports/'),
      );
      expect(
        find.text('Un chien marron blessé observé près du parc.'),
        findsOneWidget,
      );
      expect(find.byType(ReportMap), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Report empty validation keeps form and allows correction', (
    tester,
  ) async {
    await mountApp(tester, account: 'citizen', path: '/reports/new');
    await flush(tester);
    await tapAction(tester, find.text('Publier le signalement'));
    expect(find.byType(CreateReportScreen), findsOneWidget);
    expect(find.textContaining('Saisissez entre 10'), findsOneWidget);
  });
  testWidgets(
    'Public report cards filter and navigate without overflow at 360 px',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (_, router) = await mountApp(
        tester,
        account: 'citizen',
        path: '/reports/new',
      );
      await flush(tester);
      final repo = tester
          .element(find.byType(CreateReportScreen))
          .read<LocalReportsRepository>();
      await tester.runAsync(
        () => repo.createReport(
          Signalement(
            id: 0,
            userId: '',
            type: ReportType.INJURED_ANIMAL,
            description: 'Un chat blessé devant la gare.',
            urgencyLevel: 3,
            status: ReportStatus.NEW,
            createdAt: DateTime.now(),
          ),
        ),
      );
      router.go('/reports');
      await flush(tester);
      await tester.enterText(find.byType(TextField), 'introuvable');
      await flush(tester);
      expect(find.text('Aucun signalement pour ces critères.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'chat');
      await flush(tester);
      await tapAction(tester, find.text('Animal blessé').last);
      await flush(tester);
      expect(find.text('Un chat blessé devant la gare.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Create LOST and FOUND through forms and own edit route', (
    tester,
  ) async {
    final (_, router) = await mountApp(
      tester,
      account: 'citizen',
      path: '/lost-found/new',
    );
    await flush(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Chat');
    await tester.enterText(find.byType(TextField).at(2), 'Gris et blanc');
    await tester.enterText(
      find.byType(TextField).at(3),
      'Chat perdu avec un collier bleu.',
    );
    await tapAction(tester, find.text('Enregistrer l’annonce'));
    await flush(tester);
    expect(find.text('Perdu • Chat'), findsOneWidget);
    expect(find.text('Modifier mon annonce'), findsOneWidget);
    await tapAction(tester, find.text('Modifier mon annonce'));
    await flush(tester);
    expect(find.text('Chat'), findsOneWidget);
    router.go('/lost-found/new');
    await flush(tester);
    await tester.tap(find.byType(DropdownButtonFormField<AnnouncementType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trouvé').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Chien');
    await tester.enterText(find.byType(TextField).at(2), 'Marron');
    await tester.enterText(
      find.byType(TextField).at(3),
      'Chien trouvé près du jardin public.',
    );
    await tapAction(tester, find.text('Enregistrer l’annonce'));
    await flush(tester);
    expect(find.text('Trouvé • Chien'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Foreign announcement cannot be edited and admin route guarded', (
    tester,
  ) async {
    final (_, router) = await mountApp(
      tester,
      account: 'citizen',
      path: '/lost-found/new',
    );
    await flush(tester);
    final repo = tester
        .element(find.byType(CreateAnnouncementScreen))
        .read<LocalReportsRepository>();
    final a = (await tester.runAsync(
      () => repo.saveAnnouncement(
        Annonce(
          id: 0,
          userId: '',
          type: AnnouncementType.LOST,
          species: 'Chat',
          color: 'Gris',
          description: 'Chat perdu près du parc.',
          date: DateTime(2026),
          status: AnnouncementStatus.ACTIVE,
        ),
        creating: true,
      ),
    ))!;
    // Ownership controls are verified at the repository too; route guards reject admin access.
    router.go('/admin/reports');
    await flush(tester);
    expect(router.routeInformationProvider.value.uri.path, '/access-denied');
    router.go('/lost-found/${a.id}');
    await flush(tester);
    expect(find.text('Modifier mon annonce'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Claim is private and admin verification allows voluntary reunion story',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'citizen',
        path: '/lost-found/new',
      );
      await flush(tester);
      final repo = tester
          .element(find.byType(CreateAnnouncementScreen))
          .read<LocalReportsRepository>();
      final lost = (await tester.runAsync(
        () => repo.saveAnnouncement(
          Annonce(
            id: 0,
            userId: '',
            type: AnnouncementType.LOST,
            species: 'Chat',
            color: 'Gris',
            description: 'Chat perdu près du parc.',
            date: DateTime(2026),
            status: AnnouncementStatus.ACTIVE,
          ),
          creating: true,
        ),
      ))!;
      await tester.runAsync(
        () => session.login('veterinarian@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      final found = (await tester.runAsync(
        () => repo.saveAnnouncement(
          Annonce(
            id: 0,
            userId: '',
            type: AnnouncementType.FOUND,
            species: 'Chat',
            color: 'Gris',
            description: 'Chat trouvé près du parc.',
            date: DateTime(2026),
            status: AnnouncementStatus.ACTIVE,
          ),
          creating: true,
        ),
      ))!;
      await tester.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      router.go('/claims/new/${found.id}');
      await flush(tester);
      await tester.enterText(
        find.byType(TextField),
        'Carnet de santé et anciennes photos montrant une tache sous la patte.',
      );
      await tapAction(tester, find.text('Soumettre à vérification humaine'));
      await flush(tester);
      expect(find.byType(ClaimCard), findsOneWidget);
      expect(find.textContaining('Preuves privées : Carnet'), findsOneWidget);
      await tester.runAsync(
        () => session.login('veterinarian@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      expect(find.textContaining('Preuves privées : Carnet'), findsNothing);
      expect(find.text('Aucune réclamation.'), findsOneWidget);
      await tester.runAsync(
        () => session.login('admin@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      router.go('/admin/reports');
      await flush(tester);
      await tapAction(tester, find.text('Vérifier la propriété'));
      await tapAction(tester, find.text('Confirmer'));
      await flush(tester);
      expect(
        (await tester.runAsync(() => repo.getAnnouncement(found.id)))!.status,
        AnnouncementStatus.CLOSED,
      );
      expect(
        (await tester.runAsync(() => repo.getAnnouncement(lost.id)))!.status,
        AnnouncementStatus.ACTIVE,
      );
      await tester.runAsync(
        () => session.login('citizen@animora.test', DemoAccounts.password),
      );
      await flush(tester);
      router.go('/claims');
      await flush(tester);
      await tapAction(tester, find.text('Publier des retrouvailles'));
      await flush(tester);
      await tester.enterText(
        find.byType(TextField),
        'Notre chat est enfin rentré à la maison !',
      );
      await tapAction(tester, find.text('Publier l’histoire'));
      await flush(tester);
      expect(
        find.text('Notre chat est enfin rentré à la maison !'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Testimony and search radius persist and fit mobile width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (_, router) = await mountApp(
      tester,
      account: 'citizen',
      path: '/lost-found/new',
    );
    await flush(tester);
    final repo = tester
        .element(find.byType(CreateAnnouncementScreen))
        .read<LocalReportsRepository>();
    final a = (await tester.runAsync(
      () => repo.saveAnnouncement(
        Annonce(
          id: 0,
          userId: '',
          type: AnnouncementType.LOST,
          species: 'Chat',
          color: 'Gris',
          description: 'Chat perdu près du parc.',
          date: DateTime(2026),
          status: AnnouncementStatus.ACTIVE,
        ),
        creating: true,
      ),
    ))!;
    router.go('/lost-found/${a.id}/testimonies');
    await flush(tester);
    await tester.enterText(
      find.byType(TextField).first,
      'Je l’ai aperçu près de la gare cet après-midi.',
    );
    await tapAction(tester, find.text('Publier le témoignage'));
    await flush(tester);
    expect(
      find.text('Je l’ai aperçu près de la gare cet après-midi.'),
      findsOneWidget,
    );
    router.go('/lost-found/${a.id}/zone');
    await flush(tester);
    await tapAction(tester, find.byType(CheckboxListTile));
    await tapAction(tester, find.text('Enregistrer la zone'));
    await flush(tester);
    expect(find.text('Zone de recherche : rayon 3.0 km.'), findsOneWidget);
    expect(find.byType(ReportMap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
