import '../../../core/widgets/guarded_form.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/event_widgets.dart';
import '../models/event.dart';
import '../models/event_registration.dart';
import '../models/event_ticket.dart';
import '../models/event_activity.dart';
import '../models/volunteer_task.dart';
import '../models/event_report.dart';

import 'dart:typed_data';

class AdminEventsDashboardScreen extends StatelessWidget {
  const AdminEventsDashboardScreen({super.key});
  @override
  Widget build(
    BuildContext c,
  ) => EventsView<(List<Event>, List<EventRegistration>)>(
    load: (s) async =>
        (await s.events.getEvents(), await s.registrations.getRegistrations()),
    builder: (c, data) {
      final (events, regs) = data;
      final now = c.read<EventsStore>().now;
      return EventsPage(
        title: 'Administration des événements',
        children: [
          eventCard([
            Text('Événements : ${events.length}'),
            Text(
              'À venir publiés : ${events.where((e) => e.status == EventStatus.PUBLISHED && now.isBefore(e.startDate)).length}',
            ),
            Text(
              'Terminés : ${events.where((e) => e.status == EventStatus.COMPLETED).length}',
            ),
            Text('Inscriptions (historique inclus) : ${regs.length}'),
            Text(
              'Bénévoles actifs ou présents : ${regs.where((r) => r.type == RegistrationType.VOLUNTEER && (r.status == RegistrationStatus.CONFIRMED || r.status == RegistrationStatus.ATTENDED)).length}',
            ),
            Text(
              'Liste d’attente : ${regs.where((r) => r.status == RegistrationStatus.WAITLISTED).length}',
            ),
          ]),
          serviceLink(c, 'Gérer les événements', '/admin/events/list'),
          serviceLink(c, 'Créer un événement', '/admin/events/new'),
        ],
      );
    },
  );
}

class AdminEventsScreen extends StatelessWidget {
  const AdminEventsScreen({super.key});
  @override
  Widget build(BuildContext c) => EventsView<List<Event>>(
    load: (s) => s.events.getEvents(),
    builder: (c, events) => EventsPage(
      title: 'Gestion des événements',
      children: [
        serviceLink(c, 'Créer un événement', '/admin/events/new'),
        if (events.isEmpty) const Text('Aucun événement enregistré.'),
        for (final e in events)
          eventCard([
            Text(e.title, style: Theme.of(c).textTheme.titleLarge),
            serviceBadge(e.status.label),
            Text('${serviceDateTime(e.startDate)} • ${e.city}'),
            serviceLink(c, 'Consulter', '/events/${e.id}'),
            if (e.status == EventStatus.DRAFT ||
                e.status == EventStatus.PUBLISHED)
              serviceLink(
                c,
                'Modifier l’événement',
                '/admin/events/${e.id}/edit',
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                serviceLink(
                  c,
                  'Inscriptions et pointage',
                  '/admin/events/${e.id}/registrations',
                ),
                serviceLink(c, 'Activités', '/admin/events/${e.id}/activities'),
                serviceLink(
                  c,
                  'Tâches bénévoles',
                  '/admin/events/${e.id}/volunteers',
                ),
                serviceLink(c, 'Bilan', '/admin/events/${e.id}/report'),
              ],
            ),
            if (e.status == EventStatus.DRAFT)
              eventStatusButton(
                c,
                e,
                EventStatus.PUBLISHED,
                'Publier l’événement',
              ),
            if (e.status == EventStatus.PUBLISHED &&
                !c.read<EventsStore>().now.isBefore(e.endDate))
              eventStatusButton(
                c,
                e,
                EventStatus.COMPLETED,
                'Terminer l’événement',
              ),
            if (e.status == EventStatus.DRAFT ||
                e.status == EventStatus.PUBLISHED)
              eventStatusButton(
                c,
                e,
                EventStatus.CANCELLED,
                'Annuler l’événement',
              ),
          ]),
      ],
    ),
  );
}

