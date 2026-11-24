import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/animal_status.dart';
import '../../adoption/state/adoption_store.dart';
import '../../adoption/widgets/favorite_button.dart';
import '../../adoption/widgets/catalog_feedback.dart';
import '../../../core/widgets/animal_card.dart';
import '../../../core/widgets/feature_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/animora_logo_app_bar.dart';
import '../../../core/enums/user_profile.dart';
import '../../auth/state/auth_session.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().currentUser;
    final catalog = context.watch<AdoptionStore>();
    final availableAnimals = catalog.animals
        .where((animal) => animal.status == AnimalStatus.AVAILABLE)
        .take(3)
        .toList();
    if (user == null) return const SizedBox.shrink();
    final space = switch (user.profile) {
      UserProfile.veterinarian => (
        label: 'Mon espace vétérinaire',
        path: '/veterinary/dashboard',
      ),
      UserProfile.petSitter => (
        label: 'Mes gardes',
        path: '/pet-sitting/dashboard',
      ),
      UserProfile.fosterFamily => (
        label: 'Mes hébergements',
        path: '/foster/space',
      ),
      UserProfile.admin => (label: 'Administration', path: '/admin'),
      UserProfile.citizen => null,
    };
    return Scaffold(
      appBar: AnimoraLogoAppBar(
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.go('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'ENSEMBLE POUR LEUR BIEN-ÊTRE',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Bonjour, ${user.firstName} ☀',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Une belle journée pour faire une différence.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Une famille pour chaque patte.',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Votre prochain compagnon vous attend peut-être ici.',
                      ),
                      const SizedBox(height: 18),
                      AppButton(
                        label: 'Rencontrer les animaux',
                        onPressed: () => context.go('/animals'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ils attendent une famille',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/animals'),
                      child: const Text('Voir tous'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (catalog.loading || catalog.error != null)
                  CatalogFeedback(store: catalog)
                else if (availableAnimals.isEmpty)
                  const Text('Aucun animal disponible pour le moment.')
                else
                  SizedBox(
                    height: 320,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: availableAnimals.length,
                      separatorBuilder: (_, i) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => SizedBox(
                        width: 210,
                        child: AnimalCard(
                          animal: availableAnimals[i],
                          onTap: () => context.push(
                            '/animals/${availableAnimals[i].id}',
                          ),
                          favoriteAction: FavoriteButton(
                            animalId: availableAnimals[i].id,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Comment voulez-vous aider ?',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 600
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        for (final m in _modules)
                          SizedBox(
                            width: width,
                            child: FeatureCard(
                              label: m.label,
                              icon: m.icon,
                              color: m.color,
                              background: m.background,
                              onTap: () => context.push(m.path),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                if (space != null) ...[
                  FeatureCard(
                    label: space.label,
                    icon: Icons.dashboard_outlined,
                    color: AppColors.primary,
                    background: AppColors.primaryLight,
                    onTap: () => context.push(space.path),
                  ),
                  const SizedBox(height: 20),
                ],
                const Text(
                  'Version locale de développement · Animaux fictifs',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _modules = [
  (
    label: 'Mes rendez-vous vétérinaires',
    path: '/veterinary/my-appointments',
    icon: Icons.event_available_outlined,
    color: AppColors.veterinary,
    background: AppColors.turquoiseLight,
  ),
  (
    label: 'Mes demandes de garde',
    path: '/pet-sitting/my-requests',
    icon: Icons.pets_outlined,
    color: AppColors.adoption,
    background: AppColors.greenLight,
  ),
  (
    label: 'Carnets de santé',
    path: '/health',
    icon: Icons.health_and_safety_outlined,
    color: AppColors.veterinary,
    background: AppColors.turquoiseLight,
  ),
  (
    label: 'Perdus / trouvés',
    path: '/lost-found',
    icon: Icons.location_searching,
    color: AppColors.reports,
    background: AppColors.reportsLight,
  ),
  (
    label: 'Retrouvailles',
    path: '/reunion-stories',
    icon: Icons.celebration_outlined,
    color: AppColors.reports,
    background: AppColors.reportsLight,
  ),
  (
    label: 'Adoption',
    path: '/adoptions',
    icon: Icons.favorite_outline,
    color: AppColors.adoption,
    background: AppColors.greenLight,
  ),
  (
    label: 'Signalements',
    path: '/reports',
    icon: Icons.campaign_outlined,
    color: AppColors.reports,
    background: AppColors.reportsLight,
  ),
  (
    label: 'Vétérinaires',
    path: '/veterinary',
    icon: Icons.medical_services_outlined,
    color: AppColors.veterinary,
    background: AppColors.turquoiseLight,
  ),
  (
    label: 'Pet-sitting',
    path: '/pet-sitting',
    icon: Icons.home_outlined,
    color: AppColors.primary,
    background: AppColors.primaryLight,
  ),
  (
    label: 'Dons',
    path: '/donations',
    icon: Icons.volunteer_activism_outlined,
    color: AppColors.donations,
    background: AppColors.purpleLight,
  ),
  (
    label: 'Événements',
    path: '/events',
    icon: Icons.celebration_outlined,
    color: AppColors.events,
    background: AppColors.pinkLight,
  ),
];
