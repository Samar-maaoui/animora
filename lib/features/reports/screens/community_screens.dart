import '../../../core/widgets/guarded_form.dart';
import '../models/reclamation.dart';
import '../models/correspondance.dart';
import '../models/annonce.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../widgets/reports_widgets.dart';
import '../widgets/report_map.dart';
import '../services/report_privacy.dart';

class TestimoniesScreen extends StatefulWidget {
  const TestimoniesScreen({super.key, required this.id});
  final int id;
  @override
  State<TestimoniesScreen> createState() => _TestimoniesScreenState();
}

class _TestimoniesScreenState extends State<TestimoniesScreen> {
  final comment = TextEditingController(),
      lat = TextEditingController(),
      lon = TextEditingController();
  DateTime date = DateTime.now();
  bool consent = false, busy = false;
  Uint8List? photo;
  int pickerKey = 0;
  @override
  void dispose() {
    comment.dispose();
    lat.dispose();
    lon.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => busy = true);
    final repo = context.read<LocalReportsRepository>();
    await reportAction(context, () async {
      final latitude = coordinate(lat), longitude = coordinate(lon);
      ReportPrivacy.publish(latitude, longitude, consent: consent);
      final ref = photo == null ? null : await repo.savePhoto(photo!);
      await repo.addTestimony(
        widget.id,
        comment.text,
        date,
        latitude: latitude,
        longitude: longitude,
        photo: ref,
        locationConsent: consent,
      );
      comment.clear();
      lat.clear();
      lon.clear();
      photo = null;
      consent = false;
      pickerKey++;
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => ReportsView(
    load: (r) async =>
        (await r.getAnnouncement(widget.id), await r.getTestimonies(widget.id)),
    builder: (c, data) => ReportsPage(
      title: 'Témoignages',
      children: [
        const Text(
          'Observations classées par date d’observation, de la plus ancienne à la plus récente.',
        ),
        if (data.$2.isEmpty) const Text('Aucun témoignage pour le moment.'),
        ...data.$2.map(
          (t) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(reportDate(t.date)),
                  Text(t.comment),
                  ReportPhoto(t.photo),
                  if (t.latitude != null && t.longitude != null)
                    ReportMap(latitude: t.latitude!, longitude: t.longitude!),
                ],
              ),
            ),
          ),
        ),
        if (data.$1.status == AnnouncementStatus.ACTIVE && !data.$1.hidden) ...[
          const Text(
            'Ajouter une observation',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          field(comment, 'Votre observation (10 caractères minimum)', lines: 4),
          OutlinedButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: c,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (d == null || !c.mounted) return;
              final time = await showTimePicker(
                context: c,
                initialTime: TimeOfDay.fromDateTime(date),
              );
              if (time != null && mounted) {
                setState(
                  () => date = DateTime(
                    d.year,
                    d.month,
                    d.day,
                    time.hour,
                    time.minute,
                  ),
                );
              }
            },
            child: Text('Observation : ${reportDate(date)}'),
          ),
          ReportPhotoPicker(
            key: ValueKey(pickerKey),
            onChanged: (v) => photo = v,
          ),
          LocationFields(
            key: ValueKey('location$pickerKey'),
            latitude: lat,
            longitude: lon,
            onConsent: (v) => consent = v,
          ),
          FilledButton(
            onPressed: busy ? null : submit,
            child: const Text('Publier le témoignage'),
          ),
        ],
      ],
    ),
  );
}

class SearchZoneScreen extends StatefulWidget {
  const SearchZoneScreen({super.key, required this.id});
  final int id;
  @override
  State<SearchZoneScreen> createState() => _SearchZoneScreenState();
}

