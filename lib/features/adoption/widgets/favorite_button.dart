import '../../../core/widgets/app_notification.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../repositories/animal_repository.dart';
import '../state/adoption_store.dart';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.animalId});
  final int animalId;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdoptionStore>();
    final selected = store.isFavorite(animalId);
    return IconButton.filledTonal(
      key: ValueKey('favorite-$animalId'),
      tooltip: selected ? 'Retirer des favoris' : 'Ajouter aux favoris',
      isSelected: selected,
      icon: Icon(
        selected ? Icons.favorite : Icons.favorite_outline,
        color: AppColors.primary,
      ),
      onPressed: store.busy
          ? null
          : () async {
              try {
                await store.toggleFavorite(animalId);
              } catch (error) {
                if (context.mounted) {
                  AppNotification.error(context, catalogErrorMessage(error));
                }
              }
            },
    );
  }
}
