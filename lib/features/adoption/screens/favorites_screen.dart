import '../../../core/widgets/navigation_app_bar.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/empty_state_widget.dart';
import '../state/adoption_store.dart';
import '../widgets/animal_grid.dart';
import '../widgets/catalog_feedback.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdoptionStore>();
    final animals = [
      for (final favorite in store.favorites) ?store.byId(favorite.animalId),
    ];
    return Scaffold(
      appBar: NavigationAppBar(title: const Text('Favoris')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (store.loading || store.error != null)
                CatalogFeedback(store: store)
              else if (animals.isEmpty)
                const EmptyStateWidget(
                  title: 'Aucun favori',
                  message: 'Touchez le cœur sur la fiche d’un animal pour le retrouver ici.',
                  icon: Icons.favorite_outline,
                )
              else
                AnimalGrid(animals: animals),
            ],
          ),
        ),
      ),
    );
  }
}