class _SearchZoneScreenState extends State<SearchZoneScreen> {
  final lat = TextEditingController(), lon = TextEditingController();
  bool initialized = false, consent = false, busy = false;
  double radius = 3000;
  @override
  void dispose() {
    lat.dispose();
    lon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ReportsView(
    load: (r) async =>
        (await r.getAnnouncement(widget.id), await r.getSearchZone(widget.id)),
    builder: (c, data) {
      final a = data.$1;
      final zone = data.$2;
      if (a.userId != c.watch<AuthSession>().currentUser?.id ||
          a.type != AnnouncementType.LOST ||
          a.status != AnnouncementStatus.ACTIVE) {
        return const ReportsPage(
          title: 'Zone inaccessible',
          children: [
            Text(
              'Seul l’auteur d’une annonce active d’animal perdu peut définir sa zone.',
            ),
          ],
        );
      }
      if (!initialized) {
        lat.text = (zone?.latitude ?? a.latitude ?? 36.80).toString();
        lon.text = (zone?.longitude ?? a.longitude ?? 10.18).toString();
        radius = zone?.radius ?? 3000;
        initialized = true;
      }
      return ReportsPage(
        title: 'Zone de recherche',
        children: [
          const Text(
            'Choisissez un centre approximatif et un rayon de 1 à 20 km.',
          ),
          LocationFields(
            latitude: lat,
            longitude: lon,
            showMap: false,
            onPositionChanged: () => setState(() {}),
            onConsent: (v) => consent = v,
          ),
          Text('Rayon : ${(radius / 1000).toStringAsFixed(1)} km'),
          Slider(
            value: radius,
            min: 1000,
            max: 20000,
            divisions: 38,
            label: '${(radius / 1000).toStringAsFixed(1)} km',
            onChanged: GuardedForm.track<double>(
              (v) => setState(() => radius = v),
            ),
          ),
          if (double.tryParse(lat.text) != null &&
              double.tryParse(lon.text) != null &&
              double.parse(lat.text).abs() <= 90 &&
              double.parse(lon.text).abs() <= 180)
            ReportMap(
              key: const ValueKey('search-zone-map'),
              latitude: double.parse(lat.text),
              longitude: double.parse(lon.text),
              radius: radius,
              onTap: (a, b) => setState(() {
                lat.text = a.toStringAsFixed(2);
                lon.text = b.toStringAsFixed(2);
              }),
            ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    final ok = await reportAction(c, () async {
                      final x = coordinate(lat), y = coordinate(lon);
                      if (x == null || y == null) {
                        throw const ReportsFailure(
                          'Un centre est nécessaire pour la zone.',
                        );
                      }
                      await c.read<LocalReportsRepository>().saveSearchZone(
                        widget.id,
                        x,
                        y,
                        radius,
                        consent: consent,
                      );
                    });
                    if (!mounted) return;
                    setState(() => busy = false);
                    if (ok && c.mounted) {
                      GuardedForm.savedGo(c, '/lost-found/${widget.id}');
                    }
                  },
            child: const Text('Enregistrer la zone'),
          ),
        ],
      );
    },
  );
}

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});
  @override
  Widget build(BuildContext c) => ReportsView(
    load: (r) async => (await r.getMatches(), await r.getAnnouncements()),
    builder: (c, data) => ReportsPage(
      title: 'Correspondances possibles',
      children: [
        const Text(
          'Une aide à la recherche, jamais une preuve de propriété.',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Score explicable : espèce 30 %, race 15 %, couleur 20 %, proximité 20 %, signes distinctifs 15 %. Une validation humaine reste nécessaire.',
        ),
        FilledButton(
          onPressed: () => reportAction(
            c,
            () => c.read<LocalReportsRepository>().refreshMatches(),
            success: 'Comparaison des annonces actives terminée.',
          ),
          child: const Text('Rechercher des correspondances'),
        ),
        if (data.$1.isEmpty)
          const Text(
            'Aucune correspondance active. Publiez des annonces puis lancez la recherche.',
          ),
        ...data.$1.map((m) => MatchSummary(m, data.$2)),
      ],
    ),
  );
}

class MatchSummary extends StatelessWidget {
  const MatchSummary(this.match, this.announcements, {super.key});
  final Correspondance match;
  final List<Annonce> announcements;
  @override
  Widget build(BuildContext c) {
    final pair = announcements.where(
      (a) =>
          a.id == match.lostAnnouncementId || a.id == match.foundAnnouncementId,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Similarité : ${match.score.toStringAsFixed(1)} / 100',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(match.status.label)),
                Chip(label: Text(reportDate(match.detectedAt))),
              ],
            ),
            ...pair.map(
              (a) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (a.photo != null)
                    SizedBox(height: 130, child: ReportPhoto(a.photo))
                  else
                    const Icon(Icons.pets, color: Color(0xFFF59E0B), size: 48),
                  Text(
                    '${a.type.label} • ${a.species} • ${a.breed ?? 'Race non précisée'} • ${a.color}',
                  ),
                  Text(
                    a.distinguishingSigns ?? 'Signes distinctifs non précisés',
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            routeButton(c, 'Voir la correspondance', '/matches/${match.id}'),
          ],
        ),
      ),
    );
  }
}

