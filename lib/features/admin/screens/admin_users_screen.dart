import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/account_status.dart';
import '../../../core/enums/user_profile.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/navigation_app_bar.dart';
import '../../auth/state/auth_session.dart';
import '../../users/models/user.dart';
import '../../users/widgets/user_details.dart';

IconData profileIcon(UserProfile p) => switch (p) {
  UserProfile.citizen => Icons.person_outline,
  UserProfile.veterinarian => Icons.medical_services_outlined,
  UserProfile.fosterFamily => Icons.home_outlined,
  UserProfile.petSitter => Icons.pets,
  UserProfile.admin => Icons.admin_panel_settings_outlined,
};

(Color, Color) statusColors(AccountStatus s) => switch (s) {
  AccountStatus.active => (AppColors.adoption, AppColors.greenLight),
  AccountStatus.pending => (AppColors.primaryDark, AppColors.primaryLight),
  AccountStatus.blocked => (const Color(0xFFE5484D), const Color(0xFFFFE9EA)),
};

/// Admin dashboard of accounts: statistics, search, filters, validation.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<User>> _users;
  UserProfile? _profile;
  AccountStatus? _status;
  final _search = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _users = context.read<AuthSession>().listUsers();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
    _users = context.read<AuthSession>().listUsers();
  });

  String _actionLabel(AccountStatus status) => switch (status) {
    AccountStatus.pending => 'Valider',
    AccountStatus.active => 'Bloquer',
    AccountStatus.blocked => 'Réactiver',
  };

  Future<void> _changeStatus(User user) async {
    final target = user.status == AccountStatus.active
        ? AccountStatus.blocked
        : AccountStatus.active;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(
          target == AccountStatus.blocked
              ? Icons.block_rounded
              : Icons.verified_user_outlined,
          color: statusColors(target).$1,
          size: 36,
        ),
        title: Text('${_actionLabel(user.status)} ce compte ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(user: user, radius: 22),
                const SizedBox(width: 12),
                Expanded(child: Text('${user.fullName}\n${user.email}')),
              ],
            ),
            if (user.professionalCardNumber != null) ...[
              const SizedBox(height: 12),
              _CardNumberBanner(number: user.professionalCardNumber!),
            ] else if (user.profile == UserProfile.veterinarian) ...[
              const SizedBox(height: 12),
              const Text(
                'Aucun numéro de carte professionnelle enregistré.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '${user.status.label} → ${target.label}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Nouveau statut : ${target.label}.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: statusColors(target).$1,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AuthSession>().updateUserStatus(user.id, target);
      if (!mounted) return;
      setState(() => _error = null);
      _reload();
      AppNotification.success(
        context,
        '${user.fullName} : ${target.label}.',
        title: 'Compte mis à jour',
      );
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    }
  }

  /// Refuse a pending registration (deleted) or delete an account.
  Future<void> _remove(User user, {required bool rejection}) async {
    const danger = Color(0xFFE5484D);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(
          rejection ? Icons.person_off_outlined : Icons.delete_forever_outlined,
          color: danger,
          size: 36,
        ),
        title: Text(
          rejection ? 'Refuser cette inscription ?' : 'Supprimer ce compte ?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(user: user, radius: 22),
                const SizedBox(width: 12),
                Expanded(child: Text('${user.fullName}\n${user.email}')),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              rejection
                  ? 'Le compte est supprimé automatiquement : la personne ne '
                        'pourra plus se connecter et devra se réinscrire.'
                  : 'Suppression définitive du compte et de ses identifiants. '
                        'Si le compte a un historique (adoptions, dons…), la '
                        'suppression sera refusée : bloquez-le plutôt.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Cette action est irréversible.',
              style: TextStyle(fontWeight: FontWeight.bold, color: danger),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const ValueKey('confirm-remove'),
            style: FilledButton.styleFrom(backgroundColor: danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(rejection ? 'Refuser et supprimer' : 'Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final session = context.read<AuthSession>();
    try {
      rejection
          ? await session.rejectUser(user.id)
          : await session.deleteUser(user.id);
      if (!mounted) return;
      setState(() => _error = null);
      _reload();
      AppNotification.success(
        context,
        rejection
            ? 'Inscription de ${user.fullName} refusée : compte supprimé.'
            : 'Compte de ${user.fullName} supprimé.',
        title: rejection ? 'Inscription refusée' : 'Compte supprimé',
      );
    } catch (error) {
      if (!mounted) return;
      AppNotification.error(
        context,
        authErrorMessage(error),
        title: 'Suppression impossible',
      );
    }
  }

  void _showDetails(User user) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Détails de l’utilisateur'),
      scrollable: true,
      content: SizedBox(width: 440, child: UserDetails(user: user)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );

  bool _matches(User u) {
    final q = _search.text.trim().toLowerCase();
    return (_profile == null || u.profile == _profile) &&
        (_status == null || u.status == _status) &&
        (q.isEmpty ||
            u.fullName.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            u.city.toLowerCase().contains(q) ||
            (u.professionalCardNumber ?? '').toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    return Scaffold(
      appBar: NavigationAppBar(
        title: const Text('Gestion utilisateurs'),
        actions: [
          IconButton(
            tooltip: 'Journal de sécurité',
            onPressed: () => context.push('/admin/security'),
            icon: const Icon(Icons.shield_outlined),
          ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: session.busy ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<User>>(
        future: _users,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingWidget();
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(authErrorMessage(snapshot.error!)),
                  TextButton(
                    onPressed: _reload,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }
          final all = snapshot.data!;
          final users = all.where(_matches).toList()
            ..sort((a, b) {
              // Pending accounts first: they need an action.
              final pa = a.status == AccountStatus.pending ? 0 : 1;
              final pb = b.status == AccountStatus.pending ? 0 : 1;
              return pa != pb ? pa - pb : a.fullName.compareTo(b.fullName);
            });
          int count(AccountStatus? s) =>
              s == null ? all.length : all.where((u) => u.status == s).length;
          final pending = count(AccountStatus.pending);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverList.list(
                      children: [
                        // Statistics = status filter.
                        Row(
                          children: [
                            for (final s in [
                              null,
                              AccountStatus.active,
                              AccountStatus.pending,
                              AccountStatus.blocked,
                            ])
                              Expanded(
                                child: _StatTile(
                                  label: s == null ? 'Total' : s.label,
                                  value: count(s),
                                  color: s == null
                                      ? AppColors.primary
                                      : statusColors(s).$1,
                                  selected: _status == s,
                                  onTap: () => setState(() => _status = s),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey('admin-user-search'),
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText:
                                'Rechercher : nom, e-mail, ville, n° de carte',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Effacer',
                                    icon: const Icon(Icons.close),
                                    onPressed: () =>
                                        setState(() => _search.clear()),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final p in <UserProfile?>[
                                null,
                                ...UserProfile.values,
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    key: ValueKey(
                                      'profile-filter-${p?.name ?? 'all'}',
                                    ),
                                    avatar: Icon(
                                      p == null
                                          ? Icons.groups_outlined
                                          : profileIcon(p),
                                      size: 18,
                                    ),
                                    label: Text(
                                      p == null ? 'Tous les profils' : p.label,
                                    ),
                                    selected: _profile == p,
                                    onSelected: (_) =>
                                        setState(() => _profile = p),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (pending > 0 && _status != AccountStatus.pending)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Material(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(16),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                leading: const Icon(
                                  Icons.hourglass_top_rounded,
                                  color: AppColors.primaryDark,
                                ),
                                title: Text(
                                  '$pending compte(s) en attente de validation',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => setState(
                                  () => _status = AccountStatus.pending,
                                ),
                              ),
                            ),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                          child: Text(
                            '${users.length} résultat(s)',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (users.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyStateWidget(
                        title: 'Aucun utilisateur',
                        message: 'Aucun compte ne correspond à ces filtres.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: users.length,
                        itemBuilder: (context, i) {
                          final user = users[i];
                          return _UserCard(
                            user: user,
                            self: user.id == session.currentUser?.id,
                            actionLabel: _actionLabel(user.status),
                            onDetails: () => _showDetails(user),
                            onAction: session.busy
                                ? null
                                : () => _changeStatus(user),
                            onRemove: session.busy
                                ? null
                                : () => _remove(
                                    user,
                                    rejection:
                                        user.status == AccountStatus.pending,
                                  ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Semantics(
      button: true,
      selected: selected,
      label: '$label : $value',
      child: Material(
        color: selected ? color : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? color : AppColors.border,
                width: 1.5,
              ),
            ),
            child: ExcludeSemantics(
              child: Column(
                children: [
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                  FittedBox(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.self,
    required this.actionLabel,
    required this.onDetails,
    required this.onAction,
    required this.onRemove,
  });
  final User user;
  final bool self;
  final String actionLabel;
  final VoidCallback onDetails;
  final VoidCallback? onAction;

  /// « Refuser » (pending) or « Supprimer » (others).
  final VoidCallback? onRemove;

  static String _date(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusTint) = statusColors(user.status);
    final Widget action = self
        ? const Chip(
            avatar: Icon(Icons.star_rounded, size: 16),
            label: Text('Votre compte'),
          )
        : switch (user.status) {
            AccountStatus.active => OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE5484D),
                side: const BorderSide(color: Color(0xFFE5484D)),
              ),
              onPressed: onAction,
              icon: const Icon(Icons.block_rounded, size: 18),
              label: Text(actionLabel),
            ),
            AccountStatus.pending => FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.adoption,
                minimumSize: const Size(0, 42),
              ),
              onPressed: onAction,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(actionLabel),
            ),
            AccountStatus.blocked => FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: onAction,
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: Text(actionLabel),
            ),
          };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: user.status == AccountStatus.pending
              ? AppColors.primary
              : AppColors.border,
          width: user.status == AccountStatus.pending ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    UserAvatar(user: user, radius: 26),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(color: AppColors.muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _Meta(
                  icon: profileIcon(user.profile),
                  text: user.profile.label,
                ),
                _Meta(icon: Icons.location_on_outlined, text: user.city),
                _Meta(
                  icon: Icons.event_outlined,
                  text: 'Inscrit le ${_date(user.createdAt)}',
                ),
              ],
            ),
            if (user.professionalCardNumber != null) ...[
              const SizedBox(height: 8),
              _CardNumberBanner(number: user.professionalCardNumber!),
            ],
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Consulter'),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!self && user.profile != UserProfile.admin) ...[
                      if (user.status == AccountStatus.pending)
                        OutlinedButton.icon(
                          key: ValueKey('reject-${user.id}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE5484D),
                            side: const BorderSide(color: Color(0xFFE5484D)),
                            minimumSize: const Size(0, 42),
                          ),
                          onPressed: onRemove,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Refuser'),
                        )
                      else
                        IconButton(
                          key: ValueKey('delete-${user.id}'),
                          tooltip: 'Supprimer le compte',
                          color: const Color(0xFFE5484D),
                          onPressed: onRemove,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      const SizedBox(width: 6),
                    ],
                    action,
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppColors.muted),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 13)),
    ],
  );
}

/// Professional card number read by OCR at sign-up, shown to the admin
/// before validating a veterinarian account.
class _CardNumberBanner extends StatelessWidget {
  const _CardNumberBanner({required this.number});
  final String number;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.badge, size: 18, color: AppColors.primaryDark),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Carte professionnelle : $number',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
