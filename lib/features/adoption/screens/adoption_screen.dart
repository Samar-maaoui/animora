import '../../../core/widgets/navigation_app_bar.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/user_profile.dart';
import '../../../core/widgets/feature_card.dart';
import '../../auth/state/auth_session.dart';

class AdoptionsScreen extends StatelessWidget {
  const AdoptionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthSession>().currentUser?.profile;
    return Scaffold(
      appBar: NavigationAppBar(title: const Text('Adoptions')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FeatureCard(
            label: 'Rencontrer les animaux',
            icon: Icons.pets_outlined,
            color: AppColors.adoption,
            background: AppColors.greenLight,
            onTap: () => context.push('/animals'),
          ),
          FeatureCard(
            label: 'Mes demandes d’adoption',
            icon: Icons.assignment_outlined,
            color: AppColors.adoption,
            background: AppColors.greenLight,
            onTap: () => context.push('/adoptions/my'),
          ),
          if (profile == UserProfile.fosterFamily)
            FeatureCard(
              label: 'Mes hébergements',
              icon: Icons.home_outlined,
              color: AppColors.adoption,
              background: AppColors.greenLight,
              onTap: () => context.push('/foster-family'),
            ),
          if (profile == UserProfile.admin) ...[
            FeatureCard(
              label: 'Administrer les adoptions',
              icon: Icons.admin_panel_settings_outlined,
              color: AppColors.adoption,
              background: AppColors.greenLight,
              onTap: () => context.push('/admin/adoptions'),
            ),
            FeatureCard(
              label: 'Administrer les hébergements',
              icon: Icons.home_outlined,
              color: AppColors.adoption,
              background: AppColors.greenLight,
              onTap: () => context.push('/admin/foster-placements'),
            ),
          ],
        ],
      ),
    );
  }
}