Widget eventStatusButton(
  BuildContext c,
  Event e,
  EventStatus next,
  String label,
) => OutlinedButton(
  onPressed: () async {
    if (await serviceConfirm(
          c,
          '$label « ${e.title} » ? Une annulation invalide les inscriptions et billets encore actifs, sans promotion de la liste d’attente.',
        ) &&
        c.mounted) {
      await eventAction(
        c,
        () => c.read<EventsStore>().events.changeEventStatus(e.id, next),
      );
    }
  },
  child: Text(label),
);

class EventFormScreen extends StatelessWidget {
  const EventFormScreen({super.key, this.id});
  final int? id;
  @override
  Widget build(BuildContext c) => EventsView<(Event?,)>(
    load: (s) async => (id == null ? null : await s.events.getEvent(id!),),
    builder: (c, data) =>
        EventEditor(key: ValueKey(data.$1?.id ?? 0), event: data.$1),
  );
}

class EventEditor extends StatefulWidget {
  const EventEditor({super.key, this.event});
  final Event? event;
  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  late final title = TextEditingController(text: widget.event?.title),
      description = TextEditingController(text: widget.event?.description),
      city = TextEditingController(text: widget.event?.city),
      location = TextEditingController(text: widget.event?.location),
      capacity = TextEditingController(
        text: widget.event?.capacity.toString() ?? '30',
      ),
      latitude = TextEditingController(
        text: widget.event?.latitude?.toString(),
      ),
      longitude = TextEditingController(
        text: widget.event?.longitude?.toString(),
      );
  late EventType type = widget.event?.type ?? EventType.ADOPTION_DAY;
  late DateTime start =
          widget.event?.startDate ??
          DateTime.now().add(const Duration(days: 7)),
      end = widget.event?.endDate ?? start.add(const Duration(hours: 3));
  Uint8List? image;
  bool busy = false;
  @override
  void dispose() {
    for (final ctrl in [
      title,
      description,
      city,
      location,
      capacity,
      latitude,
      longitude,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => EventsPage(
    title: widget.event == null ? 'Créer un événement' : 'Modifier l’événement',
    children: [
      serviceField(title, 'Titre'),
      serviceField(description, 'Description', lines: 4),
      serviceDropdown(type, EventType.values, 'Type', (v) => v.label, (v) {
        if (v != null) setState(() => type = v);
      }),
      if (widget.event != null) EventPhoto(widget.event!.id),
      ServicePhotoPicker(onChanged: (v) => image = v),
      const Text('Image facultative • 2 Mo maximum'),
      OutlinedButton(
        onPressed: () async {
          final d = await servicePickDate(c, start, time: true);
          if (d != null && mounted) setState(() => start = d);
        },
        child: Text('Début : ${serviceDateTime(start)}'),
      ),
      OutlinedButton(
        onPressed: () async {
          final d = await servicePickDate(c, end, time: true);
          if (d != null && mounted) setState(() => end = d);
        },
        child: Text('Fin : ${serviceDateTime(end)}'),
      ),
      serviceField(location, 'Adresse / lieu'),
      serviceField(city, 'Ville'),
      serviceField(latitude, 'Latitude (facultative)'),
      serviceField(longitude, 'Longitude (facultative)'),
      serviceField(capacity, 'Capacité'),
      const Text(
        'Après la première inscription, les dates sont figées. La capacité ne peut pas être réduite sous le nombre de places occupées.',
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                final store = c.read<EventsStore>();
                final ok = await eventAction(c, () async {
                  final cap = int.tryParse(capacity.text.trim());
                  final lat = latitude.text.trim().isEmpty
                      ? null
                      : double.tryParse(
                          latitude.text.trim().replaceAll(',', '.'),
                        );
                  final lng = longitude.text.trim().isEmpty
                      ? null
                      : double.tryParse(
                          longitude.text.trim().replaceAll(',', '.'),
                        );
                  if (cap == null ||
                      (latitude.text.trim().isNotEmpty && lat == null) ||
                      (longitude.text.trim().isNotEmpty && lng == null)) {
                    throw const EventFailure(
                      'Vérifiez la capacité et les coordonnées numériques.',
                    );
                  }
                  await store.events.saveEvent(
                    Event(
                      id: widget.event?.id ?? 0,
                      title: title.text,
                      description: description.text,
                      type: type,
                      location: location.text,
                      city: city.text,
                      latitude: lat,
                      longitude: lng,
                      startDate: start,
                      endDate: end,
                      capacity: cap,
                      status: widget.event?.status ?? EventStatus.DRAFT,
                      image: widget.event?.image,
                      organizerUserId: store.session.currentUser!.id,
                    ),
                    creating: widget.event == null,
                    imageBytes: image,
                  );
                });
                if (!mounted || !c.mounted) return;
                setState(() => busy = false);
                if (ok) GuardedForm.savedGo(c, '/admin/events/list');
              },
        child: Text(busy ? 'Enregistrement…' : 'Enregistrer l’événement'),
      ),
    ],
  );
}

class AdminEventRegistrationsScreen extends StatefulWidget {
  const AdminEventRegistrationsScreen({super.key, required this.eventId});
  final int eventId;
  @override
  State<AdminEventRegistrationsScreen> createState() =>
      _AdminEventRegistrationsScreenState();
}

class _AdminEventRegistrationsScreenState
    extends State<AdminEventRegistrationsScreen> {
  RegistrationStatus? status;
  RegistrationType? type;
  final code = TextEditingController();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) =>
      EventsView<(Event, List<EventRegistration>, Map<int, EventTicket?>)>(
        load: (s) async {
          final e = await s.events.getEvent(widget.eventId),
              regs = await s.registrations.getRegistrations(
                eventId: widget.eventId,
              );
          final tickets = <int, EventTicket?>{};
          for (final r in regs) {
            tickets[r.id] = await s.tickets.ticketForRegistration(r.id);
          }
          return (e, regs, tickets);
        },
        builder: (c, data) {
          final (e, regs, tickets) = data;
          final now = c.read<EventsStore>().now;
          final canCheck =
              e.status == EventStatus.PUBLISHED &&
              !now.isBefore(e.startDate) &&
              now.isBefore(e.endDate);
          return EventsPage(
            title: 'Inscriptions et pointage',
            children: [
              Text(e.title, style: Theme.of(c).textTheme.titleLarge),
              serviceDropdown(
                status,
                RegistrationStatus.values,
                'Statut d’inscription',
                (v) => v.label,
                (v) => setState(() => status = v),
              ),
              serviceDropdown(
                type,
                RegistrationType.values,
                'Participants / bénévoles',
                (v) => v.label,
                (v) => setState(() => type = v),
              ),
              TextButton(
                onPressed: () => setState(() {
                  type = null;
                  status = null;
                }),
                child: const Text('Afficher toutes les inscriptions'),
              ),
              serviceField(code, 'Code du billet à valider'),
              if (!canCheck)
                const Text(
                  'Le pointage est ouvert uniquement pendant les horaires de l’événement publié.',
                ),
              FilledButton(
                onPressed: canCheck
                    ? () async {
                        if (await serviceConfirm(
                              c,
                              'Valider la présence avec ce code ? Le billet ne pourra plus être utilisé.',
                            ) &&
                            c.mounted) {
                          final ok = await eventAction(
                            c,
                            () => c.read<EventsStore>().tickets.checkIn(
                              e.id,
                              code.text,
                            ),
                            message: 'Présence validée, billet utilisé.',
                          );
                          if (ok) code.clear();
                        }
                      }
                    : null,
                child: const Text('Valider la présence'),
              ),
              if (regs.isEmpty) const Text('Aucune inscription.'),
              for (final r in regs.where(
                (r) =>
                    (status == null || r.status == status) &&
                    (type == null || r.type == type),
              ))
                eventCard([
                  Text(r.userName, style: Theme.of(c).textTheme.titleMedium),
                  Text(r.type.label),
                  serviceBadge(r.status.label),
                  Text('Demande : ${serviceDateTime(r.registrationDate)}'),
                  if (tickets[r.id] != null)
                    serviceLink(
                      c,
                      'Consulter le billet',
                      '/events/tickets/${tickets[r.id]!.id}',
                    ),
                  if (e.status == EventStatus.PUBLISHED &&
                      now.isBefore(e.startDate) &&
                      (r.status == RegistrationStatus.CONFIRMED ||
                          r.status == RegistrationStatus.WAITLISTED))
                    OutlinedButton(
                      onPressed: () async {
                        if (await serviceConfirm(
                              c,
                              'Annuler cette inscription et libérer sa place ?',
                            ) &&
                            c.mounted) {
                          await eventAction(
                            c,
                            () => c
                                .read<EventsStore>()
                                .registrations
                                .cancelRegistration(r.id),
                          );
                        }
                      },
                      child: const Text('Annuler l’inscription'),
                    ),
                ]),
            ],
          );
        },
      );
}

class AdminEventActivitiesScreen extends StatelessWidget {
  const AdminEventActivitiesScreen({super.key, required this.eventId});
  final int eventId;
  @override
  Widget build(BuildContext c) => EventsView<(Event, List<EventActivity>)>(
    load: (s) async => (
      await s.events.getEvent(eventId),
      await s.activities.getActivities(eventId),
    ),
    builder: (c, data) {
      final (e, activities) = data;
      final editable =
          e.status == EventStatus.DRAFT || e.status == EventStatus.PUBLISHED;
      return EventsPage(
        title: 'Programme des activités',
        children: [
          Text(e.title),
          if (editable)
            FilledButton(
              onPressed: () => showDialog<void>(
                context: c,
                builder: (_) => ActivityEditor(event: e),
              ),
              child: const Text('Ajouter une activité'),
            ),
          if (activities.isEmpty) const Text('Aucune activité.'),
          for (final a in activities)
            eventCard([
              Text(a.title, style: Theme.of(c).textTheme.titleMedium),
              Text(a.description),
              Text(
                '${serviceDateTime(a.startTime)} au ${serviceDateTime(a.endTime)}',
              ),
              if (editable)
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => showDialog<void>(
                        context: c,
                        builder: (_) => ActivityEditor(event: e, activity: a),
                      ),
                      child: const Text('Modifier l’activité'),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (await serviceConfirm(
                              c,
                              'Supprimer cette activité ?',
                            ) &&
                            c.mounted) {
                          await eventAction(
                            c,
                            () => c
                                .read<EventsStore>()
                                .activities
                                .deleteActivity(a.id),
                          );
                        }
                      },
                      child: const Text('Supprimer l’activité'),
                    ),
                  ],
                ),
            ]),
        ],
      );
    },
  );
}

