import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/animal_card.dart';
import '../models/animal.dart';
import 'favorite_button.dart';

class AnimalGrid extends StatelessWidget {
  const AnimalGrid({super.key, required this.animals});
  final List<Animal> animals;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / 280).floor().clamp(1, 4);
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final animal in animals)
            SizedBox(
              width: (constraints.maxWidth - 12 * (columns - 1)) / columns,
              child: AnimalCard(
                animal: animal,
                onTap: () => context.push('/animals/${animal.id}'),
                favoriteAction: FavoriteButton(animalId: animal.id),
              ),
            ),
        ],
      );
    },
  );
}
