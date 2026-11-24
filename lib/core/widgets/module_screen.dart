import 'navigation_app_bar.dart';

import 'package:flutter/material.dart';

import 'empty_state_widget.dart';

class ModuleScreen extends StatelessWidget {
  const ModuleScreen({
    super.key,
    required this.title,
    this.icon = Icons.pets_rounded,
    this.message,
  });
  final String title;
  final IconData icon;
  final String? message;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: NavigationAppBar(title: Text(title)),
    body: EmptyStateWidget(
      title: title,
      message: message ?? 'Cet espace sera disponible lors d’une prochaine étape.\nAucune donnée réelle pour le moment.',
      icon: icon,
    ),
  );
}