class ActivityEditor extends StatefulWidget {
  const ActivityEditor({super.key, required this.event, this.activity});
  final Event event;
  final EventActivity? activity;
  @override
  State<ActivityEditor> createState() => _ActivityEditorState();
}

class _ActivityEditorState extends State<ActivityEditor> {
  late final title = TextEditingController(text: widget.activity?.title),
      description = TextEditingController(text: widget.activity?.description);
  late DateTime start = widget.activity?.startTime ?? widget.event.startDate,
      end = widget.activity?.endTime ?? widget.event.endDate;
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: Text(
      widget.activity == null ? 'Ajouter une activité' : 'Modifier l’activité',
    ),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            serviceField(title, 'Titre de l’activité'),
            const SizedBox(height: 12),
            serviceField(description, 'Description de l’activité', lines: 3),
            OutlinedButton(
              onPressed: () async {
                final v = await servicePickDate(
                  c,
                  start,
                  past: true,
                  time: true,
                );
                if (v != null && mounted) setState(() => start = v);
              },
              child: Text('Début : ${serviceDateTime(start)}'),
            ),
            OutlinedButton(
              onPressed: () async {
                final v = await servicePickDate(c, end, past: true, time: true);
                if (v != null && mounted) setState(() => end = v);
              },
              child: Text('Fin : ${serviceDateTime(end)}'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('Fermer'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                final ok = await eventAction(
                  c,
                  () => c.read<EventsStore>().activities.saveActivity(
                    EventActivity(
                      id: widget.activity?.id ?? 0,
                      eventId: widget.event.id,
                      title: title.text,
                      description: description.text,
                      startTime: start,
                      endTime: end,
                    ),
                    creating: widget.activity == null,
                  ),
                );
                if (!mounted || !c.mounted) return;
                setState(() => busy = false);
                if (ok) Navigator.pop(c);
              },
        child: const Text('Enregistrer l’activité'),
      ),
    ],
  );
}

