import 'package:animora/core/enums/account_status.dart';
import 'package:animora/core/widgets/app_notification.dart';
import 'package:animora/core/database/sql_module.dart';
import 'package:animora/core/database/sqlite_runtime_scope.dart';
import 'package:animora/core/database/database_helper.dart';
import 'package:animora/features/adoption/state/adoption_store.dart';
import 'package:animora/features/adoption/database/business_user_source.dart';
import 'package:animora/features/events/widgets/events_scope.dart';
import 'package:animora/features/donations/widgets/donations_scope.dart';
import 'package:animora/features/veterinary/screens/veterinary_screens.dart';
import 'package:animora/features/pet_sitting/screens/pet_sitting_screens.dart';
import 'package:animora/features/animal_services/widgets/services_scope.dart';
import 'package:animora/features/reports/widgets/reports_scope.dart';

import 'support/reports_test_support.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:animora/app/routes/app_router.dart';
import 'package:animora/app/theme/app_theme.dart';
import 'package:animora/core/enums/user_profile.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/auth/state/auth_session.dart';
import 'package:animora/features/adoption/widgets/adoption_scope.dart';
import 'package:animora/features/adoption/screens/foster_family_screen.dart';

import 'support/catalog_test_support.dart';

import 'support/auth_test_support.dart';

