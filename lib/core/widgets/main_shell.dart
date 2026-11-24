import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'guarded_form.dart';
import 'navigation_app_bar.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    body: BackButtonListener(
      onBackButtonPressed: () async {
        final router = GoRouter.of(context);
        final path = router.routeInformationProvider.value.uri.path;
        if (router.canPop() ||
            const [
              '/home',
              '/animals',
              '/favorites',
              '/notifications',
              '/profile',
            ].contains(path)) {
          return false;
        }
        if (await GuardedForm.confirmExit(context) && context.mounted) {
          router.go(navigationFallback(path));
        }
        return true;
      },
      child: shell,
    ),
    bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
        ? null
        : NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (i) async {
              if (await GuardedForm.confirmExit(context) && context.mounted) {
                shell.goBranch(i, initialLocation: true);
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: 'Accueil',
              ),
              NavigationDestination(
                icon: Icon(Icons.pets_outlined),
                label: 'Animaux',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_outline),
                label: 'Favoris',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                label: 'Notifications',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                label: 'Profil',
              ),
            ],
          ),
  );
}