class AdminVolunteerTasksScreen extends StatelessWidget {
  const AdminVolunteerTasksScreen({super.key, required this.eventId});
  final int eventId;
  @override
  Widget build(
    BuildContext c,
  ) => EventsView<(Event, List<VolunteerTask>, List<EventRegistration>)>(
    load: (s) async => (
      await s.events.getEvent(eventId),
      await s.tasks.getTasks(eventId: eventId),
      await s.registrations.eligibleVolunteers(eventId),
    ),
    builder: (c, data) {
      final (e, tasks, volunteers) = data;
      final editable =
          e.status == EventStatus.DRAFT || e.status == EventStatus.PUBLISHED;
      return EventsPage(
        title: 'Gestion des tâches bénévoles',
        children: [
          Text(e.title),
          if (editable)
            FilledButton(
              onPressed: () => showDialog<void>(
                context: c,
                builder: (_) =>
                    TaskEditor(eventId: eventId, volunteers: volunteers),
              ),
              child: const Text('Créer une tâche'),
            ),
          const Text(
            'Affectation réservée aux bénévoles confirmés avec un compte actif. Leur présence pointée conserve cette éligibilité.',
          ),
          if (tasks.isEmpty) const Text('Aucune tâche.'),
          for (final t in tasks)
            eventCard([
              Text(t.title, style: Theme.of(c).textTheme.titleMedium),
              Text(t.description),
              serviceBadge(t.status.label),
              Text(
                t.assignedUserId == null
                    ? 'Non attribuée'
                    : 'Bénévole : ${volunteers.where((r) => r.userId == t.assignedUserId).firstOrNull?.userName ?? t.assignedUserId}',
              ),
              if (editable)
                OutlinedButton(
                  onPressed: () => showDialog<void>(
                    context: c,
                    builder: (_) => TaskEditor(
                      eventId: eventId,
                      volunteers: volunteers,
                      task: t,
                    ),
                  ),
                  child: const Text('Modifier / affecter'),
                ),
            ]),
        ],
      );
    },
  );
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({
    super.key,
    required this.eventId,
    required this.volunteers,
    this.task,
  });
  final int eventId;
  final List<EventRegistration> volunteers;
  final VolunteerTask? task;
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late final title = TextEditingController(text: widget.task?.title),
      description = TextEditingController(text: widget.task?.description);
  late String? assigned = widget.task?.assignedUserId;
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('Tâche bénévole'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            serviceField(title, 'Titre de la tâche'),
            const SizedBox(height: 12),
            serviceField(description, 'Description de la tâche', lines: 3),
            const SizedBox(height: 12),
            serviceDropdown<String>(
              assigned,
              ['', ...widget.volunteers.map((r) => r.userId)],
              'Bénévole affecté',
              (id) => id.isEmpty
                  ? 'Non attribuée'
                  : widget.volunteers
                        .firstWhere((r) => r.userId == id)
                        .userName,
              (v) => setState(() => assigned = v == '' ? null : v),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('Fermer'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                final ok = await eventAction(
                  c,
                  () => c.read<EventsStore>().tasks.saveTask(
                    VolunteerTask(
                      id: widget.task?.id ?? 0,
                      eventId: widget.eventId,
                      title: title.text,
                      description: description.text,
                      assignedUserId: assigned,
                      status:
                          widget.task?.status ?? VolunteerTaskStatus.AVAILABLE,
                    ),
                    creating: widget.task == null,
                  ),
                );
                if (!mounted || !c.mounted) return;
                setState(() => busy = false);
                if (ok) Navigator.pop(c);
              },
        child: const Text('Enregistrer la tâche'),
      ),
    ],
  );
}

