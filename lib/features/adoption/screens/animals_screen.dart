import '../../../core/widgets/navigation_app_bar.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/animal_status.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../models/animal_filter.dart';
import '../state/adoption_store.dart';
import '../widgets/animal_grid.dart';
import '../widgets/catalog_feedback.dart';

class AnimalsScreen extends StatefulWidget {
  const AnimalsScreen({super.key});
  @override
  State<AnimalsScreen> createState() => _AnimalsScreenState();
}

class _AnimalsScreenState extends State<AnimalsScreen> {
  final _search = TextEditingController();
  String? _species, _breed, _city;
  AnimalAgeGroup? _age;
  AnimalStatus? _status;
  int _resetKey = 0;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _search.clear();
    _species = null;
    _breed = null;
    _city = null;
    _age = null;
    _status = null;
    _resetKey++;
  });
  Widget _filter<T>(
    String label,
    T? value,
    List<T> values,
    String Function(T) display,
    ValueChanged<T?> change,
  ) => SizedBox(
    width: 220,
    child: DropdownButtonFormField<T>(
      key: ValueKey('$label-$_resetKey'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<T>(child: const Text('Tous')),
        for (final option in values)
          DropdownMenuItem(
            value: option,
            child: Text(display(option), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: change,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdoptionStore>();
    final breeds = {...store.animals.map((a) => a.breed), ?_breed}.toList()
      ..sort();
    final cities = {...store.animals.map((a) => a.city), ?_city}.toList()
      ..sort();
    final filter = AnimalFilter(
      name: _search.text,
      species: _species,
      breed: _breed,
      age: _age,
      city: _city,
      status: _status,
    );
    final animals = store.animals.where(filter.matches).toList();
    return Scaffold(
      appBar: NavigationAppBar(title: const Text('Animaux à adopter')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                key: const ValueKey('animal-search'),
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Rechercher par nom',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _filter(
                    'Espèce',
                    _species,
                    ['Chien', 'Chat', 'Autre'],
                    (s) => s,
                    (v) => setState(() => _species = v),
                  ),
                  _filter(
                    'Race',
                    _breed,
                    breeds,
                    (s) => s,
                    (v) => setState(() => _breed = v),
                  ),
                  _filter(
                    'Âge',
                    _age,
                    AnimalAgeGroup.values,
                    (s) => s.label,
                    (v) => setState(() => _age = v),
                  ),
                  _filter(
                    'Ville',
                    _city,
                    cities,
                    (s) => s,
                    (v) => setState(() => _city = v),
                  ),
                  _filter(
                    'Statut',
                    _status,
                    AnimalStatus.values,
                    (s) => s.label,
                    (v) => setState(() => _status = v),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Réinitialiser les filtres'),
                ),
              ),
              if (store.loading || store.error != null)
                CatalogFeedback(store: store)
              else if (animals.isEmpty)
                const EmptyStateWidget(
                  title: 'Aucun animal',
                  message: 'Aucun animal ne correspond à votre recherche.',
                )
              else ...[
                Text(
                  '${animals.length} animal(aux)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                AnimalGrid(animals: animals),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