Future<(AuthSession, GoRouter)> mountApp(
  WidgetTester tester, {
  String path = '/splash',
  String? account,
  DateTime Function()? eventsClock,
  DatabaseHelper? catalogDatabaseHelper,
  BusinessUserSource? catalogBusinessUsers,
  SqliteModuleContext? moduleContext,
}) async {
  final repo = (await tester.runAsync(() => testRepository()))!;
  final session = AuthSession(repo);
  await tester.runAsync(() async {
    await session.initialize();
    if (account != null) {
      await session.login('$account@animora.test', DemoAccounts.password);
    }
    await Future<void>.delayed(Duration.zero);
  });
  final router = createAppRouter(session: session, initialLocation: path);
  addTearDown(() {
    router.dispose();
    session.dispose();
    repo.dispose();
  });
  Future<void> mountTree() async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: SqliteRuntimeScope(
          context: moduleContext,
          child: ReportsScope(
            storage: MemoryReportsStorage(),
            location: DeniedReportLocation(),
            child: AdoptionScope(
              databaseHelper: catalogDatabaseHelper,
              businessUsers: catalogBusinessUsers,
              storage: MemoryCatalogStorage(),
              child: ServicesScope(
                storage: MemoryReportsStorage(),
                child: DonationsScope(
                  storage: MemoryReportsStorage(),
                  child: EventsScope(
                    clock: eventsClock,
                    storage: MemoryReportsStorage(),
                    child: MaterialApp.router(
                      theme: AppTheme.light,
                      routerConfig: router,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  if (catalogDatabaseHelper != null || moduleContext != null) {
    await tester.runAsync(() async {
      await (catalogDatabaseHelper ?? moduleContext!.helper).database;
      await mountTree();
      final store = tester
          .element(find.byType(MaterialApp))
          .read<AdoptionStore>();
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (store.loading && DateTime.now().isBefore(deadline)) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      if (store.loading) {
        throw TestFailure('Initial SQLite catalogue load did not complete.');
      }
    });
  } else {
    await mountTree();
  }
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() async {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 15));
    });
  }
  await tester.pumpAndSettle();
  return (session, router);
}

Future<void> submit(
  WidgetTester tester,
  AuthSession session,
  String label,
) async {
  // Let field errors settle before scrolling within the taller logo header.
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(find.text(label));
    for (var i = 0; i < 1000 && session.busy; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    // Let repositories triggered by the session change finish in the real zone.
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 10)),
  );
  await tester.pumpAndSettle();
  expect(session.busy, isFalse);
}

void main() {
  setUpAll(seedDatabase);
  testWidgets(
    'No session goes from Splash to Welcome, then Login; private URLs remain guarded',
    (tester) async {
      final (_, router) = await mountApp(tester);
      expect(router.routeInformationProvider.value.uri.path, '/welcome');
      expect(find.text('Commencer'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('welcome-start')));
      await tester.pumpAndSettle();
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
      router.go('/admin/users');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
    },
  );
  testWidgets('Tapping empty login fields does not turn them red', (
    tester,
  ) async {
    final (session, _) = await mountApp(tester, path: '/login');
    await tester.tap(find.byKey(const ValueKey('email')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('password')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('email')), 'a');
    await tester.enterText(find.byKey(const ValueKey('email')), '');
    await tester.pumpAndSettle();
    expect(find.text('L’e-mail est obligatoire.'), findsNothing);
    expect(find.text('Ce champ est obligatoire.'), findsNothing);
    await submit(tester, session, 'Se connecter');
    expect(find.text('L’e-mail est obligatoire.'), findsOneWidget);
  });
  testWidgets('Notifications appear at the top and close by themselves', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    AppNotification.success(c, 'Profil mis à jour.'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    final text = find.text('Profil mis à jour.');
    expect(text, findsOneWidget);
    expect(tester.getCenter(text).dy, lessThan(200));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(text, findsNothing);
  });
  for (final scenario in [
    (account: 'citizen', route: '/home', title: 'Bonjour, Amine ☀'),
    (
      account: 'pending',
      route: '/pending-approval',
      title: 'Compte en attente de validation',
    ),
    (account: 'blocked', route: '/blocked', title: 'Compte bloqué'),
  ]) {
    testWidgets(
      'Login routes ${scenario.account} according to account status',
      (tester) async {
        final (session, router) = await mountApp(tester, path: '/login');
        await tester.enterText(
          find.byKey(const ValueKey('email')),
          '${scenario.account}@animora.test',
        );
        await tester.enterText(
          find.byKey(const ValueKey('password')),
          DemoAccounts.password,
        );
        await submit(tester, session, 'Se connecter');
        expect(router.routeInformationProvider.value.uri.path, scenario.route);
        expect(find.text(scenario.title), findsOneWidget);
        if (scenario.account != 'citizen') {
          router.go('/home');
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.path,
            scenario.route,
          );
          await submit(tester, session, 'Retour à la connexion');
          expect(find.text('Se connecter'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Wrong password displays an error and visibility can be toggled',
    (tester) async {
      final (session, _) = await mountApp(tester, path: '/login');
      await tester.enterText(
        find.byKey(const ValueKey('email')),
        'citizen@animora.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('password')),
        'incorrect',
      );
      await tester.tap(find.byTooltip('Afficher le mot de passe'));
      await tester.pump();
      final passwordField = find.descendant(
        of: find.byKey(const ValueKey('password')),
        matching: find.byType(TextFormField),
      );
      final editable = find.descendant(
        of: passwordField,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(editable).obscureText, isFalse);
      await submit(tester, session, 'Se connecter');
      expect(find.text('E-mail ou mot de passe incorrect.'), findsOneWidget);
      expect(session.currentUser, isNull);
    },
  );
  testWidgets(
    'Registration validates required fields, formats, confirmation and profile',
    (tester) async {
      await mountApp(tester, path: '/register');
      await tester.ensureVisible(find.text('Créer mon compte'));
      await tester.tap(find.text('Créer mon compte'));
      await tester.pumpAndSettle();
      expect(find.text('Choisissez un profil.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('email')));
      await tester.enterText(find.byKey(const ValueKey('email')), 'invalid');
      await tester.enterText(find.byKey(const ValueKey('phone')), '12abc');
      await tester.enterText(find.byKey(const ValueKey('password')), 'short');
      await tester.enterText(
        find.byKey(const ValueKey('confirmation')),
        'other',
      );
      await tester.pumpAndSettle();
      expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);
      expect(
        find.text('Saisissez 8 à 15 chiffres, avec un + facultatif.'),
        findsOneWidget,
      );
      expect(find.textContaining('Mot de passe trop faible'), findsOneWidget);
      expect(
        find.text('Les mots de passe doivent être identiques.'),
        findsOneWidget,
      );
      final dropdown = tester.widget<DropdownButton<UserProfile>>(
        find.byType(DropdownButton<UserProfile>),
      );
      // Public form must not offer an admin option.
      expect(find.text('Administrateur'), findsNothing);
      expect(
        dropdown.items!.map((item) => item.value),
        isNot(contains(UserProfile.admin)),
      );
    },
  );
  testWidgets(
    'Veterinarian: e-mail verified, then waits for admin validation',
    (tester) async {
      final (session, router) = await mountApp(tester, path: '/register');
      for (final entry in {
        'firstName': 'Sami',
        'lastName': 'Veto',
        'email': 'sami.veto@example.test',
        'phone': '+216 20 444 555',
        'city': 'Sousse',
        'password': 'Secret2026!',
        'confirmation': 'Secret2026!',
      }.entries) {
        await tester.ensureVisible(find.byKey(ValueKey(entry.key)));
        await tester.enterText(find.byKey(ValueKey(entry.key)), entry.value);
      }
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButton<UserProfile>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<UserProfile>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vétérinaire').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('professionalCard')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('professionalCard')),
        'CNOV-7788',
      );
      await submit(tester, session, 'Créer mon compte');
      final demo = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('verify-demo-code')),
              matching: find.byType(Text),
            ),
          )
          .data!;
      await tester.enterText(
        find.byKey(const ValueKey('verify-code')),
        RegExp(r'\d{6}').firstMatch(demo)!.group(0)!,
      );
      await submit(tester, session, 'Vérifier');

      // No « compte créé, connectez-vous » and no confetti: waiting notice.
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(
        find.byKey(const ValueKey('registration-pending')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('registration-success')), findsNothing);
      expect(find.textContaining('un administrateur doit'), findsOneWidget);

      // Signing in only shows the waiting screen.
      await tester.runAsync(
        () => session.login('sami.veto@example.test', 'Secret2026!'),
      );
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/pending-approval',
      );
      expect(find.text('Compte en attente de validation'), findsOneWidget);
      router.go('/veterinary/dashboard');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/pending-approval',
      );

      // After the admin validates, the veterinarian gets in.
      final vetId = session.currentUser!.id;
      await tester.runAsync(() async {
        await session.logout();
        await session.login('admin@animora.test', DemoAccounts.password);
        await session.updateUserStatus(vetId, AccountStatus.active);
        await session.logout();
        await session.login('sami.veto@example.test', 'Secret2026!');
      });
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(router.routeInformationProvider.value.uri.path, '/home');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Valid registration returns to login and duplicate email appears under its field',
    (tester) async {
      final (session, router) = await mountApp(tester, path: '/register');
      for (final entry in {
        'firstName': 'Lina',
        'lastName': 'Test',
        'email': 'citizen@animora.test',
        'phone': '+216 20 555 666',
        'city': 'Tunis',
        'password': 'Secret2026!',
        'confirmation': 'Secret2026!',
      }.entries) {
        await tester.ensureVisible(find.byKey(ValueKey(entry.key)));
        await tester.enterText(find.byKey(ValueKey(entry.key)), entry.value);
      }
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButton<UserProfile>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<UserProfile>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Citoyen').last);
      await tester.pumpAndSettle();
      await submit(tester, session, 'Créer mon compte');
      await tester.ensureVisible(find.byKey(const ValueKey('email')));
      expect(
        find.text('Cette adresse e-mail est déjà utilisée.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('email')),
        'lina@example.test',
      );
      await submit(tester, session, 'Créer mon compte');
      // E-mail verification: no account before the code is confirmed.
      expect(find.text('Vérifiez votre e-mail'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/register');
      final demo = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('verify-demo-code')),
              matching: find.byType(Text),
            ),
          )
          .data!;
      final code = RegExp(r'\d{6}').firstMatch(demo)!.group(0)!;
      final wrong = code == '000000' ? '111111' : '000000';
      await tester.enterText(find.byKey(const ValueKey('verify-code')), wrong);
      await submit(tester, session, 'Vérifier');
      expect(find.textContaining('Code incorrect'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('verify-code')), code);
      await submit(tester, session, 'Vérifier');
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(
        find.byKey(const ValueKey('registration-success')),
        findsOneWidget,
      );
      expect(session.currentUser, isNull);
    },
  );
  testWidgets('Citizen cannot open admin URLs or another profile workspace', (
    tester,
  ) async {
    final (_, router) = await mountApp(
      tester,
      account: 'citizen',
      path: '/admin',
    );
    expect(router.routeInformationProvider.value.uri.path, '/access-denied');
    router.go('/admin/users');
    await tester.pumpAndSettle();
    expect(find.text('Accès refusé'), findsWidgets);
    router.go('/veterinary/space');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/access-denied');
  });
  testWidgets('Security journal refreshes and filters by category', (
    tester,
  ) async {
    final (session, _) = await mountApp(
      tester,
      account: 'admin',
      path: '/admin/security',
    );
    expect(find.text('Connexion réussie'), findsWidgets);
    await tester.runAsync(
      () => session.updateUserStatus('demo-pending', AccountStatus.active),
    );
    await tester.tap(find.byTooltip('Actualiser'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Statut modifié'), findsOneWidget);
    expect(find.textContaining('pending → active'), findsOneWidget);
    expect(find.textContaining('par Salma Admin'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filter-alerts')));
    await tester.pumpAndSettle();
    expect(find.text('Statut modifié'), findsNothing);
    expect(find.text('Aucun événement'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filter-admin')));
    await tester.pumpAndSettle();
    expect(find.text('Statut modifié'), findsOneWidget);
    expect(find.text('Connexion réussie'), findsNothing);
  });
  testWidgets('Admin refuses a pending registration: account deleted', (
    tester,
  ) async {
    final (session, _) = await mountApp(
      tester,
      account: 'admin',
      path: '/admin/users',
    );
    expect(find.text('Nour Haddad'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reject-demo-pending')));
    await tester.pumpAndSettle();
    expect(find.text('Refuser cette inscription ?'), findsOneWidget);
    await submit(tester, session, 'Refuser et supprimer');
    expect(find.text('Nour Haddad'), findsNothing);
    expect(find.text('Inscription refusée'), findsOneWidget);
    // Existing accounts get a delete button (not admins / own account).
    expect(find.byKey(const ValueKey('delete-demo-citizen')), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-demo-admin')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });
  testWidgets('Admin can filter, consult and confirm a status change', (
    tester,
  ) async {
    final (session, router) = await mountApp(
      tester,
      account: 'admin',
      path: '/admin/users',
    );
    expect(router.routeInformationProvider.value.uri.path, '/admin/users');
    await tester.tap(find.byKey(const ValueKey('profile-filter-veterinarian')));
    await tester.pumpAndSettle();
    expect(find.text('Amine Ben Ali'), findsNothing);
    // Status tiles act as filters (Total / Actif / En attente / Bloqué).
    await tester.tap(find.bySemanticsLabel(RegExp(r'^En attente : \d+$')));
    await tester.pumpAndSettle();
    expect(find.text('Nour Haddad'), findsOneWidget);
    expect(find.text('Amine Ben Ali'), findsNothing);
    await tester.tap(find.text('Consulter'));
    await tester.pumpAndSettle();
    expect(find.text('Détails de l’utilisateur'), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text('Valider ce compte ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Nour Haddad'), findsOneWidget);
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    await submit(tester, session, 'Confirmer');
    expect(find.text('Nour Haddad'), findsNothing);
    expect(find.text('Aucun utilisateur'), findsOneWidget);
    // Search by name across all statuses.
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Total : \d+$')));
    await tester.tap(find.byKey(const ValueKey('profile-filter-all')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-user-search')),
      'nour',
    );
    await tester.pumpAndSettle();
    expect(find.text('Nour Haddad'), findsOneWidget);
    expect(find.text('Amine Ben Ali'), findsNothing);
  });
  testWidgets(
    'Editing profile updates the shared session and logout prevents Back access',
    (tester) async {
      final (session, router) = await mountApp(
        tester,
        account: 'citizen',
        path: '/profile',
      );
      await tester.scrollUntilVisible(
        find.text('Modifier le profil'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Modifier le profil'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'Amira');
      await submit(tester, session, 'Enregistrer');
      expect(session.currentUser?.firstName, 'Amira');
      expect(
        router.routeInformationProvider.value.uri.path,
        '/profile',
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      await tester.scrollUntilVisible(
        find.text('Amira Ben Ali'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Amira Ben Ali'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Se déconnecter'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await submit(tester, session, 'Se déconnecter');
      expect(router.routeInformationProvider.value.uri.path, '/login');
      router.go('/profile/edit');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
    },
  );
  for (final space in [
    (
      account: 'veterinarian',
      title: 'Mon espace vétérinaire',
      path: '/veterinary/dashboard',
    ),
    (
      account: 'pet-sitter',
      title: 'Mes gardes',
      path: '/pet-sitting/dashboard',
    ),
    (account: 'foster', title: 'Mes hébergements', path: '/foster/space'),
  ]) {
    testWidgets('Home exposes the workspace for ${space.account}', (
      tester,
    ) async {
      await mountApp(tester, account: space.account, path: '/home');
      await tester.scrollUntilVisible(
        find.text(space.title),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text(space.title));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() async {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 15));
        });
      }
      await tester.pumpAndSettle();
      if (space.account == 'foster') {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FosterFamilyScreen), findsOneWidget);
      } else {
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(() async {
            await tester.pump();
            await Future<void>.delayed(const Duration(milliseconds: 15));
          });
        }
        await tester.pumpAndSettle();
        expect(
          find.byType(
            space.account == 'veterinarian'
                ? VeterinarianDashboardScreen
                : PetSitterDashboardScreen,
          ),
          findsOneWidget,
        );
      }
      expect(
        find.text(
          space.account == 'pet-sitter' ? 'Mon espace pet-sitter' : space.title,
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final path in [
    '/home',
    '/animals',
    '/adoptions',
    '/reports',
    '/veterinary',
    '/pet-sitting',
    '/donations',
    '/events',
    '/favorites',
    '/notifications',
    '/profile',
  ]) {
    testWidgets('Existing route $path still renders at mobile width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mountApp(tester, account: 'citizen', path: path);
      expect(tester.takeException(), isNull);
    });
  }
}
