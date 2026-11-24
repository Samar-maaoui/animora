import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/account_status.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/navigation_app_bar.dart';
import '../../auth/models/auth_event.dart';
import '../../auth/state/auth_session.dart';
import '../../users/models/user.dart';

enum SecurityLogFilter { all, logins, alerts, accounts, admin }

extension SecurityLogFilterRules on SecurityLogFilter {
  String get label => switch (this) {
    SecurityLogFilter.all => 'Tout',
    SecurityLogFilter.logins => 'Connexions',
    SecurityLogFilter.alerts => 'Alertes',
    SecurityLogFilter.accounts => 'Comptes & e-mails',
    SecurityLogFilter.admin => 'Administration',
  };

  IconData get icon => switch (this) {
    SecurityLogFilter.all => Icons.list_alt_rounded,
    SecurityLogFilter.logins => Icons.login_rounded,
    SecurityLogFilter.alerts => Icons.warning_amber_rounded,
    SecurityLogFilter.accounts => Icons.mark_email_read_outlined,
    SecurityLogFilter.admin => Icons.admin_panel_settings_outlined,
  };

  /// Every event type belongs to exactly one specific filter (+ « Tout »).
  bool accepts(AuthEventType type) => switch (this) {
    SecurityLogFilter.all => true,
    SecurityLogFilter.logins => const {
      AuthEventType.loginSuccess,
      AuthEventType.loginBiometric,
      AuthEventType.logout,
      AuthEventType.sessionExpired,
    }.contains(type),
    SecurityLogFilter.alerts => const {
      AuthEventType.loginFailure,
      AuthEventType.loginLocked,
    }.contains(type),
    SecurityLogFilter.accounts => const {
      AuthEventType.register,
      AuthEventType.emailCodeSent,
      AuthEventType.emailVerified,
      AuthEventType.passwordResetRequested,
      AuthEventType.passwordReset,
      AuthEventType.passwordChange,
      AuthEventType.photoUpdate,
      AuthEventType.profileUpdate,
      AuthEventType.biometricEnabled,
      AuthEventType.biometricDisabled,
    }.contains(type),
    SecurityLogFilter.admin => const {
      AuthEventType.statusChange,
      AuthEventType.accountRejected,
      AuthEventType.accountDeleted,
    }.contains(type),
  };
}

/// Security journal: newest first, with date and time. Never contains a
/// password, hash or e-mail code.
class AdminSecurityLogScreen extends StatefulWidget {
  const AdminSecurityLogScreen({super.key});
  @override
  State<AdminSecurityLogScreen> createState() => _AdminSecurityLogScreenState();
}

typedef _Journal = ({List<AuthEvent> events, Map<String, User> users});

class _AdminSecurityLogScreenState extends State<AdminSecurityLogScreen> {
  late Future<_Journal> _journal;
  SecurityLogFilter _filter = SecurityLogFilter.all;

  @override
  void initState() {
    super.initState();
    _journal = _load();
  }

