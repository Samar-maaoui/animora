import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:animora/features/adoption/state/adoption_store.dart';
import 'package:animora/features/adoption/screens/animal_details_screen.dart';
import 'package:animora/features/adoption/widgets/animal_photo.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';

import 'support/auth_test_support.dart';
import 'widget_test.dart' show mountApp;

Future<void> flush(WidgetTester tester) async {
  // Advance both widget frames and repository futures, including nested views.
  for (var i = 0; i < 5; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pumpAndSettle();
}

Future<void> tapAction(WidgetTester tester, Finder target) async {
  tester.testTextInput.hide();
  FocusManager.instance.primaryFocus?.unfocus();
  await flush(tester);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(target);
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });
  await flush(tester);
}

Future<void> selectFilter(WidgetTester tester, String key, String value) async {
  tester.testTextInput.hide();
  FocusManager.instance.primaryFocus?.unfocus();
  await flush(tester);
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(seedDatabase);
  testWidgets('Catalogue shows photos and searchable cards opening details', (
    tester,
  ) async {
    await mountApp(tester, account: 'citizen', path: '/animals');
    await tester.enterText(find.byKey(const ValueKey('animal-search')), 'mAx');
    await tester.pumpAndSettle();
    expect(find.text('1 animal(aux)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Max'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnimalPhoto), findsWidgets);
    await tester.tap(find.text('Max'));
    await tester.pumpAndSettle();
    expect(find.byType(AnimalDetailsScreen), findsOneWidget);
    expect(find.text('Golden retriever'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Combined catalog filters show an empty state and can be reset', (
    tester,
  ) async {
    await mountApp(tester, account: 'citizen', path: '/animals');
    await tester.enterText(find.byKey(const ValueKey('animal-search')), 'Luna');
    await selectFilter(tester, 'Espèce-0', 'Chat');
    await selectFilter(tester, 'Race-0', 'Européen');
    await selectFilter(tester, 'Âge-0', '2 à 7 ans');
    await selectFilter(tester, 'Ville-0', 'Tunis');
    await selectFilter(tester, 'Statut-0', 'À adopter');
    expect(find.text('1 animal(aux)'), findsOneWidget);
    await selectFilter(tester, 'Ville-0', 'Sfax');
    expect(find.text('Aucun animal'), findsOneWidget);
    await tapAction(tester, find.text('Réinitialiser les filtres'));
    expect(find.text('8 animal(aux)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Favorite state stays synchronized in details, catalog and favorites',
    (tester) async {
      final (_, router) = await mountApp(
        tester,
        account: 'citizen',
        path: '/animals/1',
      );
      await tapAction(tester, find.byKey(const ValueKey('favorite-1')));
      expect(find.byTooltip('Retirer des favoris'), findsOneWidget);
      router.go('/favorites');
      await flush(tester);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.byTooltip('Retirer des favoris'), findsOneWidget);
      await tapAction(tester, find.byKey(const ValueKey('favorite-1')));
      expect(find.text('Aucun favori'), findsOneWidget);
      router.go('/animals/1');
      await flush(tester);
      expect(find.byTooltip('Ajouter aux favoris'), findsOneWidget);
    },
  );
  testWidgets(
    'Favorite UI does not expose the previous account after account switching',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'citizen',
        path: '/animals/1',
      );
      await tapAction(tester, find.byKey(const ValueKey('favorite-1')));
      await tester.runAsync(() async {
        await session.logout();
        await session.login('veterinarian@animora.test', DemoAccounts.password);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      router.go('/favorites');
      await flush(tester);
      expect(find.text('Aucun favori'), findsOneWidget);
      expect(find.text('Luna'), findsNothing);
      await tester.runAsync(() async {
        await session.logout();
        await session.login('citizen@animora.test', DemoAccounts.password);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      router.go('/favorites');
      await flush(tester);
      expect(find.text('Luna'), findsOneWidget);
    },
  );
  testWidgets(
    'Adoption entry is available only for available animals, missing IDs are handled',
    (tester) async {
      final (_, router) = await mountApp(
        tester,
        account: 'citizen',
        path: '/animals/1',
      );
      await tester.scrollUntilVisible(
        find.text('Demander une adoption'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tapAction(tester, find.text('Demander une adoption'));
      expect(find.text('Questionnaire d’adoption'), findsOneWidget);
      router.go('/animals/6');
      await flush(tester);
      expect(find.text('Demander une adoption'), findsNothing);
      router.go('/animals/999');
      await flush(tester);
      expect(find.text('Animal introuvable'), findsOneWidget);
    },
  );
  for (final route in [
    '/admin/animals',
    '/admin/animals/new',
    '/admin/animals/1/edit',
  ]) {
    testWidgets('Citizen cannot access $route directly', (tester) async {
      final (_, router) = await mountApp(
        tester,
        account: 'citizen',
        path: route,
      );
      expect(router.routeInformationProvider.value.uri.path, '/access-denied');
      expect(find.text('Accès refusé'), findsWidgets);
    });
  }
  testWidgets('Admin animal form validates before saving', (tester) async {
    await mountApp(tester, account: 'admin', path: '/admin/animals/new');
    await tester.scrollUntilVisible(
      find.text('Enregistrer l’animal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapAction(tester, find.text('Enregistrer l’animal'));
    expect(find.text('Choisissez un statut.'), findsOneWidget);
    expect(find.text('Saisissez un entier entre 0 et 200.'), findsOneWidget);
    expect(
      find.text('Saisissez un poids positif (maximum 10 000 kg).'),
      findsOneWidget,
    );
  });
  testWidgets(
    'Admin edits an animal and confirms deletion; cancel preserves it',
    (tester) async {
      final (_, router) = await mountApp(
        tester,
        account: 'admin',
        path: '/admin/animals/1/edit',
      );
      await tester.enterText(
        find.byKey(const ValueKey('animal-name')),
        'Luna modifiée',
      );
      await tester.scrollUntilVisible(
        find.text('Enregistrer l’animal'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tapAction(tester, find.text('Enregistrer l’animal'));
      expect(find.text('Gestion des animaux'), findsOneWidget);
      expect(find.text('Luna modifiée'), findsOneWidget);
      await tapAction(tester, find.byKey(const ValueKey('delete-animal-1')));
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Luna modifiée'), findsOneWidget);
      await tapAction(tester, find.byKey(const ValueKey('delete-animal-1')));
      await tapAction(tester, find.widgetWithText(FilledButton, 'Supprimer'));
      expect(find.text('Luna modifiée'), findsNothing);
      router.go('/animals/1');
      await flush(tester);
      expect(find.text('Animal introuvable'), findsOneWidget);
    },
  );
  testWidgets('Narrow catalog and details render without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (_, router) = await mountApp(
      tester,
      account: 'citizen',
      path: '/animals',
    );
    expect(tester.takeException(), isNull);
    router.go('/animals/1');
    await flush(tester);
    expect(tester.takeException(), isNull);
    final store = tester
        .element(find.byType(AnimalDetailsScreen))
        .read<AdoptionStore>();
    expect(store.animals.length, 8);
  });
}
