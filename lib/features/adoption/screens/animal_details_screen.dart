import '../../../core/widgets/navigation_app_bar.dart';
import '../widgets/breed_information.dart';

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/animal_status.dart';
import '../widgets/adoption_request_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../state/adoption_store.dart';
import '../widgets/animal_photo.dart';
import '../widgets/catalog_feedback.dart';
import '../widgets/favorite_button.dart';

class AnimalDetailsScreen extends StatelessWidget {
  const AnimalDetailsScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdoptionStore>();
    final animal = store.byId(id);
    Widget content;
    if (store.loading || store.error != null) {
      content = CatalogFeedback(store: store);
    } else if (animal == null) {
      content = const EmptyStateWidget(
        title: 'Animal introuvable',
        message: 'Cet animal a peut-être été supprimé.',
      );
    } else {
      final details = <String, String>{
        'Espèce': animal.species,
        'Race': animal.breed,
        'Sexe': animal.sex,
        'Âge': '${animal.age} ${animal.age <= 1 ? 'an' : 'ans'}',
        'Poids': '${animal.weight} kg',
        'Couleur': animal.color,
        'Santé': animal.health,
        'Caractère': animal.character,
        'Stérilisation': animal.sterilized ? 'Oui' : 'Non',
        'Ville': animal.city,
        'Statut': animal.status.label,
        'Numéro de puce': animal.microchipNumber.isEmpty
            ? 'Non renseigné'
            : animal.microchipNumber,
        'Date d’arrivée':
            '${animal.arrivalDate.day.toString().padLeft(2, '0')}/${animal.arrivalDate.month.toString().padLeft(2, '0')}/${animal.arrivalDate.year}',
      };
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AnimalPhoto(
              source: animal.animalPhoto,
              name: animal.name,
              height: 300,
              fit: BoxFit.contain,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  animal.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              FavoriteButton(animalId: id),
            ],
          ),
          Card(
            child: Column(
              children: [
                for (final entry in details.entries)
                  ListTile(title: Text(entry.key), subtitle: Text(entry.value)),
              ],
            ),
          ),
          BreedInformation(species: animal.species, breed: animal.breed),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.push('/animals/$id/health'),
            child: const Text('Carnet de santé (accès autorisé uniquement)'),
          ),
          if (animal.status == AnimalStatus.AVAILABLE)
            AdoptionRequestButton(animalId: id),
        ],
      );
    }
    return Scaffold(
      appBar: NavigationAppBar(title: Text(animal?.name ?? 'Fiche animal')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [content],
          ),
        ),
      ),
    );
  }
}
