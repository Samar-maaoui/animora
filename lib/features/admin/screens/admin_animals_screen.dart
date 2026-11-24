import '../../../core/widgets/app_notification.dart';
import '../../../core/widgets/navigation_app_bar.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/animal_status.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../adoption/models/animal.dart';
import '../../adoption/repositories/animal_repository.dart';
import '../../adoption/state/adoption_store.dart';
import '../../adoption/widgets/animal_photo.dart';
import '../../adoption/widgets/catalog_feedback.dart';

class AdminAnimalsScreen extends StatelessWidget {
  const AdminAnimalsScreen({super.key});
  Future<void> _delete(BuildContext context, Animal animal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet animal ?'),
        content: Text(
          'Supprimer ${animal.name} et ses favoris associés ? Cette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<AdoptionStore>().delete(animal.id);
    } catch (error) {
      if (context.mounted) {
        AppNotification.error(context, catalogErrorMessage(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdoptionStore>();
    return Scaffold(
      appBar: NavigationAppBar(title: const Text('Gestion des animaux')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: store.busy
                      ? null
                      : () => context.push('/admin/animals/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un animal'),
                ),
              ),
              const SizedBox(height: 16),
              if (store.loading || store.error != null)
                CatalogFeedback(store: store)
              else if (store.animals.isEmpty)
                const EmptyStateWidget(
                  title: 'Aucun animal',
                  message: 'Ajoutez le premier animal au catalogue.',
                )
              else
                for (final animal in store.animals)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AnimalPhoto(
                              source: animal.animalPhoto,
                              name: animal.name,
                              height: 140,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            animal.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${animal.species} · ${animal.city} · ${animal.status.label}',
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    context.push('/animals/${animal.id}'),
                                child: const Text('Consulter'),
                              ),
                              TextButton(
                                key: ValueKey('edit-animal-${animal.id}'),
                                onPressed: store.busy
                                    ? null
                                    : () => context.push(
                                        '/admin/animals/${animal.id}/edit',
                                      ),
                                child: const Text('Modifier'),
                              ),
                              TextButton(
                                key: ValueKey('delete-animal-${animal.id}'),
                                onPressed: store.busy
                                    ? null
                                    : () => _delete(context, animal),
                                child: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
