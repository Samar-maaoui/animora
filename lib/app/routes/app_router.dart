import '../../core/widgets/guarded_form.dart';
import '../../features/events/screens/admin_event_screens.dart';
import '../../core/enums/registration_type.dart';
import '../../features/donations/screens/donation_screens.dart';
import '../../features/donations/screens/admin_donation_screens.dart';
import '../../features/animal_services/screens/admin_services_screen.dart';
import '../../features/veterinary/screens/veterinary_screens.dart';
import '../../features/veterinary/screens/health_screens.dart';
import '../../features/pet_sitting/screens/pet_sitting_screens.dart';
import '../../features/reports/screens/community_screens.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/main_shell.dart';
import '../../core/widgets/module_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/users/screens/profile_screen.dart';
import '../../features/adoption/screens/animals_screen.dart';
import '../../features/adoption/screens/animal_details_screen.dart';
import '../../features/adoption/screens/favorites_screen.dart';
import '../../features/admin/screens/admin_animals_screen.dart';
import '../../features/admin/screens/animal_form_screen.dart';
import '../../features/adoption/screens/adoption_screen.dart';
import '../../features/adoption/screens/adoption_questionnaire_screen.dart';
import '../../features/adoption/screens/my_adoptions_screen.dart';
import '../../features/adoption/screens/adoption_details_screen.dart';
import '../../features/adoption/screens/adoption_contract_screen.dart';
import '../../features/adoption/screens/adoption_follow_up_screen.dart';
import '../../features/adoption/screens/foster_family_screen.dart';
import '../../features/adoption/screens/foster_placement_details_screen.dart';
import '../../features/admin/screens/admin_adoptions_screen.dart';
import '../../features/admin/screens/admin_foster_placements_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/veterinary/screens/veterinary_screen.dart';
import '../../features/pet_sitting/screens/pet_sitting_screen.dart';
import '../../features/donations/screens/donations_screen.dart';
import '../../features/events/screens/events_screen.dart';
import '../../features/admin/screens/admin_screen.dart';
import '../../features/admin/screens/admin_users_screen.dart';
import '../../features/users/screens/edit_profile_screen.dart';
import '../../features/users/screens/change_password_screen.dart';
import '../../features/users/screens/member_card_screen.dart';
import '../../features/admin/screens/admin_security_log_screen.dart';
import '../../features/auth/screens/account_access_screen.dart';
import '../../features/auth/state/auth_session.dart';
import '../../core/enums/account_status.dart';
import '../../core/enums/user_profile.dart';
import '../../features/auth/services/account_policy.dart';

