import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_panel.dart';
import '../../../core/network/api_scope.dart';
import '../services/breeds_api.dart';

class BreedInformation extends StatelessWidget {
  const BreedInformation({
    super.key,
    required this.species,
    this.breed,
    this.onSelected,
    this.service,
  });
  final BreedsApi? service;
  final String species;
  final String? breed;
  final ValueChanged<String>? onSelected;
  @override
  Widget build(BuildContext c) => ApiPanel<List<BreedInfo>>(
    key: ValueKey('$species|${breed ?? ''}'),
    title: 'Informations sur la race',
    action: onSelected == null
        ? 'Consulter les caractéristiques de la race'
        : 'Rechercher une race externe',
    load: (refresh) {
      if (service != null) return service!.breeds(species, refresh: refresh);
      final client = apiClient(c);
      if (client == null) {
        throw const ApiFailure(
          ApiErrorKind.configuration,
          'Service de races non configuré. Saisie manuelle possible.',
        );
      }
      return BreedsApi(client).breeds(species, refresh: refresh);
    },
    empty: (rows) => rows.isEmpty,
    builder: (c, rows) {
      final matches = breed == null
          ? rows
          : rows
                .where(
                  (x) => x.name.toLowerCase() == breed!.trim().toLowerCase(),
                )
                .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Source : ${species.toLowerCase() == 'chien' ? 'The Dog API' : 'The Cat API'} • informations générales, sans modification du score d’adoption.',
          ),
          if (onSelected != null)
            OutlinedButton(
              onPressed: () async {
                final choice = await searchableApiChoice(
                  c,
                  title: 'Races reçues — recherche par nom',
                  items: rows,
                  label: (x) => x.name,
                );
                if (choice != null && c.mounted) {
                  onSelected!(choice.name);
                  await showDialog<void>(
                    context: c,
                    builder: (c) => AlertDialog(
                      title: Text(choice.name),
                      content: SingleChildScrollView(child: _details(choice)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Fermer'),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: const Text('Choisir dans la liste des races'),
            ),
          if (breed != null)
            if (matches.isEmpty)
              const Text(
                'Aucune correspondance exacte fournie par cette API. La race locale est conservée.',
              )
            else
              _details(matches.first),
          const Text(
            'Race croisée ou API indisponible : conservez la saisie manuelle. Aucune photo animale n’est remplacée.',
          ),
        ],
      );
    },
  );
  Widget _details(BreedInfo b) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(b.name),
      for (final line in [
        b.description,
        b.temperament,
        b.origin.isEmpty ? '' : 'Origine : ${b.origin}',
        b.lifeSpan.isEmpty ? '' : 'Longévité : ${b.lifeSpan}',
        b.weight.isEmpty ? '' : 'Poids indicatif : ${b.weight} kg',
      ])
        if (line.isNotEmpty) Text(line),
    ],
  );
}
