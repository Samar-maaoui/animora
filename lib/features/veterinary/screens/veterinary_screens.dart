import '../../../core/widgets/guarded_form.dart';
import '../widgets/nearby_clinics.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../animal_services/widgets/services_widgets.dart';
import '../../users/models/user.dart';
import '../models/availability.dart';
import '../models/veterinary_appointment.dart';

class VeterinariansScreen extends StatefulWidget {
  const VeterinariansScreen({super.key});
  @override
  State<VeterinariansScreen> createState() => _VeterinariansScreenState();
}

class _VeterinariansScreenState extends State<VeterinariansScreen> {
  String search = '', city = '';
  DateTime? date;
  @override
  Widget build(BuildContext c) => ServiceView(
    load: (s) async {
      final users = await s.veterinary.getVeterinarians();
      return [
        for (final user in users)
          (user, await s.availability.getAvailability(user.id)),
      ];
    },
    builder: (c, rows) {
      final filtered = rows
          .where(
            (e) =>
                e.$1.fullName.toLowerCase().contains(
                  search.toLowerCase().trim(),
                ) &&
                (city.isEmpty || e.$1.city == city) &&
                (date == null ||
                    e.$2.any((a) => serviceDate(a.date) == serviceDate(date!))),
          )
          .toList();
      final cities = rows.map((e) => e.$1.city).toSet().toList()..sort();
      return ServicePage(
        title: 'Vétérinaires',
        children: [
          const Text(
            'Prenez soin de votre compagnon',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              serviceLink(c, 'Mes rendez-vous', '/veterinary/my-appointments'),
              serviceLink(c, 'Carnets de santé', '/health'),
              if (serviceProfile(c) == UserProfile.veterinarian)
                serviceLink(
                  c,
                  'Mon espace vétérinaire',
                  '/veterinary/dashboard',
                ),
            ],
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Rechercher un vétérinaire',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => search = v),
          ),
          serviceDropdown(
            city,
            ['', ...cities],
            'Ville',
            (s) => s.isEmpty ? 'Toutes les villes' : s,
            (v) => setState(() => city = v!),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final d = await servicePickDate(c, date ?? DateTime.now());
                  if (d != null && mounted) setState(() => date = d);
                },
                child: Text(
                  date == null
                      ? 'Filtrer par date disponible'
                      : serviceDate(date!),
                ),
              ),
              if (date != null)
                TextButton(
                  onPressed: () => setState(() => date = null),
                  child: const Text('Effacer la date'),
                ),
            ],
          ),
          if (filtered.isEmpty)
            const Text('Aucun vétérinaire actif ne correspond à ces critères.'),
          ...filtered.map(
            (e) => serviceCard([
              ProviderIdentity(e.$1),
              Text('${e.$2.length} créneau(x) disponible(s)'),
              if (e.$2.isNotEmpty)
                Text(
                  'Prochain : ${serviceDate(e.$2.first.date)} • ${serviceTime(e.$2.first.startTime)}',
                ),
              Wrap(
                spacing: 8,
                children: [
                  serviceLink(c, 'Voir le profil', '/veterinary/${e.$1.id}'),
                  serviceLink(
                    c,
                    'Prendre rendez-vous',
                    '/veterinary/book/${e.$1.id}',
                  ),
                ],
              ),
            ]),
          ),
          const NearbyClinics(),
        ],
      );
    },
  );
}

class VeterinarianProfileScreen extends StatelessWidget {
  const VeterinarianProfileScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext c) => ServiceView(
    load: (s) async {
      final user = (await s.veterinary.getVeterinarians())
          .where((u) => u.id == id)
          .firstOrNull;
      if (user == null) {
        throw const ServicesFailure('Vétérinaire actif introuvable.');
      }
      return (user, await s.availability.getAvailability(id));
    },
    builder: (c, data) => ServicePage(
      title: 'Profil vétérinaire',
      children: [
        ProviderIdentity(data.$1),
        const Text(
          'Créneaux disponibles',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        if (data.$2.isEmpty) const Text('Aucun créneau publié pour le moment.'),
        ...data.$2.map(
          (a) => serviceCard([
            Text(
              '${serviceDate(a.date)} • ${serviceTime(a.startTime)} – ${serviceTime(a.endTime)}',
            ),
          ]),
        ),
        serviceLink(c, 'Prendre rendez-vous', '/veterinary/book/$id'),
      ],
    ),
  );
}

class ProviderIdentity extends StatelessWidget {
  const ProviderIdentity(this.user, {super.key});
  final User user;
  @override
  Widget build(BuildContext c) => Row(
    children: [
      ServiceAvatar(user),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            Text(user.city),
          ],
        ),
      ),
    ],
  );
}

