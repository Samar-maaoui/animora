import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'guarded_form.dart';

String navigationFallback(String path) {
  if (path.startsWith('/profile/')) return '/profile';
  if (path.startsWith('/animals/')) return '/animals';
  if (path == '/admin/security') return '/admin/users';
  for (final prefix in [
    '/admin/donations',
    '/admin/events',
    '/admin/animals',
    '/admin',
    '/adoptions',
    '/foster-family',
    '/lost-found',
    '/reports',
    '/veterinary',
    '/pet-sitting',
    '/donations',
    '/events',
  ]) {
    if (path.startsWith('$prefix/')) return prefix;
  }
  return '/home';
}

class NavigationAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NavigationAppBar({
    super.key,
    this.title,
    this.actions,
    this.backgroundColor,
  });
  final Widget? title;
  final List<Widget>? actions;
  final Color? backgroundColor;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) {
    String path;
    try {
      path = GoRouterState.of(context).uri.path;
    } on GoError {
      path = GoRouter.of(context).routeInformationProvider.value.uri.path;
    }
    final root = const [
      '/home',
      '/animals',
      '/favorites',
      '/notifications',
      '/profile',
    ].contains(path);
    return AppBar(
      title: title,
      actions: actions,
      backgroundColor: backgroundColor,
      automaticallyImplyLeading: false,
      leading: root
          ? null
          : BackButton(
              onPressed: () async {
                if (!await GuardedForm.confirmExit(context) ||
                    !context.mounted) {
                  return;
                }
                if (GoRouter.of(context).canPop()) {
                  context.pop();
                } else {
                  context.go(navigationFallback(path));
                }
              },
            ),
    );
  }
}
