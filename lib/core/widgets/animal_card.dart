import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../features/adoption/models/animal.dart';
import '../../features/adoption/widgets/animal_photo.dart';
import '../enums/animal_status.dart';

class AnimalCard extends StatelessWidget {
  const AnimalCard({
    super.key,
    required this.animal,
    this.onTap,
    this.favoriteAction,
  });
  final Animal animal;
  final VoidCallback? onTap;
  final Widget? favoriteAction;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AnimalPhoto(
                source: animal.animalPhoto,
                name: animal.name,
                height: 128,
              ),
              if (favoriteAction != null)
                Positioned(top: 6, right: 6, child: favoriteAction!),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  animal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${animal.species} · ${animal.age} ${animal.age <= 1 ? 'an' : 'ans'}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                Text(
                  animal.city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: animal.status == AnimalStatus.AVAILABLE
                        ? AppColors.greenLight
                        : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    animal.status.label,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