class VeterinarianAvailabilityScreen extends StatelessWidget {
  const VeterinarianAvailabilityScreen({super.key});
  @override
  Widget build(BuildContext c) {
    if (serviceProfile(c) != UserProfile.veterinarian) {
      return const ServicePage(
        title: 'Accès refusé',
        children: [Text('Cet espace est réservé aux vétérinaires actifs.')],
      );
    }
    final id = c.watch<AuthSession>().currentUser!.id;
    return ServiceView(
      load: (s) => s.availability.getAvailability(id, includeReserved: true),
      builder: (c, slots) => ServicePage(
        title: 'Mes disponibilités',
        children: [
          FilledButton.icon(
            onPressed: () => showDialog<void>(
              context: c,
              builder: (_) => const AvailabilityEditor(),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une disponibilité'),
          ),
          if (slots.isEmpty)
            const Text(
              'Aucun créneau. Publiez vos disponibilités pour recevoir des demandes.',
            ),
          ...slots.map(
            (a) => serviceCard([
              Text(
                '${serviceDate(a.date)} • ${serviceTime(a.startTime)} – ${serviceTime(a.endTime)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              serviceBadge(a.isFree ? 'Libre' : 'Réservé / archivé'),
              if (a.isFree)
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => showDialog<void>(
                        context: c,
                        builder: (_) => AvailabilityEditor(initial: a),
                      ),
                      child: const Text('Modifier'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        if (await serviceConfirm(
                          c,
                          'Supprimer ce créneau libre ?',
                        )) {
                          if (c.mounted) {
                            await serviceAction(
                              c,
                              () => c
                                  .read<ServicesStore>()
                                  .availability
                                  .deleteAvailability(a.id),
                            );
                          }
                        }
                      },
                      child: const Text('Supprimer'),
                    ),
                  ],
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class AvailabilityEditor extends StatefulWidget {
  const AvailabilityEditor({super.key, this.initial});
  final Availability? initial;
  @override
  State<AvailabilityEditor> createState() => _AvailabilityEditorState();
}

class _AvailabilityEditorState extends State<AvailabilityEditor> {
  late DateTime date =
      widget.initial?.date ?? DateTime.now().add(const Duration(days: 1));
  late int start = widget.initial?.startTime ?? 540,
      end = widget.initial?.endTime ?? 600;
  bool busy = false;
  Future<void> pickTime(bool first) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (first ? start : end) ~/ 60,
        minute: (first ? start : end) % 60,
      ),
    );
    if (t != null && mounted) {
      setState(() {
        if (first) {
          start = t.hour * 60 + t.minute;
        } else {
          end = t.hour * 60 + t.minute;
        }
      });
    }
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: Text(
      widget.initial == null
          ? 'Ajouter une disponibilité'
          : 'Modifier le créneau',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: () async {
              final d = await servicePickDate(c, date);
              if (d != null && mounted) setState(() => date = d);
            },
            child: Text('Date : ${serviceDate(date)}'),
          ),
          OutlinedButton(
            onPressed: () => pickTime(true),
            child: Text('Début : ${serviceTime(start)}'),
          ),
          OutlinedButton(
            onPressed: () => pickTime(false),
            child: Text('Fin : ${serviceTime(end)}'),
          ),
          const Text(
            'Les créneaux ne peuvent pas se chevaucher. Une demande en attente réserve déjà le créneau.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(c),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                final ok = await serviceAction(
                  c,
                  () => c.read<ServicesStore>().availability.saveAvailability(
                    Availability(
                      id: widget.initial?.id ?? 0,
                      veterinarianUserId: '',
                      date: date,
                      startTime: start,
                      endTime: end,
                      isFree: true,
                    ),
                    creating: widget.initial == null,
                  ),
                );
                if (!mounted || !c.mounted) return;
                setState(() => busy = false);
                if (ok && c.mounted) Navigator.pop(c);
              },
        child: const Text('Enregistrer le créneau'),
      ),
    ],
  );
}

class BookVeterinaryAppointmentScreen extends StatefulWidget {
  const BookVeterinaryAppointmentScreen({
    super.key,
    required this.veterinarianId,
  });
  final String veterinarianId;
  @override
  State<BookVeterinaryAppointmentScreen> createState() =>
      _BookVeterinaryAppointmentScreenState();
}

class _BookVeterinaryAppointmentScreenState
    extends State<BookVeterinaryAppointmentScreen> {
  int? slot, animal;
  final reason = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ServiceView(
    load: (s) async {
      final user = (await s.veterinary.getVeterinarians())
          .where((u) => u.id == widget.veterinarianId)
          .firstOrNull;
      if (user == null) {
        throw const ServicesFailure('Vétérinaire indisponible.');
      }
      return (
        user,
        await s.availability.getAvailability(user.id),
        await s.veterinary.getResponsibleAnimals(),
      );
    },
    builder: (c, data) {
      final slots = data.$2, animals = data.$3;
      return ServicePage(
        title: 'Prendre rendez-vous',
        children: [
          ProviderIdentity(data.$1),
          if (slots.isEmpty)
            const Text(
              'Aucun créneau disponible. Réessayez après la publication de nouvelles disponibilités.',
            ),
          if (animals.isEmpty) ...[
            const Text(
              'Aucun animal sous votre responsabilité. Une adoption signée ou un accueil actif est nécessaire.',
            ),
            serviceLink(c, 'Mes adoptions', '/adoptions/my'),
          ],
          if (slots.isNotEmpty && animals.isNotEmpty) ...[
            serviceDropdown(slot, slots.map((s) => s.id).toList(), 'Créneau', (
              id,
            ) {
              final s = slots.firstWhere((s) => s.id == id);
              return '${serviceDate(s.date)} • ${serviceTime(s.startTime)} – ${serviceTime(s.endTime)}';
            }, (v) => setState(() => slot = v)),
            serviceDropdown(
              animal,
              animals.map((a) => a.id).toList(),
              'Animal',
              (id) => animals.firstWhere((a) => a.id == id).name,
              (v) => setState(() => animal = v),
            ),
            serviceField(reason, 'Motif (10 caractères minimum)', lines: 4),
            const Text(
              'La demande est transmise localement au vétérinaire. Le créneau est bloqué en attendant sa décision.',
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (slot == null || animal == null) {
                        await serviceAction(
                          c,
                          () async => throw const ServicesFailure(
                            'Choisissez un créneau et un animal.',
                          ),
                        );
                        return;
                      }
                      if (!await serviceConfirm(
                        c,
                        'Confirmer cette demande de rendez-vous ?',
                      )) {
                        return;
                      }
                      if (!mounted || !c.mounted) return;
                      setState(() => busy = true);
                      final ok = await serviceAction(
                        c,
                        () => c
                            .read<ServicesStore>()
                            .appointments
                            .bookAppointment(slot!, animal!, reason.text),
                      );
                      if (!mounted) return;
                      setState(() => busy = false);
                      if (ok && c.mounted) {
                        GuardedForm.savedGo(c, '/veterinary/my-appointments');
                      }
                    },
              child: const Text('Demander le rendez-vous'),
            ),
          ],
        ],
      );
    },
  );
}

class MyVeterinaryAppointmentsScreen extends StatelessWidget {
  const MyVeterinaryAppointmentsScreen({super.key});
  @override
  Widget build(BuildContext c) => ServiceView(
    load: (s) => s.appointments.getAppointments(),
    builder: (c, all) {
      final id = c.watch<AuthSession>().currentUser?.id;
      final appointments = all.where((a) => a.clientUserId == id).toList();
      return ServicePage(
        title: 'Mes rendez-vous vétérinaires',
        children: [
          serviceLink(c, 'Trouver un vétérinaire', '/veterinary'),
          if (appointments.isEmpty)
            const Text('Vous n’avez aucun rendez-vous.'),
          ...appointments.map((a) => AppointmentCard(a)),
        ],
      );
    },
  );
}

class VeterinarianDashboardScreen extends StatelessWidget {
  const VeterinarianDashboardScreen({super.key});
  @override
  Widget build(BuildContext c) {
    if (serviceProfile(c) != UserProfile.veterinarian) {
      return const ServicePage(
        title: 'Accès refusé',
        children: [Text('Cet espace est réservé aux vétérinaires actifs.')],
      );
    }
    final id = c.watch<AuthSession>().currentUser!.id;
    return ServiceView(
      load: (s) => s.appointments.getAppointments(),
      builder: (c, all) {
        final rows = all.where((a) => a.veterinarianUserId == id).toList();
        final now = DateTime.now();
        return ServicePage(
          title: 'Mon espace vétérinaire',
          children: [
            OutlinedButton.icon(
              onPressed: () => c.read<ServicesStore>().refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser'),
            ),
            Wrap(
              spacing: 8,
              children: [
                serviceLink(
                  c,
                  'Gérer mes disponibilités',
                  '/veterinary/availability',
                ),
                serviceLink(c, 'Carnets de mes patients', '/health'),
                serviceLink(
                  c,
                  'Mes rendez-vous personnels',
                  '/veterinary/my-appointments',
                ),
              ],
            ),
            Text(
              '${rows.where((a) => a.status == AppointmentStatus.PENDING).length} en attente • ${rows.where((a) => a.status == AppointmentStatus.CONFIRMED).length} confirmés',
            ),
            Text(
              '${rows.where((a) => serviceDate(a.appointmentDate) == serviceDate(now) && ![AppointmentStatus.CANCELLED, AppointmentStatus.REJECTED].contains(a.status)).length} rendez-vous aujourd’hui',
            ),
            for (final group in [
              (
                'Demandes en attente',
                rows.where((a) => a.status == AppointmentStatus.PENDING),
              ),
              (
                'Rendez-vous confirmés',
                rows.where((a) => a.status == AppointmentStatus.CONFIRMED),
              ),
              (
                'Historique',
                rows.where(
                  (a) => ![
                    AppointmentStatus.PENDING,
                    AppointmentStatus.CONFIRMED,
                  ].contains(a.status),
                ),
              ),
            ]) ...[
              Text(
                group.$1,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (group.$2.isEmpty)
                const Text('Aucun rendez-vous dans cette section.'),
              ...group.$2.map((a) => AppointmentCard(a, professional: true)),
            ],
          ],
        );
      },
    );
  }
}

class AppointmentCard extends StatefulWidget {
  const AppointmentCard(
    this.appointment, {
    super.key,
    this.professional = false,
    this.readOnly = false,
  });
  final VeterinaryAppointment appointment;
  final bool professional, readOnly;
  @override
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard> {
  bool busy = false;
  Future<void> change(AppointmentStatus status) async {
    if (!await serviceConfirm(
      context,
      'Passer le rendez-vous au statut « ${status.label} » ?',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    await serviceAction(
      context,
      () => context.read<ServicesStore>().appointments.changeAppointmentStatus(
        widget.appointment.id,
        status,
      ),
    );
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    final a = widget.appointment;
    return serviceCard([
      Text(
        '${a.animalName} • ${a.veterinarianName}',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      if (widget.professional || widget.readOnly)
        Text('Responsable : ${a.clientName}'),
      Text(serviceDateTime(a.appointmentDate)),
      serviceBadge(a.status.label),
      Text('Motif : ${a.reason}'),
      if (a.notes?.isNotEmpty == true)
        Text('Notes de consultation : ${a.notes}'),
      if (!widget.readOnly)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.professional &&
                a.status == AppointmentStatus.PENDING) ...[
              FilledButton(
                onPressed: busy
                    ? null
                    : () => change(AppointmentStatus.CONFIRMED),
                child: const Text('Accepter le rendez-vous'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => change(AppointmentStatus.REJECTED),
                child: const Text('Refuser le rendez-vous'),
              ),
            ],
            if (widget.professional &&
                a.status == AppointmentStatus.CONFIRMED &&
                !a.appointmentDate.isAfter(DateTime.now()))
              FilledButton(
                onPressed: busy
                    ? null
                    : () => change(AppointmentStatus.COMPLETED),
                child: const Text('Terminer la consultation'),
              ),
            if ([
                  AppointmentStatus.PENDING,
                  AppointmentStatus.CONFIRMED,
                ].contains(a.status) &&
                a.appointmentDate.isAfter(DateTime.now()))
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => change(AppointmentStatus.CANCELLED),
                child: const Text('Annuler le rendez-vous'),
              ),
            if (widget.professional &&
                [
                  AppointmentStatus.CONFIRMED,
                  AppointmentStatus.COMPLETED,
                ].contains(a.status))
              OutlinedButton(
                onPressed: () => showDialog<void>(
                  context: c,
                  builder: (_) => ConsultationNotesEditor(a),
                ),
                child: const Text('Notes de consultation'),
              ),
            if ([
              AppointmentStatus.CONFIRMED,
              AppointmentStatus.COMPLETED,
            ].contains(a.status))
              serviceLink(
                c,
                'Carnet de santé',
                '/animals/${a.animalId}/health',
              ),
          ],
        ),
    ]);
  }
}

class ConsultationNotesEditor extends StatefulWidget {
  const ConsultationNotesEditor(this.appointment, {super.key});
  final VeterinaryAppointment appointment;
  @override
  State<ConsultationNotesEditor> createState() =>
      _ConsultationNotesEditorState();
}

class _ConsultationNotesEditorState extends State<ConsultationNotesEditor> {
  late final notes = TextEditingController(text: widget.appointment.notes);
  bool busy = false;
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('Notes de consultation privées'),
    content: SizedBox(
      width: 500,
      child: serviceField(notes, 'Notes (10 000 caractères maximum)', lines: 5),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(c),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                final ok = await serviceAction(
                  c,
                  () => c
                      .read<ServicesStore>()
                      .appointments
                      .saveConsultationNotes(widget.appointment.id, notes.text),
                );
                if (!mounted) return;
                setState(() => busy = false);
                if (ok && c.mounted) Navigator.pop(c);
              },
        child: const Text('Enregistrer les notes'),
      ),
    ],
  );
}
