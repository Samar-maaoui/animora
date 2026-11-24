import '../../../core/widgets/guarded_form.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../widgets/reports_widgets.dart';
import '../widgets/report_map.dart';
import '../services/report_privacy.dart';
import '../models/signalement.dart';
import '../models/annonce.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String search = '';
  ReportType? type;
  ReportStatus? status;
  int? urgency;
  @override
  Widget build(BuildContext c) => ReportsView(
    load: (r) => r.getReports(),
    builder: (c, items) {
      final filtered = items
          .where(
            (r) =>
                (type == null || r.type == type) &&
                (status == null || r.status == status) &&
                (urgency == null || r.urgencyLevel == urgency) &&
                r.description.toLowerCase().contains(search.toLowerCase()),
          )
          .toList();
      return ReportsPage(
        title: 'Signalements',
        children: [
          const Text(
            'Un animal a besoin d’aide ?',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Partagez une observation et aidez à retrouver les animaux de votre quartier. En cas de danger immédiat, contactez les services locaux compétents.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              routeButton(c, 'Nouveau signalement', '/reports/new'),
              routeButton(c, 'Perdus / trouvés', '/lost-found'),
              routeButton(c, 'Correspondances', '/matches'),
              routeButton(c, 'Mes réclamations', '/claims'),
              routeButton(c, 'Retrouvailles', '/reunion-stories'),
              if (reportsAdmin(c))
                routeButton(c, 'Modération', '/admin/reports'),
            ],
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Rechercher un signalement',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => search = v),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Tous les types'),
                selected: type == null,
                onSelected: (_) => setState(() => type = null),
              ),
              ...ReportType.values.map(
                (t) => FilterChip(
                  label: Text(t.label),
                  selected: t == type,
                  onSelected: (_) => setState(() => type = t),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Tous les statuts'),
                selected: status == null,
                onSelected: (_) => setState(() => status = null),
              ),
              ...ReportStatus.values.map(
                (s) => FilterChip(
                  label: Text(s.label),
                  selected: s == status,
                  onSelected: (_) => setState(() => status = s),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Toutes les urgences'),
                selected: urgency == null,
                onSelected: (_) => setState(() => urgency = null),
              ),
              ...[1, 2, 3].map(
                (n) => FilterChip(
                  label: Text('Urgence $n/3'),
                  selected: urgency == n,
                  onSelected: (_) => setState(() => urgency = n),
                ),
              ),
            ],
          ),
          Text('${filtered.length} signalement(s)'),
          if (filtered.isEmpty)
            const Text('Aucun signalement pour ces critères.'),
          ...filtered.map(
            (r) => Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (r.photo != null)
                    SizedBox(height: 130, child: ReportPhoto(r.photo)),
                  ListTile(
                    isThreeLine: true,
                    leading: Icon(
                      r.urgencyLevel == 3 ? Icons.warning_amber : Icons.pets,
                      color: const Color(0xFFF59E0B),
                    ),
                    title: Text(r.type.label),
                    subtitle: Text(
                      '${r.description}\n${r.status.label} • Urgence ${r.urgencyLevel}/3 • ${reportDate(r.createdAt)}\n${r.latitude == null ? 'Position non renseignée' : 'Zone approximative : ${r.latitude}, ${r.longitude}'}',
                    ),
                    onTap: () => c.push('/reports/${r.id}'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class ReportDetailsScreen extends StatelessWidget {
  const ReportDetailsScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext c) => ReportsView(
    load: (r) async => (await r.getReport(id), await r.getConfirmations(id)),
    builder: (c, data) {
      final r = data.$1;
      final confirmations = data.$2;
      final uid = c.watch<AuthSession>().currentUser?.id;
      return ReportsPage(
        title: r.type.label,
        children: [
          ReportPhoto(r.photo),
          Text(r.description, style: const TextStyle(fontSize: 20)),
          Text(
            '${r.status.label} • Urgence ${r.urgencyLevel}/3 • ${reportDate(r.createdAt)}',
          ),
          if (r.latitude != null && r.longitude != null)
            ReportMap(latitude: r.latitude!, longitude: r.longitude!),
          Text(
            '${confirmations.length} confirmation(s) • ces observations ne remplacent pas une vérification.',
          ),
          if (r.userId != uid &&
              !confirmations.any((x) => x.userId == uid) &&
              ![
                ReportStatus.RESOLVED,
                ReportStatus.REJECTED,
              ].contains(r.status))
            FilledButton(
              onPressed: () async {
                if (await reportConfirm(
                  c,
                  'Confirmez uniquement si vous avez personnellement observé cet animal.',
                )) {
                  if (c.mounted) {
                    await reportAction(
                      c,
                      () => c.read<LocalReportsRepository>().confirmReport(id),
                    );
                  }
                }
              },
              child: const Text('Confirmer ce signalement'),
            ),
          ...confirmations.map(
            (x) => Text(
              'Observation du ${reportDate(x.date)}${x.comment == null ? '' : ' • ${x.comment}'}',
            ),
          ),
          if (reportsAdmin(c))
            Wrap(
              spacing: 8,
              children: ReportStatus.values
                  .where((s) => s != r.status && s != ReportStatus.NEW)
                  .map(
                    (s) => OutlinedButton(
                      onPressed: () async {
                        if (await reportConfirm(
                          c,
                          'Passer le signalement au statut « ${s.label} » ?',
                        )) {
                          if (c.mounted) {
                            await reportAction(
                              c,
                              () => c
                                  .read<LocalReportsRepository>()
                                  .moderateReport(id, s),
                            );
                          }
                        }
                      },
                      child: Text(s.label),
                    ),
                  )
                  .toList(),
            ),
        ],
      );
    },
  );
}

class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({super.key});
  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final description = TextEditingController(),
      lat = TextEditingController(),
      lon = TextEditingController();
  ReportType type = ReportType.STRAY_ANIMAL;
  int urgency = 1;
  bool consent = false, busy = false;
  Uint8List? photo;
  @override
  void dispose() {
    description.dispose();
    lat.dispose();
    lon.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => busy = true);
    final repo = context.read<LocalReportsRepository>();
    int? id;
    final ok = await reportAction(context, () async {
      final latitude = coordinate(lat), longitude = coordinate(lon);
      ReportPrivacy.publish(latitude, longitude, consent: consent);
      final ref = photo == null ? null : await repo.savePhoto(photo!);
      final r = await repo.createReport(
        Signalement(
          id: 0,
          userId: '',
          type: type,
          description: description.text,
          urgencyLevel: urgency,
          status: ReportStatus.NEW,
          createdAt: DateTime.now(),
          photo: ref,
          latitude: latitude,
          longitude: longitude,
        ),
        locationConsent: consent,
      );
      id = r.id;
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) GuardedForm.savedGo(context, '/reports/$id');
  }

  @override
  Widget build(BuildContext c) => ReportsPage(
    title: 'Nouveau signalement',
    children: [
      dropdown(
        type,
        ReportType.values,
        'Type de signalement',
        (t) => t.label,
        (v) => setState(() => type = v!),
      ),
      field(description, 'Description (10 caractères minimum)', lines: 4),
      dropdown(
        urgency,
        [1, 2, 3],
        'Niveau d’urgence',
        (n) => ['Faible', 'Modérée', 'Élevée'][n - 1],
        (v) => setState(() => urgency = v!),
      ),
      ReportPhotoPicker(onChanged: (v) => photo = v),
      LocationFields(
        latitude: lat,
        longitude: lon,
        onConsent: (v) => consent = v,
      ),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(busy ? 'Publication…' : 'Publier le signalement'),
      ),
    ],
  );
}

class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({super.key});
  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  AnnouncementType? type;
  AnnouncementStatus? status = AnnouncementStatus.ACTIVE;
  String search = '';
  bool mine = false;
  @override
  Widget build(BuildContext c) => ReportsView(
    load: (r) => r.getAnnouncements(),
    builder: (c, items) {
      final uid = c.watch<AuthSession>().currentUser?.id;
      final filtered = items
          .where(
            (a) =>
                (type == null || a.type == type) &&
                (status == null || a.status == status) &&
                (!mine || a.userId == uid) &&
                '${a.species} ${a.breed ?? ''} ${a.color} ${a.description}'
                    .toLowerCase()
                    .contains(search.toLowerCase()),
          )
          .toList();
      return ReportsPage(
        title: 'Animaux perdus / trouvés',
        children: [
          const Text(
            'Chaque observation peut aider.',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            children: [
              routeButton(c, 'Publier une annonce', '/lost-found/new'),
              routeButton(c, 'Correspondances', '/matches'),
              routeButton(c, 'Mes réclamations', '/claims'),
              routeButton(c, 'Signalements', '/reports'),
            ],
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Espèce, race, couleur ou description',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => search = v),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Tous'),
                selected: type == null,
                onSelected: (_) => setState(() => type = null),
              ),
              ...AnnouncementType.values.map(
                (t) => FilterChip(
                  label: Text(t.label),
                  selected: type == t,
                  onSelected: (_) => setState(() => type = t),
                ),
              ),
              FilterChip(
                label: const Text('Mes annonces'),
                selected: mine,
                onSelected: (v) => setState(() => mine = v),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Tous les statuts'),
                selected: status == null,
                onSelected: (_) => setState(() => status = null),
              ),
              ...AnnouncementStatus.values.map(
                (s) => FilterChip(
                  label: Text(s.label),
                  selected: status == s,
                  onSelected: (_) => setState(() => status = s),
                ),
              ),
            ],
          ),
          if (filtered.isEmpty) const Text('Aucune annonce pour ces critères.'),
          ...filtered.map(
            (a) => Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (a.photo != null)
                    SizedBox(height: 130, child: ReportPhoto(a.photo)),
                  ListTile(
                    title: Text('${a.type.label} • ${a.species} • ${a.color}'),
                    subtitle: Text(
                      '${a.description}\n${a.status.label}${a.hidden ? ' • Masquée' : ''} • ${reportDate(a.date)}',
                    ),
                    isThreeLine: true,
                    onTap: () => c.push('/lost-found/${a.id}'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class AnnouncementDetailsScreen extends StatelessWidget {
  const AnnouncementDetailsScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext c) => ReportsView(
    load: (r) async => (await r.getAnnouncement(id), await r.getSearchZone(id)),
    builder: (c, data) {
      final a = data.$1;
      final zone = data.$2;
      final own = c.watch<AuthSession>().currentUser?.id == a.userId;
      final active = a.status == AnnouncementStatus.ACTIVE && !a.hidden;
      return ReportsPage(
        title: '${a.type.label} • ${a.species}',
        children: [
          ReportPhoto(a.photo),
          Text(a.description, style: const TextStyle(fontSize: 22)),
          Text(
            'Couleur : ${a.color}\nRace : ${a.breed ?? 'Non précisée'}\nSignes distinctifs : ${a.distinguishingSigns ?? 'Non précisés'}\nDate : ${reportDate(a.date)}\nStatut : ${a.status.label}${a.hidden ? ' • Masquée' : ''}',
          ),
          if (zone != null)
            ReportMap(
              latitude: zone.latitude,
              longitude: zone.longitude,
              radius: zone.radius,
            )
          else if (a.latitude != null && a.longitude != null)
            ReportMap(latitude: a.latitude!, longitude: a.longitude!),
          if (zone != null)
            Text(
              'Zone de recherche : rayon ${(zone.radius / 1000).toStringAsFixed(1)} km.',
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              routeButton(
                c,
                'Ajouter un témoignage',
                '/lost-found/$id/testimonies',
              ),
              if (own && a.status == AnnouncementStatus.ACTIVE)
                routeButton(c, 'Modifier mon annonce', '/lost-found/$id/edit'),
              if (own && active && a.type == AnnouncementType.LOST)
                routeButton(
                  c,
                  'Définir la zone de recherche',
                  '/lost-found/$id/zone',
                ),
              if (!own && active && a.type == AnnouncementType.FOUND)
                routeButton(c, 'C’est peut-être mon animal', '/claims/new/$id'),
              if (own && a.status == AnnouncementStatus.ACTIVE)
                OutlinedButton(
                  onPressed: () async {
                    if (await reportConfirm(
                      c,
                      'Clôturer cette annonce ? Les réclamations en attente seront rejetées.',
                    )) {
                      if (c.mounted) {
                        await reportAction(
                          c,
                          () => c
                              .read<LocalReportsRepository>()
                              .closeAnnouncement(id),
                        );
                      }
                    }
                  },
                  child: const Text('Clôturer mon annonce'),
                ),
              if (reportsAdmin(c))
                OutlinedButton(
                  onPressed: () async {
                    if (await reportConfirm(
                      c,
                      a.hidden
                          ? 'Rendre cette annonce visible ?'
                          : 'Masquer cette annonce ?',
                    )) {
                      if (c.mounted) {
                        await reportAction(
                          c,
                          () => c
                              .read<LocalReportsRepository>()
                              .moderateAnnouncement(id, !a.hidden),
                        );
                      }
                    }
                  },
                  child: Text(a.hidden ? 'Rendre visible' : 'Masquer'),
                ),
            ],
          ),
        ],
      );
    },
  );
}

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key, this.initial});
  final Annonce? initial;
  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  late final species = TextEditingController(text: widget.initial?.species),
      breed = TextEditingController(text: widget.initial?.breed),
      color = TextEditingController(text: widget.initial?.color),
      description = TextEditingController(text: widget.initial?.description),
      signs = TextEditingController(text: widget.initial?.distinguishingSigns),
      lat = TextEditingController(text: widget.initial?.latitude?.toString()),
      lon = TextEditingController(text: widget.initial?.longitude?.toString());
  late AnnouncementType type = widget.initial?.type ?? AnnouncementType.LOST;
  late DateTime date = widget.initial?.date ?? DateTime.now();
  bool consent = false, busy = false;
  Uint8List? photo;
  @override
  void dispose() {
    for (final c in [species, breed, color, description, signs, lat, lon]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => busy = true);
    final repo = context.read<LocalReportsRepository>();
    int? id;
    final ok = await reportAction(context, () async {
      final latitude = coordinate(lat), longitude = coordinate(lon);
      ReportPrivacy.publish(latitude, longitude, consent: consent);
      final ref = photo == null
          ? widget.initial?.photo
          : await repo.savePhoto(photo!);
      final a = await repo.saveAnnouncement(
        Annonce(
          id: widget.initial?.id ?? 0,
          userId: '',
          type: type,
          species: species.text,
          breed: breed.text.trim().isEmpty ? null : breed.text.trim(),
          color: color.text,
          description: description.text,
          distinguishingSigns: signs.text.trim().isEmpty
              ? null
              : signs.text.trim(),
          date: date,
          status: AnnouncementStatus.ACTIVE,
          photo: ref,
          latitude: latitude,
          longitude: longitude,
        ),
        creating: widget.initial == null,
        locationConsent: consent,
      );
      id = a.id;
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) GuardedForm.savedGo(context, '/lost-found/$id');
  }

  @override
  Widget build(BuildContext c) => ReportsPage(
    title: widget.initial == null
        ? 'Publier une annonce'
        : 'Modifier mon annonce',
    children: [
      if (widget.initial == null)
        dropdown(
          type,
          AnnouncementType.values,
          'Perdu ou trouvé',
          (v) => v.label,
          (v) => setState(() => type = v!),
        ),
      field(species, 'Espèce'),
      field(breed, 'Race (facultative)'),
      field(color, 'Couleur'),
      field(description, 'Description (10 caractères minimum)', lines: 4),
      field(signs, 'Signes distinctifs (facultatifs)', lines: 2),
      OutlinedButton(
        onPressed: () async {
          final d = await showDatePicker(
            context: c,
            initialDate: date,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (d != null && mounted) setState(() => date = d);
        },
        child: Text('Date : ${reportDate(date)}'),
      ),
      ReportPhotoPicker(
        existing: widget.initial?.photo,
        onChanged: (v) => photo = v,
      ),
      LocationFields(
        latitude: lat,
        longitude: lon,
        onConsent: (v) => consent = v,
      ),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(busy ? 'Enregistrement…' : 'Enregistrer l’annonce'),
      ),
    ],
  );
}

class AnnouncementEditScreen extends StatelessWidget {
  const AnnouncementEditScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext c) => ReportsView(
    load: (r) => r.getAnnouncement(id),
    builder: (c, a) {
      if (a.userId != c.watch<AuthSession>().currentUser?.id ||
          a.status != AnnouncementStatus.ACTIVE) {
        return const ReportsPage(
          title: 'Accès refusé',
          children: [Text('Cette annonce ne peut pas être modifiée.')],
        );
      }
      return CreateAnnouncementScreen(key: ValueKey(a.id), initial: a);
    },
  );
}