class AdminEventReportScreen extends StatelessWidget {
  const AdminEventReportScreen({super.key, required this.eventId});
  final int eventId;
  @override
  Widget build(BuildContext c) =>
      EventsView<(Event, EventReport?, List<EventRegistration>)>(
        load: (s) async => (
          await s.events.getEvent(eventId),
          await s.reports.getReport(eventId),
          await s.registrations.getRegistrations(eventId: eventId),
        ),
        builder: (c, data) => ReportEditor(
          key: ValueKey('${data.$1.id}/${data.$2?.createdAt}'),
          event: data.$1,
          report: data.$2,
          registrations: data.$3,
        ),
      );
}

class ReportEditor extends StatefulWidget {
  const ReportEditor({
    super.key,
    required this.event,
    required this.report,
    required this.registrations,
  });
  final Event event;
  final EventReport? report;
  final List<EventRegistration> registrations;
  @override
  State<ReportEditor> createState() => _ReportEditorState();
}

class _ReportEditorState extends State<ReportEditor> {
  late final description = TextEditingController(
    text: widget.report?.description,
  );
  final photos = <Uint8List>[];
  bool busy = false;
  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> save(bool publish) async {
    if (publish &&
        !await serviceConfirm(
          context,
          'Publier ce bilan ? Les chiffres proviennent des présences pointées et le bilan publié sera figé.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    await eventAction(
      context,
      () => context.read<EventsStore>().reports.saveReport(
        widget.event.id,
        description.text,
        photos: photos,
        publish: publish,
      ),
    );
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    final present = widget.registrations.where(
      (r) => r.status == RegistrationStatus.ATTENDED,
    );
    final published = widget.report?.published ?? false;
    return EventsPage(
      title: 'Bilan après événement',
      children: [
        Text(widget.event.title, style: Theme.of(c).textTheme.titleLarge),
        Text(
          'Participants présents : ${present.where((r) => r.type == RegistrationType.PARTICIPANT).length}',
        ),
        Text(
          'Bénévoles présents : ${present.where((r) => r.type == RegistrationType.VOLUNTEER).length}',
        ),
        const Text(
          'Présences calculées automatiquement, sans chiffres saisis ni statistiques fictives.',
        ),
        if (widget.event.status != EventStatus.COMPLETED)
          const Text(
            'Le bilan peut être enregistré après la fin et la clôture de l’événement.',
          )
        else if (published) ...[
          serviceBadge('Bilan publié et figé'),
          Text(widget.report!.description),
          serviceLink(
            c,
            'Voir le bilan public',
            '/events/${widget.event.id}/report',
          ),
        ] else ...[
          serviceField(description, 'Description du bilan', lines: 6),
          ServicePhotoPicker(
            onChanged: (b) {
              if (b != null) setState(() => photos.add(b));
            },
          ),
          Text(
            '${photos.length} nouvelle(s) photo(s) • six photos maximum au total',
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: busy ? null : () => save(false),
                child: const Text('Enregistrer le brouillon du bilan'),
              ),
              FilledButton(
                onPressed: busy ? null : () => save(true),
                child: const Text('Publier le bilan'),
              ),
            ],
          ),
        ],
        for (final ref in widget.report?.photos ?? <String>[])
          EventPhoto(widget.event.id, reference: ref),
        for (var i = 0; i < photos.length; i++)
          eventCard([
            Image.memory(photos[i], height: 120, fit: BoxFit.contain),
            TextButton(
              onPressed: () => setState(() => photos.removeAt(i)),
              child: const Text('Retirer cette photo'),
            ),
          ]),
      ],
    );
  }
}
