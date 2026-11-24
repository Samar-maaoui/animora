import '../../../core/widgets/navigation_app_bar.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/feature_card.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: NavigationAppBar(title: const Text('Administration')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        FeatureCard(
          label: 'Événements et bénévolat',
          icon: Icons.event_outlined,
          color: const Color(0xFFFF6B6B),
          background: const Color(0xFFFFE8E8),
          onTap: () => context.push('/admin/events'),
        ),

        FeatureCard(
          label: 'Dons et campagnes',
          icon: Icons.volunteer_activism_outlined,
          color: AppColors.donations,
          background: AppColors.purpleLight,
          onTap: () => context.push('/admin/donations'),
        ),
        FeatureCard(
          label: 'Rendez-vous et gardes',
          icon: Icons.supervisor_account_outlined,
          color: AppColors.veterinary,
          background: AppColors.turquoiseLight,
          onTap: () => context.push('/admin/services'),
        ),
        FeatureCard(
          label: 'Signalements et réclamations',
          icon: Icons.campaign_outlined,
          color: AppColors.reports,
          background: AppColors.reportsLight,
          onTap: () => context.push('/admin/reports'),
        ),
        FeatureCard(
          label: 'Demandes d’adoption',
          icon: Icons.assignment_outlined,
          color: AppColors.adoption,
          background: AppColors.greenLight,
          onTap: () => context.push('/admin/adoptions'),
        ),
        FeatureCard(
          label: 'Hébergements en famille',
          icon: Icons.home_outlined,
          color: AppColors.adoption,
          background: AppColors.greenLight,
          onTap: () => context.push('/admin/foster-placements'),
        ),
        FeatureCard(
          label: 'Gestion des animaux',
          icon: Icons.pets_outlined,
          color: AppColors.adoption,
          background: AppColors.greenLight,
          onTap: () => context.push('/admin/animals'),
        ),
        FeatureCard(
          label: 'Gestion utilisateurs',
          icon: Icons.manage_accounts_outlined,
          color: AppColors.primary,
          background: AppColors.primaryLight,
          onTap: () => context.push('/admin/users'),
        ),
      ],
    ),
  );
}