/// Status and profile guards are refreshed from the shared session.
GoRouter createAppRouter({
  required AuthSession session,
  String initialLocation = '/splash',
}) => GoRouter(
  refreshListenable: _RouteSessionRefresh(session),
  redirect: (context, state) => sessionRedirect(session, state.uri.path),
  initialLocation: initialLocation,
  errorBuilder: (context, state) =>
      const ModuleScreen(title: 'Page introuvable'),
  routes: [
    GoRoute(path: '/', redirect: (_, state) => '/splash'),
    GoRoute(
      onExit: (context, state) =>
          sessionRedirect(session, state.uri.path) != null
          ? true
          : GuardedForm.confirmExit(context),
      path: '/splash',
      builder: (_, state) => const SplashScreen(),
    ),
    GoRoute(
      onExit: (context, state) =>
          sessionRedirect(session, state.uri.path) != null
          ? true
          : GuardedForm.confirmExit(context),
      path: '/login',
      builder: (_, state) => LoginScreen(
        registered: state.uri.queryParameters['registered'] == '1',
        passwordReset: state.uri.queryParameters['reset'] == '1',
        awaitingApproval: UserProfile.values
            .where(
              (p) =>
                  p.name == state.uri.queryParameters['awaiting'] &&
                  AccountPolicy.initialStatus(p) == AccountStatus.pending,
            )
            .firstOrNull,
      ),
    ),
    GoRoute(
      onExit: (context, state) =>
          sessionRedirect(session, state.uri.path) != null
          ? true
          : GuardedForm.confirmExit(context),
      path: '/pending-approval',
      builder: (_, state) => const AccountAccessScreen(),
    ),
    GoRoute(
      onExit: (context, state) =>
          sessionRedirect(session, state.uri.path) != null
          ? true
          : GuardedForm.confirmExit(context),
      path: '/blocked',
      builder: (_, state) => const AccountAccessScreen(blocked: true),
    ),
    GoRoute(
      onExit: (context, state) =>
          sessionRedirect(session, state.uri.path) != null
          ? true
          : GuardedForm.confirmExit(context),
      path: '/register',
      builder: (_, state) => const RegisterScreen(),
    ),
    GoRoute(path: '/welcome', builder: (_, state) => const WelcomeScreen()),
    GoRoute(
      path: '/forgot-password',
      builder: (_, state) => ForgotPasswordScreen(
        initialEmail: state.uri.queryParameters['email'],
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainShell(shell: shell),
      branches: [
        StatefulShellBranch(
          initialLocation: '/home',
          routes: [
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/home',
              builder: (_, state) => const HomeScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/access-denied',
              builder: (_, state) => const ModuleScreen(
                title: 'Accès refusé',
                message: 'Votre profil ne permet pas d’ouvrir cet espace. Revenez à l’accueil pour accéder à vos fonctionnalités.',
                icon: Icons.lock_outline,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/veterinary/my-appointments',
              builder: (_, state) => const MyVeterinaryAppointmentsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/veterinary/dashboard',
              builder: (_, state) => const VeterinarianDashboardScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/veterinary/availability',
              builder: (_, state) => const VeterinarianAvailabilityScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/veterinary/book/:id',
              builder: (_, state) => BookVeterinaryAppointmentScreen(
                veterinarianId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/veterinary/:id',
              builder: (_, state) =>
                  VeterinarianProfileScreen(id: state.pathParameters['id']!),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/health',
              builder: (_, state) => const HealthAnimalsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/pet-sitting/my-requests',
              builder: (_, state) => const MyPetSittingRequestsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/pet-sitting/dashboard',
              builder: (_, state) => const PetSitterDashboardScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/pet-sitting/settings',
              builder: (_, state) => const PetSitterSettingsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/pet-sitting/request/:id',
              builder: (_, state) => CreatePetSittingRequestScreen(
                sitterId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/pet-sitting/requests/:id/tracking',
              builder: (_, state) => PetSittingTrackingScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/pet-sitting/requests/:id/review',
              builder: (_, state) => PetSitterReviewScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/pet-sitting/:id',
              builder: (_, state) =>
                  PetSitterProfileScreen(id: state.pathParameters['id']!),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/services',
              builder: (_, state) => const AdminServicesScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/adoptions',
              builder: (_, state) => const AdminAdoptionsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/foster-placements',
              builder: (_, state) => const AdminFosterPlacementsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/reports/new',
              builder: (_, state) => const CreateReportScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/reports/:id',
              builder: (_, state) => ReportDetailsScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/lost-found',
              builder: (_, state) => const LostFoundScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/lost-found/new',
              builder: (_, state) => const CreateAnnouncementScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/lost-found/:id',
              builder: (_, state) => AnnouncementDetailsScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/lost-found/:id/edit',
              builder: (_, state) => AnnouncementEditScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/lost-found/:id/testimonies',
              builder: (_, state) => TestimoniesScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/lost-found/:id/zone',
              builder: (_, state) => SearchZoneScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/matches',
              builder: (_, state) => const MatchesScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/matches/:id',
              builder: (_, state) => MatchDetailsScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/claims',
              builder: (_, state) => const ClaimsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/claims/new/:announcementId',
              builder: (_, state) => AnimalClaimScreen(
                announcementId:
                    int.tryParse(
                      state.pathParameters['announcementId'] ?? '',
                    ) ??
                    -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/reunion-stories',
              builder: (_, state) => const ReunionStoriesScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/reunion-stories/new/:id',
              builder: (_, state) => ReunionStoryFormScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/reports',
              builder: (_, state) => const AdminReportsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/reports',
              builder: (_, state) => const ReportsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/veterinary',
              builder: (_, state) => const VeterinaryScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/pet-sitting',
              builder: (_, state) => const PetSittingScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/donations/my',
              builder: (_, state) => const MyDonationsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/donations/recurring',
              builder: (_, state) => const RecurringDonationsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/donations/campaigns/:id',
              builder: (_, state) => DonationCampaignDetailsScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/donations/financial/:campaignId',
              builder: (_, state) => FinancialDonationScreen(
                campaignId:
                    int.tryParse(state.pathParameters['campaignId'] ?? '') ??
                    -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/donations/material/:campaignId',
              builder: (_, state) => MaterialDonationScreen(
                campaignId:
                    int.tryParse(state.pathParameters['campaignId'] ?? '') ??
                    -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/donations/receipts/:id',
              builder: (_, state) => DonationReceiptScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/donations/details/:id',
              builder: (_, state) => DonationDetailsScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/donations',
              builder: (_, state) => const AdminDonationsDashboardScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/donations/campaigns',
              builder: (_, state) => const AdminDonationCampaignsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/donations/campaigns/new',
              builder: (_, state) => const AdminCampaignFormScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/donations/campaigns/:id/edit',
              builder: (_, state) => AdminCampaignFormScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/donations/campaigns/:id/needs',
              builder: (_, state) => AdminMaterialNeedsScreen(
                campaignId:
                    int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/donations/campaigns/:id/contributions',
              builder: (_, state) => AdminCampaignContributionsScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/donations/material',
              builder: (_, state) => const AdminMaterialDonationsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/donations/reports',
              builder: (_, state) => AdminTransparencyReportsScreen(
                initialCampaignId: int.tryParse(
                  state.uri.queryParameters['campaignId'] ?? '',
                ),
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/donations',
              builder: (_, state) => const DonationsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/events/my',
              builder: (_, state) => const MyEventsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/events/volunteer',
              builder: (_, state) => const VolunteerDashboardScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/events/tickets/:id',
              builder: (_, state) => EventTicketScreen(
                key: ValueKey(state.uri.toString()),
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/events/:id/register',
              builder: (_, state) => EventRegistrationScreen(
                key: ValueKey(state.uri.toString()),
                eventId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
                initialType: state.uri.queryParameters['type'] == 'VOLUNTEER'
                    ? RegistrationType.VOLUNTEER
                    : RegistrationType.PARTICIPANT,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/events/:id/report',
              builder: (_, state) => EventReportScreen(
                key: ValueKey(state.uri.toString()),
                eventId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/events/:id',
              builder: (_, state) => EventDetailsScreen(
                key: ValueKey(state.uri.toString()),
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/events',
              builder: (_, state) => const AdminEventsDashboardScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/events/list',
              builder: (_, state) => const AdminEventsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/events/new',
              builder: (_, state) => const EventFormScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/events/:id/edit',
              builder: (_, state) => EventFormScreen(
                key: ValueKey(state.uri.toString()),
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/events/:id/registrations',
              builder: (_, state) => AdminEventRegistrationsScreen(
                key: ValueKey(state.uri.toString()),
                eventId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/events/:id/activities',
              builder: (_, state) => AdminEventActivitiesScreen(
                key: ValueKey(state.uri.toString()),
                eventId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/events/:id/volunteers',
              builder: (_, state) => AdminVolunteerTasksScreen(
                key: ValueKey(state.uri.toString()),
                eventId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/events/:id/report',
              builder: (_, state) => AdminEventReportScreen(
                key: ValueKey(state.uri.toString()),
                eventId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/events',
              builder: (_, state) => const EventsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin',
              builder: (_, state) => const AdminScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/animals',
              builder: (_, state) => const AdminAnimalsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/animals/new',
              builder: (_, state) => const AnimalFormScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/animals/:id/edit',
              builder: (_, state) => AnimalFormScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/admin/users',
              builder: (_, state) => const AdminUsersScreen(),
            ),
            GoRoute(
              path: '/admin/security',
              builder: (_, state) => const AdminSecurityLogScreen(),
            ),
            GoRoute(
              path: '/veterinary/space',
              redirect: (_, state) => '/veterinary/dashboard',
            ),
            GoRoute(
              path: '/pet-sitting/space',
              redirect: (_, state) => '/pet-sitting/dashboard',
            ),
          ],
        ),
        StatefulShellBranch(
          initialLocation: '/animals',
          routes: [
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/adoptions',
              builder: (_, state) => const AdoptionsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/adoptions/new/:animalId',
              builder: (_, state) => AdoptionQuestionnaireScreen(
                animalId:
                    int.tryParse(state.pathParameters['animalId'] ?? '') ?? -1,
                placementId: int.tryParse(
                  state.uri.queryParameters['placementId'] ?? '',
                ),
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/adoptions/my',
              builder: (_, state) => const MyAdoptionsScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/adoptions/:id',
              builder: (_, state) => AdoptionDetailsScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/adoptions/:id/contract',
              builder: (_, state) => AdoptionContractScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/adoptions/:id/follow-up',
              builder: (_, state) => AdoptionFollowUpScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/foster-family',
              builder: (_, state) => const FosterFamilyScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/foster-family/:id',
              builder: (_, state) => FosterPlacementDetailsScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/foster/space',
              builder: (_, state) => const FosterFamilyScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/animals',
              builder: (_, state) => const AnimalsScreen(),
              routes: [
                GoRoute(
                  onExit: (context, state) =>
                      sessionRedirect(session, state.uri.path) != null
                      ? true
                      : GuardedForm.confirmExit(context),
                  path: ':id',
                  builder: (_, state) => AnimalDetailsScreen(
                    id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
                  ),
                  routes: [
                    GoRoute(
                      path: 'adoption',
                      redirect: (_, state) =>
                          '/adoptions/new/${state.pathParameters['id']}',
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/animals/:id/health',
              builder: (_, state) => AnimalCareHistoryScreen(
                animalId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/animals/:id/vaccinations',
              builder: (_, state) => VaccinationRecordScreen(
                animalId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/animals/:id/reminders',
              builder: (_, state) => HealthRemindersScreen(
                animalId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          initialLocation: '/favorites',
          routes: [
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/favorites',
              builder: (_, state) => const FavoritesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          initialLocation: '/notifications',
          routes: [
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/notifications',
              builder: (_, state) => const ModuleScreen(
                title: 'Notifications',
                icon: Icons.notifications_outlined,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          initialLocation: '/profile',
          routes: [
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/profile',
              builder: (_, state) => const ProfileScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/profile/edit',
              builder: (_, state) => const EditProfileScreen(),
            ),
            GoRoute(
              onExit: (context, state) =>
                  sessionRedirect(session, state.uri.path) != null
                  ? true
                  : GuardedForm.confirmExit(context),
              path: '/profile/password',
              builder: (_, state) => const ChangePasswordScreen(),
            ),
            GoRoute(
              path: '/profile/card',
              builder: (_, state) => const MemberCardScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

String? sessionRedirect(AuthSession session, String path) {
  if (!session.ready) return path == '/splash' ? null : '/splash';
  final user = session.currentUser;
  const publicPaths = ['/welcome', '/login', '/register', '/forgot-password'];
  if (user == null) {
    if (publicPaths.contains(path)) return null;
    // App start shows the welcome screen; guarded URLs go to sign-in.
    return path == '/splash' || path == '/' ? '/welcome' : '/login';
  }
  if (user.status == AccountStatus.pending) {
    return path == '/pending-approval' ? null : '/pending-approval';
  }
  if (user.status == AccountStatus.blocked) {
    return path == '/blocked' ? null : '/blocked';
  }
  if (publicPaths.contains(path) ||
      ['/splash', '/', '/pending-approval', '/blocked'].contains(path)) {
    return '/home';
  }
  if ((path == '/admin' || path.startsWith('/admin/')) &&
      user.profile != UserProfile.admin) {
    return '/access-denied';
  }
  final professionalProfile = switch (path) {
    '/veterinary/dashboard' ||
    '/veterinary/availability' => UserProfile.veterinarian,
    '/pet-sitting/dashboard' ||
    '/pet-sitting/settings' => UserProfile.petSitter,
    _ => null,
  };
  if (professionalProfile != null && user.profile != professionalProfile) {
    return '/access-denied';
  }
  final requiredProfile = switch (path) {
    '/veterinary/space' => UserProfile.veterinarian,
    '/pet-sitting/space' => UserProfile.petSitter,
    '/foster/space' => UserProfile.fosterFamily,
    _ => null,
  };
  if ((path == '/foster-family' || path.startsWith('/foster-family/')) &&
      user.profile != UserProfile.fosterFamily &&
      user.profile != UserProfile.admin) {
    return '/access-denied';
  }
  if (requiredProfile != null &&
      user.profile != requiredProfile &&
      user.profile != UserProfile.admin) {
    return '/access-denied';
  }
  return null;
}

// Navigation refreshes only when route permissions can actually change.
// Busy flags and profile text updates must not discard a pushed editor.
class _RouteSessionRefresh extends ChangeNotifier {
  _RouteSessionRefresh(this.session) {
    _value = _snapshot();
  }
  final AuthSession session;
  late Object _value;
  Object _snapshot() => (
    session.ready,
    session.currentUser?.id,
    session.currentUser?.status,
    session.currentUser?.profile,
  );
  void _refresh() {
    final next = _snapshot();
    if (next != _value) {
      _value = next;
      notifyListeners();
    }
  }

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners) session.addListener(_refresh);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) session.removeListener(_refresh);
  }

  @override
  void dispose() {
    session.removeListener(_refresh);
    super.dispose();
  }
}
