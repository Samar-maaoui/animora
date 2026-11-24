import '../../../core/widgets/guarded_form.dart';
import '../widgets/event_weather.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/event_widgets.dart';
import '../models/event.dart';
import '../models/event_registration.dart';
import '../models/event_ticket.dart';
import '../models/event_activity.dart';
import '../models/volunteer_task.dart';
import '../models/event_report.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String query = '', city = '';
  final queryController = TextEditingController(),
      cityController = TextEditingController();
  @override
  void dispose() {
    queryController.dispose();
    cityController.dispose();
    super.dispose();
  }

  EventType? type;
  EventStatus? status;
  DateTime? date;
  @override
  Widget build(BuildContext c) => EventsView<List<(Event, int)>>(
    load: (s) async {
      final all = await s.events.getEvents();
      return Future.wait(
        all
            .where((e) => e.status != EventStatus.DRAFT)
            .map((e) async => (e, await s.events.availablePlaces(e.id))),
      );
    },
    builder: (c, all) {
      final now = c.read<EventsStore>().now;
      final filtered = all.where((row) {
        final e = row.$1;
        return e.title.toLowerCase().contains(query.toLowerCase()) &&
            e.city.toLowerCase().contains(city.toLowerCase()) &&
            (type == null || e.type == type) &&
            (status == null || e.status == status) &&
            (date == null ||
                (!e.startDate.isAfter(
                      date!
                          .add(const Duration(days: 1))
                          .subtract(const Duration(microseconds: 1)),
                    ) &&
                    e.endDate.isAfter(date!)));
      }).toList();
      return EventsPage(
        title: 'Événements et bénévolat',
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              serviceLink(c, 'Mes événements', '/events/my'),
              serviceLink(c, 'Espace bénévole', '/events/volunteer'),
              if (c.watch<AuthSession>().currentUser?.profile ==
                  UserProfile.admin)
                serviceLink(
                  c,
                  'Administration des événements',
                  '/admin/events',
                ),
            ],
          ),
          TextField(
            controller: queryController,
            decoration: const InputDecoration(
              labelText: 'Rechercher un événement',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          TextField(
            controller: cityController,
            decoration: const InputDecoration(labelText: 'Filtrer par ville'),
            onChanged: (v) => setState(() => city = v),
          ),
          serviceDropdown<EventType>(
            type,
            EventType.values,
            'Type d’événement',
            (v) => v.label,
            (v) => setState(() => type = v),
          ),
          serviceDropdown<EventStatus>(
            status,
            EventStatus.values.where((s) => s != EventStatus.DRAFT).toList(),
            'Statut',
            (v) => v.label,
            (v) => setState(() => status = v),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  date == null ? 'Choisir une date' : serviceDate(date!),
                ),
                onPressed: () async {
                  final selected = await servicePickDate(
                    c,
                    date ?? now,
                    past: true,
                  );
                  if (selected != null && mounted) {
                    setState(() => date = selected);
                  }
                },
              ),
              TextButton(
                onPressed: () => setState(() {
                  query = '';
                  city = '';
                  queryController.clear();
                  cityController.clear();
                  type = null;
                  status = null;
                  date = null;
                }),
                child: const Text('Réinitialiser les filtres'),
              ),
            ],
          ),
          for (final past in [false, true]) ...[
            Text(
              past ? 'Événements passés' : 'Événements à venir',
              style: Theme.of(c).textTheme.titleLarge,
            ),
            if (!filtered.any((row) => (!now.isBefore(row.$1.endDate)) == past))
              const Text('Aucun événement dans cette section.'),
            for (final row in filtered.where(
              (row) => (!now.isBefore(row.$1.endDate)) == past,
            ))
              eventCard([
                EventPhoto(row.$1.id),
                Text(row.$1.title, style: Theme.of(c).textTheme.titleLarge),
                serviceBadge(row.$1.status.label),
                Text(row.$1.type.label),
                Text(serviceDateTime(row.$1.startDate)),
                Text('${row.$1.city} • ${row.$1.location}'),
                Text('${row.$2} place(s) disponible(s) sur ${row.$1.capacity}'),
                serviceLink(c, 'Voir l’événement', '/events/${row.$1.id}'),
              ]),
          ],
        ],
      );
    },
  );
}

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext c) =>
      EventsView<
        (Event, int, List<EventActivity>, List<EventRegistration>, EventReport?)
      >(
        load: (s) async => (
          await s.events.getEvent(id),
          await s.events.availablePlaces(id),
          await s.activities.getActivities(id),
          await s.registrations.getRegistrations(eventId: id),
          await s.reports.getReport(id),
        ),
        builder: (c, data) {
          final (e, places, activities, registrations, report) = data;
          final uid = c.watch<AuthSession>().currentUser!.id;
          final mine = registrations
              .where(
                (r) =>
                    r.userId == uid && r.status != RegistrationStatus.CANCELLED,
              )
              .firstOrNull;
          final open =
              e.status == EventStatus.PUBLISHED &&
              c.read<EventsStore>().now.isBefore(e.startDate);
          return EventsPage(
            title: e.title,
            children: [
              EventPhoto(e.id),
              serviceBadge(e.status.label),
              Text(e.description),
              Text(e.type.label),
              Text(
                'Du ${serviceDateTime(e.startDate)} au ${serviceDateTime(e.endDate)}',
              ),
              Text('${e.location}, ${e.city}'),
              if (e.latitude != null)
                EventMap(latitude: e.latitude!, longitude: e.longitude!),
              EventWeatherPanel(event: e),
              Text('Capacité : ${e.capacity} • places restantes : $places'),
              if (mine != null)
                serviceLink(c, 'Voir mon inscription', '/events/my')
              else if (open)
                Wrap(
                  spacing: 8,
                  children: [
                    serviceLink(
                      c,
                      'Participer',
                      '/events/$id/register?type=PARTICIPANT',
                    ),
                    serviceLink(
                      c,
                      'Devenir bénévole',
                      '/events/$id/register?type=VOLUNTEER',
                    ),
                  ],
                )
              else
                const Text('Les inscriptions sont fermées.'),
              Text('Programme', style: Theme.of(c).textTheme.titleLarge),
              if (activities.isEmpty) const Text('Aucune activité publiée.'),
              for (final a in activities)
                eventCard([
                  Text(a.title, style: Theme.of(c).textTheme.titleMedium),
                  Text(a.description),
                  Text(
                    '${serviceDateTime(a.startTime)} au ${serviceDateTime(a.endTime)}',
                  ),
                ]),
              if (report?.published == true)
                serviceLink(
                  c,
                  'Consulter le bilan publié',
                  '/events/$id/report',
                ),
              if (c.watch<AuthSession>().currentUser?.profile ==
                  UserProfile.admin)
                serviceLink(c, 'Gérer cet événement', '/admin/events/$id/edit'),
            ],
          );
        },
      );
}

