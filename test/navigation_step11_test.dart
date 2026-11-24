import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:animora/core/widgets/guarded_form.dart';
import 'package:animora/core/widgets/navigation_app_bar.dart';

import 'widget_test.dart' show mountApp;

void main() {
  testWidgets('System back from a deep link uses the module fallback', (
    t,
  ) async {
    final (_, router) = await mountApp(
      t,
      account: 'citizen',
      path: '/adoptions/my',
    );
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/adoptions');
  });
  testWidgets('Secondary back respects an existing pushed history', (t) async {
    final (_, router) = await mountApp(t, account: 'citizen', path: '/reports');
    router.push('/reports/1');
    await t.pumpAndSettle();
    expect(router.canPop(), true);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/reports');
  });
  const labels = ['Accueil', 'Animaux', 'Favoris', 'Notifications', 'Profil'];
  testWidgets(
    'Five destinations retain original order and notifications behavior',
    (t) async {
      final (_, router) = await mountApp(t, account: 'citizen', path: '/home');
      expect(
        t
            .widgetList<NavigationDestination>(
              find.byType(NavigationDestination),
            )
            .map((w) => w.label)
            .toList(),
        labels,
      );
      for (final (index, path) in [
        '/home',
        '/animals',
        '/favorites',
        '/notifications',
        '/profile',
      ].indexed) {
        await t.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(labels[index]),
          ),
        );
        await t.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, path);
        expect(
          t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          index,
        );
        expect(find.byType(NavigationBar), findsOneWidget);
      }
    },
  );
  testWidgets('Animal search survives switching to notifications and back', (
    t,
  ) async {
    await mountApp(t, account: 'citizen', path: '/animals');
    await t.enterText(find.byKey(const ValueKey('animal-search')), 'Luna');
    await t.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Notifications'),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Animaux'),
      ),
    );
    await t.pumpAndSettle();
    expect(
      t
          .widget<TextField>(find.byKey(const ValueKey('animal-search')))
          .controller!
          .text,
      'Luna',
    );
  });
  for (final route in [
    '/adoptions/my',
    '/reports',
    '/veterinary/my-appointments',
    '/pet-sitting/my-requests',
    '/donations/my',
    '/events/my',
    '/profile/edit',
  ]) {
    testWidgets('Persistent single bar and deep link back on $route', (
      t,
    ) async {
      final (_, router) = await mountApp(t, account: 'citizen', path: route);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        navigationFallback(route),
      );
    });
  }
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(768, 1024),
  ]) {
    testWidgets('Five destinations fit $size and hide with keyboard', (
      t,
    ) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetViewInsets);
      await mountApp(t, account: 'citizen', path: '/profile/edit');
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(t.takeException(), isNull);
      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
  for (final route in ['/login', '/register']) {
    testWidgets('Auth $route fits short viewport with keyboard and no bar', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetViewInsets);
      await mountApp(t, path: route);
      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Unsaved form can cancel and then confirm route exit', (t) async {
    final router = GoRouter(
      initialLocation: '/edit',
      routes: [
        GoRoute(
          path: '/edit',
          onExit: (c, s) => GuardedForm.confirmExit(c),
          builder: (c, s) =>
              Scaffold(body: GuardedForm(child: TextFormField())),
        ),
        GoRoute(
          path: '/done',
          builder: (c, s) => const Scaffold(body: Text('Done')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), 'Draft');
    router.go('/done');
    await t.pumpAndSettle();
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
    expect(find.text('Draft'), findsOneWidget);
    router.go('/done');
    await t.pumpAndSettle();
    await t.tap(find.text('Quitter'));
    await t.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
  });
}