class MatchDetailsScreen extends StatelessWidget {
  const MatchDetailsScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext c) => ReportsView(
    load: (r) async {
      final m = (await r.getMatches()).where((m) => m.id == id).firstOrNull;
      if (m == null) throw const ReportsFailure('Correspondance indisponible.');
      return (
        m,
        await r.getAnnouncement(m.lostAnnouncementId),
        await r.getAnnouncement(m.foundAnnouncementId),
      );
    },
    builder: (c, data) => ReportsPage(
      title: 'Comparer les annonces',
      children: [
        Text(
          'Similarité ${data.$1.score.toStringAsFixed(1)} / 100 • ${data.$1.status.label}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Ce calcul utilise uniquement les informations déclarées. Il ne prouve ni l’identité de l’animal ni la propriété.',
        ),
        ...[data.$2, data.$3].map(
          (a) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${a.type.label} • ${a.species}',
                    style: const TextStyle(fontSize: 22),
                  ),
                  ReportPhoto(a.photo),
                  Text(
                    'Race : ${a.breed ?? 'Non précisée'}\nCouleur : ${a.color}\nSignes : ${a.distinguishingSigns ?? 'Non précisés'}\n${a.description}',
                  ),
                  routeButton(c, 'Voir l’annonce', '/lost-found/${a.id}'),
                ],
              ),
            ),
          ),
        ),
        routeButton(
          c,
          'Déposer une réclamation privée',
          '/claims/new/${data.$3.id}',
        ),
        if (reportsAdmin(c) && data.$1.status == MatchStatus.DETECTED)
          Wrap(
            spacing: 8,
            children: [MatchStatus.CONFIRMED, MatchStatus.REJECTED]
                .map(
                  (s) => OutlinedButton(
                    onPressed: () async {
                      if (await reportConfirm(
                        c,
                        '${s.label} cette correspondance ? Cela ne valide aucune propriété.',
                      )) {
                        if (c.mounted) {
                          await reportAction(
                            c,
                            () => c
                                .read<LocalReportsRepository>()
                                .moderateMatch(id, s),
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
    ),
  );
}

class AnimalClaimScreen extends StatefulWidget {
  const AnimalClaimScreen({super.key, required this.announcementId});
  final int announcementId;
  @override
  State<AnimalClaimScreen> createState() => _AnimalClaimScreenState();
}

class _AnimalClaimScreenState extends State<AnimalClaimScreen> {
  final evidence = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    evidence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ReportsView(
    load: (r) => r.getAnnouncement(widget.announcementId),
    builder: (c, a) => ReportsPage(
      title: 'Réclamer mon animal',
      children: [
        Text('${a.type.label} • ${a.species} • ${a.color}'),
        const Text(
          'Décrivez des preuves vérifiables : particularités non publiées, documents, contexte. Ces éléments restent visibles uniquement par vous et l’administration locale. Aucune attribution automatique.',
        ),
        field(evidence, 'Preuves privées (20 caractères minimum)', lines: 6),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  final ok = await reportAction(c, () async {
                    await c.read<LocalReportsRepository>().createClaim(
                      widget.announcementId,
                      evidence.text,
                    );
                  });
                  if (!mounted) return;
                  setState(() => busy = false);
                  if (ok && c.mounted) GuardedForm.savedGo(c, '/claims');
                },
          child: const Text('Soumettre à vérification humaine'),
        ),
      ],
    ),
  );
}

class ClaimsScreen extends StatelessWidget {
  const ClaimsScreen({super.key});
  @override
  Widget build(BuildContext c) => ReportsView(
    load: (r) => r.getClaims(),
    builder: (c, items) => ReportsPage(
      title: 'Mes réclamations privées',
      children: [
        const Text(
          'Les preuves ne sont jamais affichées sur les annonces publiques.',
        ),
        if (items.isEmpty) const Text('Aucune réclamation.'),
        ...items.map((claim) => ClaimCard(claim)),
      ],
    ),
  );
}

class ClaimCard extends StatefulWidget {
  const ClaimCard(this.claim, {super.key});
  final Reclamation claim;
  @override
  State<ClaimCard> createState() => _ClaimCardState();
}

class _ClaimCardState extends State<ClaimCard> {
  bool busy = false;
  Future<void> decide(bool verified) async {
    if (!await reportConfirm(
      context,
      verified
          ? 'Valider cette propriété après examen humain des preuves ? L’annonce sera clôturée et les autres réclamations en attente seront rejetées.'
          : 'Rejeter cette réclamation ?',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    await reportAction(
      context,
      () => context.read<LocalReportsRepository>().decideClaim(
        widget.claim.id,
        verified: verified,
      ),
    );
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    final claim = widget.claim;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Réclamation #${claim.id} • ${claim.status.label}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Déposée le ${reportDate(claim.createdAt)}\nPreuves privées : ${claim.evidence}',
            ),
            if (claim.verificationCode != null)
              Text('Code privé : ${claim.verificationCode}'),
            routeButton(
              c,
              'Voir l’animal',
              '/lost-found/${claim.announcementId}',
            ),
            if (claim.status == ClaimStatus.VERIFIED)
              routeButton(
                c,
                'Publier des retrouvailles',
                '/reunion-stories/new/${claim.announcementId}',
              ),
            if (reportsAdmin(c) &&
                claim.status == ClaimStatus.PENDING &&
                claim.claimantUserId != c.watch<AuthSession>().currentUser?.id)
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: busy ? null : () => decide(true),
                    child: const Text('Vérifier la propriété'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : () => decide(false),
                    child: const Text('Rejeter'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class ReunionStoriesScreen extends StatelessWidget {
  const ReunionStoriesScreen({super.key});
  @override
  Widget build(BuildContext c) => ReportsView(
    load: (r) async {
      final stories = await r.getStories();
      final announcements = await r.getAnnouncements();
      return (stories, announcements);
    },
    builder: (c, data) => ReportsPage(
      title: 'Histoires de retrouvailles',
      children: [
        const Text(
          'De belles nouvelles, après vérification humaine.',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        if (data.$1.isEmpty)
          const Text(
            'Les histoires apparaîtront après une réclamation vérifiée, une clôture et une publication volontaire.',
          ),
        ...data.$1.map((s) {
          final a = data.$2.where((a) => a.id == s.announcementId).firstOrNull;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ReportPhoto(s.photo),
                  Text(
                    s.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${a?.species ?? 'Animal'} • ${reportDate(s.publicationDate)}',
                  ),
                  routeButton(
                    c,
                    'Voir l’animal',
                    '/lost-found/${s.announcementId}',
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    ),
  );
}

class ReunionStoryFormScreen extends StatefulWidget {
  const ReunionStoryFormScreen({super.key, required this.id});
  final int id;
  @override
  State<ReunionStoryFormScreen> createState() => _ReunionStoryFormScreenState();
}

class _ReunionStoryFormScreenState extends State<ReunionStoryFormScreen> {
  final title = TextEditingController();
  Uint8List? photo;
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ReportsPage(
    title: 'Partager des retrouvailles',
    children: [
      const Text(
        'Publication publique et volontaire, réservée aux retrouvailles vérifiées.',
      ),
      field(title, 'Titre de votre histoire (5 caractères minimum)', lines: 2),
      ReportPhotoPicker(onChanged: (v) => photo = v),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                final repo = c.read<LocalReportsRepository>();
                final ok = await reportAction(c, () async {
                  final ref = photo == null
                      ? null
                      : await repo.savePhoto(photo!);
                  await repo.publishStory(widget.id, title.text, photo: ref);
                });
                if (!mounted) return;
                setState(() => busy = false);
                if (ok && c.mounted) GuardedForm.savedGo(c, '/reunion-stories');
              },
        child: const Text('Publier l’histoire'),
      ),
    ],
  );
}

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});
  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  ReportStatus? status;
  @override
  Widget build(BuildContext c) {
    if (!reportsAdmin(c)) {
      return const ReportsPage(
        title: 'Accès refusé',
        children: [Text('Administration uniquement.')],
      );
    }
    return ReportsView(
      load: (r) async => (
        await r.getReports(),
        await r.getAnnouncements(),
        await r.getClaims(),
        await r.getMatches(),
      ),
      builder: (c, data) => ReportsPage(
        title: 'Modération des signalements',
        children: [
          const Text(
            'Contrôles humains',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Examinez les preuves avant toute décision. Un score ne valide jamais une propriété. Vous ne pouvez pas vérifier votre propre réclamation.',
          ),
          const Text(
            'Signalements',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                  selected: status == s,
                  onSelected: (_) => setState(() => status = s),
                ),
              ),
            ],
          ),
          if (data.$1
              .where((r) => status == null || r.status == status)
              .isEmpty)
            const Text('Aucun signalement.'),
          ...data.$1
              .where((r) => status == null || r.status == status)
              .map(
                (r) => ListTile(
                  title: Text('${r.type.label} • ${r.status.label}'),
                  subtitle: Text(r.description),
                  onTap: () => c.push('/reports/${r.id}'),
                ),
              ),
          const Text(
            'Annonces',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          ...data.$2.map(
            (a) => ListTile(
              title: Text('${a.type.label} • ${a.species} • ${a.status.label}'),
              subtitle: Text(a.hidden ? 'Masquée' : 'Visible'),
              onTap: () => c.push('/lost-found/${a.id}'),
            ),
          ),
          const Text(
            'Réclamations privées',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          ...data.$3.map((claim) => ClaimCard(claim)),
          const Text(
            'Correspondances',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          ...data.$4.map(
            (m) => ListTile(
              title: Text(
                '${m.score.toStringAsFixed(1)} / 100 • ${m.status.label}',
              ),
              onTap: () => c.push('/matches/${m.id}'),
            ),
          ),
        ],
      ),
    );
  }
}