class EventRegistrationScreen extends StatefulWidget {
  const EventRegistrationScreen({
    super.key,
    required this.eventId,
    this.initialType = RegistrationType.PARTICIPANT,
  });
  final int eventId;
  final RegistrationType initialType;
  @override
  State<EventRegistrationScreen> createState() =>
      _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends State<EventRegistrationScreen> {
  late RegistrationType type = widget.initialType;
  bool waitlist = false, busy = false;
  @override
  Widget build(BuildContext c) => EventsView<(Event, int)>(
    load: (s) async => (
      await s.events.getEvent(widget.eventId),
      await s.events.availablePlaces(widget.eventId),
    ),
    builder: (c, data) {
      final (e, places) = data;
      final open =
          e.status == EventStatus.PUBLISHED &&
          c.read<EventsStore>().now.isBefore(e.startDate);
      return EventsPage(
        title: 'Inscription à un événement',
        children: [
          Text(e.title, style: Theme.of(c).textTheme.titleLarge),
          Text('${serviceDateTime(e.startDate)} • ${e.location}, ${e.city}'),
          Text('$places place(s) restante(s) • billet gratuit'),
          serviceDropdown(
            type,
            RegistrationType.values,
            'Type d’inscription',
            (v) => v.label,
            (v) {
              if (v != null) setState(() => type = v);
            },
          ),
          if (places <= 0)
            CheckboxListTile(
              value: waitlist,
              onChanged: GuardedForm.track<bool?>(
                (v) => setState(() => waitlist = v ?? false),
              ),
              title: const Text('Rejoindre la liste d’attente'),
              subtitle: const Text(
                'Aucun billet avant confirmation. Votre statut sera mis à jour dans l’application si une place se libère.',
              ),
            ),
          if (!open) const Text('Cet événement n’accepte plus d’inscription.'),
          FilledButton(
            onPressed: busy || !open || (places <= 0 && !waitlist)
                ? null
                : () async {
                    if (!await serviceConfirm(
                      c,
                      'Confirmer votre inscription comme ${type.label.toLowerCase()} ? Le billet est gratuit.',
                    )) {
                      return;
                    }
                    if (!c.mounted) return;
                    setState(() => busy = true);
                    EventRegistration? registered;
                    final store = c.read<EventsStore>();
                    final ok = await eventAction(
                      c,
                      () async {
                        registered = await store.registrations.register(
                          e.id,
                          type,
                          acceptWaitlist: waitlist,
                        );
                      },
                      message: places <= 0
                          ? 'Inscription en liste d’attente enregistrée.'
                          : 'Inscription confirmée, billet disponible.',
                    );
                    if (!mounted || !c.mounted) return;
                    setState(() => busy = false);
                    if (ok && registered != null) {
                      GuardedForm.savedGo(c, '/events/my');
                    }
                  },
            child: Text(busy ? 'Enregistrement…' : 'Confirmer mon inscription'),
          ),
        ],
      );
    },
  );
}

class MyEventsScreen extends StatelessWidget {
  const MyEventsScreen({super.key});
  @override
  Widget build(
    BuildContext c,
  ) => EventsView<List<(EventRegistration, Event, EventTicket?)>>(
    load: (s) async {
      final regs = await s.registrations.getRegistrations();
      final uid = s.session.currentUser!.id;
      return Future.wait(
        regs
            .where((r) => r.userId == uid)
            .map(
              (r) async => (
                r,
                await s.events.getEvent(r.eventId),
                await s.tickets.ticketForRegistration(r.id),
              ),
            ),
      );
    },
    builder: (c, rows) {
      final store = c.read<EventsStore>();
      return EventsPage(
        title: 'Mes événements',
        children: [
          serviceLink(c, 'Catalogue des événements', '/events'),
          for (final past in [false, true]) ...[
            Text(
              past ? 'Historique' : 'À venir',
              style: Theme.of(c).textTheme.titleLarge,
            ),
            if (!rows.any(
              (row) =>
                  (!store.now.isBefore(row.$2.endDate) ||
                      row.$2.status == EventStatus.CANCELLED ||
                      row.$2.status == EventStatus.COMPLETED) ==
                  past,
            ))
              const Text('Aucune inscription dans cette section.'),
            for (final (r, e, t) in rows.where(
              (row) =>
                  (!store.now.isBefore(row.$2.endDate) ||
                      row.$2.status == EventStatus.CANCELLED ||
                      row.$2.status == EventStatus.COMPLETED) ==
                  past,
            ))
              eventCard([
                Text(e.title, style: Theme.of(c).textTheme.titleLarge),
                Text('${serviceDateTime(e.startDate)} • ${e.city}'),
                Text('Inscription : ${r.type.label}'),
                serviceBadge(r.status.label),
                if (r.status == RegistrationStatus.WAITLISTED)
                  const Text('En attente d’une place ; aucun billet émis.'),
                if (r.status == RegistrationStatus.ATTENDED)
                  const Text('Présence validée ; billet déjà utilisé.'),
                serviceLink(c, 'Détails de l’événement', '/events/${e.id}'),
                if (t != null)
                  serviceLink(c, 'Voir mon billet', '/events/tickets/${t.id}'),
                if (e.status == EventStatus.PUBLISHED &&
                    store.now.isBefore(e.startDate) &&
                    (r.status == RegistrationStatus.CONFIRMED ||
                        r.status == RegistrationStatus.WAITLISTED))
                  OutlinedButton(
                    onPressed: () async {
                      if (await serviceConfirm(
                        c,
                        'Annuler cette inscription ? Son billet sera invalidé et la place sera proposée à la liste d’attente.',
                      )) {
                        if (c.mounted) {
                          await eventAction(
                            c,
                            () => store.registrations.cancelRegistration(r.id),
                          );
                        }
                      }
                    },
                    child: const Text('Annuler mon inscription'),
                  ),
              ]),
          ],
        ],
      );
    },
  );
}

class EventTicketScreen extends StatelessWidget {
  const EventTicketScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(
    BuildContext c,
  ) => EventsView<(EventTicket, EventRegistration, Event)>(
    load: (s) async {
      final t = await s.tickets.getTicket(id);
      final rows = await s.registrations.getRegistrations();
      final r = rows.firstWhere((r) => r.id == t.registrationId);
      return (t, r, await s.events.getEvent(r.eventId));
    },
    builder: (c, data) {
      final (t, r, e) = data;
      return EventsPage(
        title: 'Billet numérique gratuit',
        children: [
          eventCard([
            Text(e.title, style: Theme.of(c).textTheme.headlineSmall),
            Text(r.userName),
            Text(
              '${serviceDateTime(e.startDate)} au ${serviceDateTime(e.endDate)}',
            ),
            Text('${e.location}, ${e.city}'),
            Text('Inscription : ${r.type.label}'),
            serviceBadge('Valide • non utilisé'),
            EventQr(t.code),
            Semantics(
              label: 'Code du billet : ${t.code}',
              child: ExcludeSemantics(
                child: SelectableText(t.code, textAlign: TextAlign.center),
              ),
            ),
            const Text(
              'Présentez ce code au pointage. Le QR contient uniquement le code du billet, sans donnée personnelle.',
            ),
            Text('Émis le ${serviceDateTime(t.issueDate)}'),
          ]),
        ],
      );
    },
  );
}

class VolunteerDashboardScreen extends StatelessWidget {
  const VolunteerDashboardScreen({super.key});
  @override
  Widget build(BuildContext c) =>
      EventsView<(List<(EventRegistration, Event)>, List<VolunteerTask>)>(
        load: (s) async {
          final rows = await s.registrations.getRegistrations();
          final uid = s.session.currentUser!.id;
          final mine = rows.where(
            (r) =>
                r.userId == uid &&
                r.type == RegistrationType.VOLUNTEER &&
                r.status != RegistrationStatus.CANCELLED,
          );
          if (mine.isEmpty) {
            throw const EventFailure(
              'Cet espace est réservé aux utilisateurs inscrits comme bénévoles à un événement.',
            );
          }
          return (
            await Future.wait(
              mine.map((r) async => (r, await s.events.getEvent(r.eventId))),
            ),
            await s.tasks.getTasks(),
          );
        },
        builder: (c, data) {
          final (rows, tasks) = data;
          final uid = c.watch<AuthSession>().currentUser!.id;
          return EventsPage(
            title: 'Espace bénévole',
            children: [
              for (final (r, e) in rows)
                eventCard([
                  Text(e.title, style: Theme.of(c).textTheme.titleLarge),
                  Text(serviceDateTime(e.startDate)),
                  serviceBadge(r.status.label),
                  serviceLink(c, 'Consulter l’événement', '/events/${e.id}'),
                  for (final t in tasks.where(
                    (t) => t.eventId == e.id && t.assignedUserId == uid,
                  ))
                    eventCard([
                      Text(t.title, style: Theme.of(c).textTheme.titleMedium),
                      Text(t.description),
                      serviceBadge(t.status.label),
                      if (e.status == EventStatus.PUBLISHED &&
                          c.read<EventsStore>().now.isBefore(e.endDate) &&
                          (r.status == RegistrationStatus.CONFIRMED ||
                              r.status == RegistrationStatus.ATTENDED)) ...[
                        if (t.status == VolunteerTaskStatus.ASSIGNED)
                          FilledButton(
                            onPressed: () => eventAction(
                              c,
                              () => c.read<EventsStore>().tasks.advanceTask(
                                t.id,
                                VolunteerTaskStatus.IN_PROGRESS,
                              ),
                            ),
                            child: const Text('Commencer la tâche'),
                          ),
                        if (t.status == VolunteerTaskStatus.IN_PROGRESS)
                          FilledButton(
                            onPressed: () async {
                              if (await serviceConfirm(
                                    c,
                                    'Marquer cette tâche terminée ?',
                                  ) &&
                                  c.mounted) {
                                await eventAction(
                                  c,
                                  () => c.read<EventsStore>().tasks.advanceTask(
                                    t.id,
                                    VolunteerTaskStatus.COMPLETED,
                                  ),
                                );
                              }
                            },
                            child: const Text('Terminer la tâche'),
                          ),
                      ],
                    ]),
                  if (!tasks.any(
                    (t) => t.eventId == e.id && t.assignedUserId == uid,
                  ))
                    const Text('Aucune tâche ne vous est attribuée.'),
                ]),
            ],
          );
        },
      );
}

class EventReportScreen extends StatelessWidget {
  const EventReportScreen({super.key, required this.eventId});
  final int eventId;
  @override
  Widget build(BuildContext c) => EventsView<(Event, EventReport?)>(
    load: (s) async =>
        (await s.events.getEvent(eventId), await s.reports.getReport(eventId)),
    builder: (c, data) {
      final (e, r) = data;
      return EventsPage(
        title: 'Bilan de l’événement',
        children: [
          Text(e.title, style: Theme.of(c).textTheme.titleLarge),
          if (r == null || !r.published)
            const Text('Aucun bilan publié.')
          else ...[
            Text('Participants présents : ${r.participantCount}'),
            Text('Bénévoles présents : ${r.volunteerCount}'),
            Text(
              'Comptages issus uniquement des inscriptions pointées. Bilan du ${serviceDateTime(r.createdAt)}.',
            ),
            Text(r.description),
            for (final photo in r.photos) EventPhoto(eventId, reference: photo),
          ],
        ],
      );
    },
  );
}