  Future<_Journal> _load() async {
    final session = context.read<AuthSession>();
    final events = await session.listAuthEvents(limit: 500);
    var users = <String, User>{};
    try {
      users = {for (final u in await session.listUsers()) u.id: u};
    } catch (_) {
      // Names are a convenience: ids remain visible.
    }
    // Newest first, whatever the storage order.
    events.sort((a, b) {
      final byDate = b.createdAt.compareTo(a.createdAt);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
    return (events: events, users: users);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _journal = next;
    });
    await next;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _time(DateTime d) {
    final l = d.toLocal();
    return '${_two(l.hour)}:${_two(l.minute)}:${_two(l.second)}';
  }

  static String _day(DateTime d) {
    final l = d.toLocal();
    final today = DateTime.now();
    final date = DateTime(l.year, l.month, l.day);
    final diff = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(date).inDays;
    final full = '${_two(l.day)}/${_two(l.month)}/${l.year}';
    return diff == 0
        ? 'Aujourd’hui · $full'
        : diff == 1
        ? 'Hier · $full'
        : full;
  }

  static (IconData, Color) _style(AuthEventType type) => switch (type) {
    AuthEventType.loginFailure => (
      Icons.gpp_maybe_outlined,
      const Color(0xFFE5484D),
    ),
    AuthEventType.loginLocked => (Icons.lock_clock, const Color(0xFFB42318)),
    AuthEventType.loginSuccess => (Icons.login_rounded, AppColors.adoption),
    AuthEventType.loginBiometric => (Icons.fingerprint, AppColors.adoption),
    AuthEventType.logout ||
    AuthEventType.sessionExpired => (Icons.logout_rounded, AppColors.muted),
    AuthEventType.statusChange => (
      Icons.admin_panel_settings_outlined,
      AppColors.donations,
    ),
    AuthEventType.register => (Icons.person_add_alt_1, AppColors.primary),
    AuthEventType.accountRejected || AuthEventType.accountDeleted => (
      Icons.person_remove_alt_1,
      const Color(0xFFB42318),
    ),
    AuthEventType.emailCodeSent || AuthEventType.passwordResetRequested => (
      Icons.forward_to_inbox_outlined,
      AppColors.veterinary,
    ),
    AuthEventType.emailVerified => (Icons.mark_email_read, AppColors.adoption),
    AuthEventType.passwordReset ||
    AuthEventType.passwordChange => (Icons.password_rounded, AppColors.reports),
    AuthEventType.photoUpdate => (
      Icons.face_retouching_natural,
      AppColors.events,
    ),
    _ => (Icons.manage_accounts_outlined, AppColors.primary),
  };

  String _who(String? id, Map<String, User> users, {String? email}) {
    if (id == null) return email ?? '';
    final u = users[id];
    // A deleted account is no longer in the list: show its e-mail.
    return u == null ? (email ?? id) : '${u.fullName} (${u.email})';
  }

  /// « pending → active » becomes « En attente → Actif (pending → active) ».
  String? _details(AuthEvent e) {
    final d = e.details;
    if (d == null || e.type != AuthEventType.statusChange) return d;
    final parts = d.split(' → ');
    if (parts.length != 2) return d;
    String label(String name) {
      try {
        return AccountStatus.values.byName(name.trim()).label;
      } catch (_) {
        return name;
      }
    }

    return '${label(parts[0])} → ${label(parts[1])}  ($d)';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: NavigationAppBar(
      title: const Text('Journal de sécurité'),
      actions: [
        IconButton(
          tooltip: 'Actualiser',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<_Journal>(
      future: _journal,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingWidget();
        }
        if (snapshot.hasError) {
          return EmptyStateWidget(
            icon: Icons.error_outline,
            title: 'Journal indisponible',
            message: authErrorMessage(snapshot.error!),
          );
        }
        final journal = snapshot.data!;
        final events = journal.events
            .where((e) => _filter.accepts(e.type))
            .toList();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final f in SecurityLogFilter.values)
                        ChoiceChip(
                          key: ValueKey('filter-${f.name}'),
                          avatar: Icon(f.icon, size: 18),
                          label: Text(
                            '${f.label} '
                            '(${journal.events.where((e) => f.accepts(e.type)).length})',
                          ),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Du plus récent au plus ancien · aucun mot de passe ni code n’est enregistré.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: events.isEmpty
                        ? ListView(
                            children: const [
                              EmptyStateWidget(
                                icon: Icons.shield_outlined,
                                title: 'Aucun événement',
                                message: 'Rien à afficher pour ce filtre.',
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: events.length,
                            itemBuilder: (context, i) {
                              final e = events[i];
                              final header =
                                  i == 0 ||
                                  _day(events[i - 1].createdAt) !=
                                      _day(e.createdAt);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (header)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        14,
                                        4,
                                        8,
                                      ),
                                      child: Text(
                                        _day(e.createdAt),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                  _EventCard(
                                    event: e,
                                    style: _style(e.type),
                                    time: _time(e.createdAt),
                                    subject: e.userId != null
                                        ? _who(
                                            e.userId,
                                            journal.users,
                                            email: e.email,
                                          )
                                        : (e.email ?? ''),
                                    details: _details(e),
                                    actor: _who(e.actorId, journal.users),
                                  ),
                                ],
                              );
                            },
                          ),
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

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.style,
    required this.time,
    required this.subject,
    required this.details,
    required this.actor,
  });
  final AuthEvent event;
  final (IconData, Color) style;
  final String time, subject, actor;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = style;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.type.label,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(time, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  if (subject.isNotEmpty)
                    Text(subject, style: const TextStyle(fontSize: 13)),
                  if (details != null)
                    Text(
                      details!,
                      style: TextStyle(
                        fontSize: 13,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (actor.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'par $actor',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
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
}
