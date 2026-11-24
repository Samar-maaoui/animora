import '../../../core/widgets/guarded_form.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../animal_services/widgets/services_widgets.dart';
import '../../veterinary/screens/veterinary_screens.dart' show ProviderIdentity;
import '../models/pet_sitter_settings.dart';
import '../models/pet_sitting_request.dart';
import '../models/pet_sitting_update.dart';

class PetSittersScreen extends StatefulWidget {
  const PetSittersScreen({super.key});
  @override
  State<PetSittersScreen> createState() => _PetSittersScreenState();
}

class _PetSittersScreenState extends State<PetSittersScreen> {
  String search = '', city = '';
  bool availableOnly = false;
  DateTime? date;
  @override
  Widget build(BuildContext c) => ServiceView(
    key: ValueKey(date?.toIso8601String()),
    load: (s) async {
      final users = await s.petSitting.getPetSitters();
      final from = date ?? DateTime.now().add(const Duration(days: 1)),
          until = (date ?? DateTime.now().add(const Duration(days: 1))).add(
            const Duration(days: 1),
          );
      return [
        for (final u in users)
          (
            u,
            await s.petSitting.getPetSitterSettings(u.id),
            await s.reviews.getReviews(u.id),
            await s.petSitting.isPetSitterAvailable(u.id, from, until),
          ),
      ];
    },
    builder: (c, rows) {
      final filtered = rows
          .where(
            (e) =>
                e.$1.fullName.toLowerCase().contains(
                  search.toLowerCase().trim(),
                ) &&
                (city.isEmpty || city == e.$1.city) &&
                (!(availableOnly || date != null) || e.$4),
          )
          .toList();
      final cities = rows.map((e) => e.$1.city).toSet().toList()..sort();
      return ServicePage(
        title: 'Pet-sitting',
        sitting: true,
        children: [
          const Text(
            'Une garde en confiance',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            children: [
              serviceLink(
                c,
                'Mes demandes de garde',
                '/pet-sitting/my-requests',
              ),
              if (serviceProfile(c) == UserProfile.petSitter)
                serviceLink(
                  c,
                  'Mon espace pet-sitter',
                  '/pet-sitting/dashboard',
                ),
            ],
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Rechercher un pet-sitter',
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
          FilterChip(
            label: const Text('Disponible sur la période sélectionnée'),
            selected: availableOnly,
            onSelected: (v) => setState(() => availableOnly = v),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final d = await servicePickDate(
                    c,
                    date ?? DateTime.now().add(const Duration(days: 1)),
                  );
                  if (d != null && mounted) setState(() => date = d);
                },
                child: Text(
                  date == null
                      ? 'Disponibilité : demain (24 h)'
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
            const Text('Aucun pet-sitter actif ne correspond à ces critères.'),
          ...filtered.map(
            (e) => serviceCard([
              ProviderIdentity(e.$1),
              Text(
                e.$2 == null
                    ? 'Tarif et disponibilité non configurés'
                    : '${e.$2!.dailyRate.toStringAsFixed(2)} TND / tranche de 24 h',
              ),
              serviceBadge(
                e.$4
                    ? 'Disponible sur la période sélectionnée'
                    : 'Indisponible sur la période sélectionnée',
              ),
              Text(
                e.$3.isEmpty
                    ? 'Pas encore d’avis'
                    : '${(e.$3.fold(0, (sum, r) => sum + r.rating) / e.$3.length).toStringAsFixed(1)} / 5 • ${e.$3.length} avis',
              ),
              Wrap(
                spacing: 8,
                children: [
                  serviceLink(c, 'Voir le profil', '/pet-sitting/${e.$1.id}'),
                  serviceLink(
                    c,
                    'Demander une garde',
                    '/pet-sitting/request/${e.$1.id}',
                  ),
                ],
              ),
            ]),
          ),
        ],
      );
    },
  );
}

class PetSitterProfileScreen extends StatelessWidget {
  const PetSitterProfileScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext c) => ServiceView(
    load: (s) async {
      final u = (await s.petSitting.getPetSitters())
          .where((u) => u.id == id)
          .firstOrNull;
      if (u == null) {
        throw const ServicesFailure('Pet-sitter actif introuvable.');
      }
      return (
        u,
        await s.petSitting.getPetSitterSettings(id),
        await s.reviews.getReviews(id),
      );
    },
    builder: (c, data) => ServicePage(
      title: 'Profil pet-sitter',
      sitting: true,
      children: [
        ProviderIdentity(data.$1),
        if (data.$2 == null)
          const Text('Ce pet-sitter n’a pas encore configuré ses services.')
        else ...[
          Text(
            'Tarif : ${data.$2!.dailyRate.toStringAsFixed(2)} TND par tranche de 24 h entamée',
          ),
          Text(
            'Période proposée : ${serviceDate(data.$2!.availableFrom)} – ${serviceDate(data.$2!.availableUntil)} (fin exclue)',
          ),
          serviceBadge(
            data.$2!.available
                ? 'Accepte des demandes'
                : 'N’accepte pas de nouvelles demandes',
          ),
          const Text(
            'Capacité : une seule garde à la fois. Le devis et la disponibilité sont revérifiés à la demande.',
          ),
        ],
        serviceLink(c, 'Demander une garde', '/pet-sitting/request/$id'),
        Text(
          data.$3.isEmpty
              ? 'Pas encore d’avis'
              : 'Note moyenne : ${(data.$3.fold(0, (sum, r) => sum + r.rating) / data.$3.length).toStringAsFixed(1)} / 5',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        ...data.$3.map(
          (r) => serviceCard([
            Text('${r.rating} / 5 • ${serviceDate(r.createdAt)}'),
            Text(r.comment),
          ]),
        ),
      ],
    ),
  );
}

class PetSitterSettingsScreen extends StatefulWidget {
  const PetSitterSettingsScreen({super.key});
  @override
  State<PetSitterSettingsScreen> createState() =>
      _PetSitterSettingsScreenState();
}

class _PetSitterSettingsScreenState extends State<PetSitterSettingsScreen> {
  final rate = TextEditingController();
  DateTime from = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
      until = DateTime.now().add(const Duration(days: 30));
  bool available = false, initialized = false, busy = false;
  @override
  void dispose() {
    rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    if (serviceProfile(c) != UserProfile.petSitter) {
      return const ServicePage(
        title: 'Accès refusé',
        sitting: true,
        children: [Text('Cet espace est réservé aux pet-sitters actifs.')],
      );
    }
    final uid = c.watch<AuthSession>().currentUser!.id;
    return ServiceView(
      load: (s) async => (await s.petSitting.getPetSitterSettings(uid),),
      builder: (c, data) {
        final settings = data.$1;
        if (!initialized) {
          if (settings != null) {
            rate.text = settings.dailyRate.toString();
            from = settings.availableFrom;
            until = settings.availableUntil;
            available = settings.available;
          }
          initialized = true;
        }
        return ServicePage(
          title: 'Mes services de garde',
          sitting: true,
          children: [
            const Text(
              'Capacité : une garde à la fois. Aucun paiement n’est effectué dans cette version locale.',
            ),
            serviceField(rate, 'Tarif en TND / tranche de 24 h entamée'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accepter de nouvelles demandes'),
              value: available,
              onChanged: GuardedForm.track<bool>(
                (v) => setState(() => available = v),
              ),
            ),
            OutlinedButton(
              onPressed: () async {
                final d = await servicePickDate(c, from);
                if (d != null && mounted) setState(() => from = d);
              },
              child: Text('Début de disponibilité : ${serviceDate(from)}'),
            ),
            OutlinedButton(
              onPressed: () async {
                final d = await servicePickDate(c, until);
                if (d != null && mounted) setState(() => until = d);
              },
              child: Text(
                'Fin de disponibilité (exclue) : ${serviceDate(until)}',
              ),
            ),
            const Text(
              'Les gardes déjà acceptées ou en cours doivent rester couvertes par votre période de disponibilité.',
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final ok = await serviceAction(c, () async {
                        final price = double.tryParse(
                          rate.text.replaceAll(',', '.'),
                        );
                        if (price == null) {
                          throw const ServicesFailure(
                            'Saisissez un tarif numérique.',
                          );
                        }
                        await c
                            .read<ServicesStore>()
                            .petSitting
                            .savePetSitterSettings(
                              PetSitterSettings(
                                userId: uid,
                                available: available,
                                dailyRate: price,
                                availableFrom: from,
                                availableUntil: until,
                              ),
                            );
                      });
                      if (!mounted) return;
                      setState(() => busy = false);
                      if (ok && c.mounted) {
                        GuardedForm.savedGo(c, '/pet-sitting/dashboard');
                      }
                    },
              child: const Text('Enregistrer mes services'),
            ),
          ],
        );
      },
    );
  }
}

class CreatePetSittingRequestScreen extends StatefulWidget {
  const CreatePetSittingRequestScreen({super.key, required this.sitterId});
  final String sitterId;
  @override
  State<CreatePetSittingRequestScreen> createState() =>
      _CreatePetSittingRequestScreenState();
}

class _CreatePetSittingRequestScreenState
    extends State<CreatePetSittingRequestScreen> {
  int? animal;
  DateTime start = DateTime.now().add(const Duration(days: 1));
  late DateTime end = start.add(const Duration(days: 1));
  final instructions = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ServiceView(
    load: (s) async {
      final u = (await s.petSitting.getPetSitters())
          .where((u) => u.id == widget.sitterId)
          .firstOrNull;
      if (u == null) throw const ServicesFailure('Pet-sitter indisponible.');
      return (
        u,
        await s.petSitting.getPetSitterSettings(u.id),
        await s.veterinary.getResponsibleAnimals(),
      );
    },
    builder: (c, data) {
      String? price;
      try {
        if (data.$2 != null) {
          price = c
              .read<ServicesStore>()
              .petSitting
              .estimatePrice(data.$2!.dailyRate, start, end)
              .toStringAsFixed(2);
        }
      } catch (_) {}
      return ServicePage(
        title: 'Demander une garde',
        sitting: true,
        children: [
          ProviderIdentity(data.$1),
          if (data.$2 == null || !data.$2!.available)
            const Text(
              'Ce pet-sitter n’accepte pas encore de nouvelles demandes.',
            ),
          if (data.$3.isEmpty) ...[
            const Text(
              'Aucun animal sous votre responsabilité. Une adoption signée ou un accueil actif est nécessaire.',
            ),
            serviceLink(c, 'Mes adoptions', '/adoptions/my'),
          ],
          if (data.$2 != null && data.$2!.available && data.$3.isNotEmpty) ...[
            serviceDropdown(
              animal,
              data.$3.map((a) => a.id).toList(),
              'Animal',
              (id) => data.$3.firstWhere((a) => a.id == id).name,
              (v) => setState(() => animal = v),
            ),
            OutlinedButton(
              onPressed: () async {
                final d = await servicePickDate(c, start, time: true);
                if (d != null && mounted) setState(() => start = d);
              },
              child: Text('Début de garde : ${serviceDateTime(start)}'),
            ),
            OutlinedButton(
              onPressed: () async {
                final d = await servicePickDate(c, end, time: true);
                if (d != null && mounted) setState(() => end = d);
              },
              child: Text('Fin de garde : ${serviceDateTime(end)}'),
            ),
            serviceField(
              instructions,
              'Instructions (10 caractères minimum)',
              lines: 4,
            ),
            Text(
              price == null ? 'Période invalide' : 'Prix estimé : $price TND',
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Chaque tranche de 24 h entamée est facturée au tarif affiché. Le montant est figé à la demande. Aucun paiement n’est réalisé.',
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (animal == null) {
                        await serviceAction(
                          c,
                          () async => throw const ServicesFailure(
                            'Choisissez un animal.',
                          ),
                        );
                        return;
                      }
                      if (!await serviceConfirm(
                        c,
                        'Confirmer cette demande de garde pour ${price ?? 'le montant calculé'} TND estimés, sans paiement ?',
                      )) {
                        return;
                      }
                      if (!mounted || !c.mounted) return;
                      setState(() => busy = true);
                      final ok = await serviceAction(
                        c,
                        () => c
                            .read<ServicesStore>()
                            .petSitting
                            .createPetSittingRequest(
                              widget.sitterId,
                              animal!,
                              start,
                              end,
                              instructions.text,
                            ),
                      );
                      if (!mounted) return;
                      setState(() => busy = false);
                      if (ok && c.mounted) {
                        GuardedForm.savedGo(c, '/pet-sitting/my-requests');
                      }
                    },
              child: const Text('Confirmer la demande de garde'),
            ),
          ],
        ],
      );
    },
  );
}

class MyPetSittingRequestsScreen extends StatelessWidget {
  const MyPetSittingRequestsScreen({super.key});
  @override
  Widget build(BuildContext c) => ServiceView(
    load: (s) => s.petSitting.getPetSittingRequests(),
    builder: (c, rows) {
      final uid = c.watch<AuthSession>().currentUser?.id;
      final mine = rows.where((r) => r.ownerUserId == uid).toList();
      return ServicePage(
        title: 'Mes demandes de garde',
        sitting: true,
        children: [
          serviceLink(c, 'Trouver un pet-sitter', '/pet-sitting'),
          if (mine.isEmpty) const Text('Aucune demande de garde.'),
          ...mine.map((r) => PetSittingRequestCard(r)),
        ],
      );
    },
  );
}

class PetSitterDashboardScreen extends StatelessWidget {
  const PetSitterDashboardScreen({super.key});
  @override
  Widget build(BuildContext c) {
    if (serviceProfile(c) != UserProfile.petSitter) {
      return const ServicePage(
        title: 'Accès refusé',
        sitting: true,
        children: [Text('Cet espace est réservé aux pet-sitters actifs.')],
      );
    }
    final uid = c.watch<AuthSession>().currentUser!.id;
    return ServiceView(
      load: (s) => s.petSitting.getPetSittingRequests(),
      builder: (c, all) {
        final rows = all.where((r) => r.petSitterUserId == uid).toList();
        return ServicePage(
          title: 'Mon espace pet-sitter',
          sitting: true,
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
                  'Configurer mes services',
                  '/pet-sitting/settings',
                ),
                serviceLink(
                  c,
                  'Mes demandes personnelles',
                  '/pet-sitting/my-requests',
                ),
              ],
            ),
            for (final group in [
              (
                'Demandes reçues',
                rows.where((r) => r.status == PetSittingStatus.PENDING),
              ),
              (
                'Gardes acceptées',
                rows.where((r) => r.status == PetSittingStatus.ACCEPTED),
              ),
              (
                'Gardes en cours',
                rows.where((r) => r.status == PetSittingStatus.IN_PROGRESS),
              ),
              (
                'Historique',
                rows.where(
                  (r) => [
                    PetSittingStatus.COMPLETED,
                    PetSittingStatus.REJECTED,
                    PetSittingStatus.CANCELLED,
                  ].contains(r.status),
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
                const Text('Aucune garde dans cette section.'),
              ...group.$2.map(
                (r) => PetSittingRequestCard(r, professional: true),
              ),
            ],
          ],
        );
      },
    );
  }
}

class PetSittingRequestCard extends StatefulWidget {
  const PetSittingRequestCard(
    this.request, {
    super.key,
    this.professional = false,
    this.readOnly = false,
  });
  final PetSittingRequest request;
  final bool professional, readOnly;
  @override
  State<PetSittingRequestCard> createState() => _PetSittingRequestCardState();
}

class _PetSittingRequestCardState extends State<PetSittingRequestCard> {
  bool busy = false;
  Future<void> change(PetSittingStatus status) async {
    if (!await serviceConfirm(
      context,
      'Passer la garde au statut « ${status.label} » ?',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    await serviceAction(
      context,
      () => context.read<ServicesStore>().petSitting.changePetSittingStatus(
        widget.request.id,
        status,
      ),
    );
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    final r = widget.request;
    final now = DateTime.now();
    return serviceCard([
      Text(
        '${r.animalName} • ${r.petSitterName}',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      if (widget.professional || widget.readOnly)
        Text('Responsable : ${r.ownerName}'),
      Text('${serviceDateTime(r.startDate)} → ${serviceDateTime(r.endDate)}'),
      Text('Montant estimé : ${r.totalPrice.toStringAsFixed(2)} TND'),
      serviceBadge(r.status.label),
      Text('Instructions privées : ${r.instructions}'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          serviceLink(
            c,
            'Suivi de garde',
            '/pet-sitting/requests/${r.id}/tracking',
          ),
          if (!widget.readOnly) ...[
            if (widget.professional &&
                r.status == PetSittingStatus.PENDING) ...[
              FilledButton(
                onPressed: busy
                    ? null
                    : () => change(PetSittingStatus.ACCEPTED),
                child: const Text('Accepter la garde'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => change(PetSittingStatus.REJECTED),
                child: const Text('Refuser la garde'),
              ),
            ],
            if (widget.professional &&
                r.status == PetSittingStatus.ACCEPTED &&
                !now.isBefore(r.startDate) &&
                now.isBefore(r.endDate))
              FilledButton(
                onPressed: busy
                    ? null
                    : () => change(PetSittingStatus.IN_PROGRESS),
                child: const Text('Démarrer la garde'),
              ),
            if (widget.professional &&
                r.status == PetSittingStatus.IN_PROGRESS &&
                !now.isBefore(r.endDate))
              FilledButton(
                onPressed: busy
                    ? null
                    : () => change(PetSittingStatus.COMPLETED),
                child: const Text('Terminer la garde'),
              ),
            if ([
              PetSittingStatus.PENDING,
              PetSittingStatus.ACCEPTED,
            ].contains(r.status))
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => change(PetSittingStatus.CANCELLED),
                child: const Text('Annuler la garde'),
              ),
            if (!widget.professional && r.status == PetSittingStatus.COMPLETED)
              serviceLink(
                c,
                'Évaluer cette garde',
                '/pet-sitting/requests/${r.id}/review',
              ),
          ],
        ],
      ),
      if (widget.professional &&
          r.status == PetSittingStatus.ACCEPTED &&
          now.isBefore(r.startDate))
        const Text(
          'Le démarrage sera disponible au début de la période réservée.',
        ),
      if (widget.professional &&
          r.status == PetSittingStatus.IN_PROGRESS &&
          now.isBefore(r.endDate))
        const Text('La clôture sera disponible à la date de fin réservée.'),
    ]);
  }
}

class PetSittingTrackingScreen extends StatefulWidget {
  const PetSittingTrackingScreen({super.key, required this.id});
  final int id;
  @override
  State<PetSittingTrackingScreen> createState() =>
      _PetSittingTrackingScreenState();
}

class _PetSittingTrackingScreenState extends State<PetSittingTrackingScreen> {
  final message = TextEditingController();
  Uint8List? photo;
  bool busy = false;
  int pickerKey = 0;
  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ServiceView(
    load: (s) async => (
      await s.petSitting.getPetSittingRequest(widget.id),
      await s.updates.getUpdates(widget.id),
    ),
    builder: (c, data) {
      final r = data.$1;
      final isSitter =
          c.watch<AuthSession>().currentUser?.id == r.petSitterUserId &&
          serviceProfile(c) == UserProfile.petSitter;
      return ServicePage(
        title: 'Suivi de garde • ${r.animalName}',
        sitting: true,
        children: [
          PetSittingRequestCard(
            r,
            professional: isSitter,
            readOnly: serviceProfile(c) == UserProfile.admin,
          ),
          const Text(
            'Chronologie privée',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Visible uniquement par les participants et l’administration locale.',
          ),
          if (data.$2.isEmpty) const Text('Aucune nouvelle publiée.'),
          ...data.$2.map(
            (u) => serviceCard([
              Text(serviceDateTime(u.createdAt)),
              Text(u.message),
              if (u.photo != null) SittingUpdatePhoto(u),
            ]),
          ),
          if (isSitter && r.status == PetSittingStatus.IN_PROGRESS) ...[
            serviceField(message, 'Nouvelle de la garde', lines: 4),
            ServicePhotoPicker(
              key: ValueKey(pickerKey),
              onChanged: (v) => photo = v,
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final ok = await serviceAction(
                        c,
                        () => c.read<ServicesStore>().updates.addUpdate(
                          widget.id,
                          message.text,
                          photo: photo,
                        ),
                      );
                      if (!mounted) return;
                      setState(() {
                        busy = false;
                        if (ok) {
                          message.clear();
                          photo = null;
                          pickerKey++;
                        }
                      });
                    },
              child: const Text('Publier une nouvelle'),
            ),
          ],
        ],
      );
    },
  );
}

class SittingUpdatePhoto extends StatelessWidget {
  const SittingUpdatePhoto(this.update, {super.key});
  final PetSittingUpdate update;
  @override
  Widget build(BuildContext c) => FutureBuilder<Uint8List?>(
    future: c.read<ServicesStore>().updates.readUpdatePhoto(update.id),
    builder: (c, s) {
      if (s.connectionState != ConnectionState.done) {
        return const SizedBox(
          height: 50,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (s.hasError || s.data == null) {
        return const Text('Photo indisponible.');
      }
      return Image.memory(
        s.data!,
        height: 240,
        fit: BoxFit.contain,
        semanticLabel: 'Photo privée de la garde',
      );
    },
  );
}

class PetSitterReviewScreen extends StatefulWidget {
  const PetSitterReviewScreen({super.key, required this.id});
  final int id;
  @override
  State<PetSitterReviewScreen> createState() => _PetSitterReviewScreenState();
}

class _PetSitterReviewScreenState extends State<PetSitterReviewScreen> {
  int rating = 5;
  final comment = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ServiceView(
    load: (s) => s.petSitting.getPetSittingRequest(widget.id),
    builder: (c, r) {
      if (r.ownerUserId != c.watch<AuthSession>().currentUser?.id ||
          r.status != PetSittingStatus.COMPLETED) {
        return const ServicePage(
          title: 'Avis indisponible',
          sitting: true,
          children: [
            Text('Seul le responsable peut évaluer une garde terminée.'),
          ],
        );
      }
      return ServicePage(
        title: 'Évaluer la garde de ${r.animalName}',
        sitting: true,
        children: [
          Text('Pet-sitter : ${r.petSitterName}'),
          const Text(
            'Votre note et votre commentaire seront publics dans cet annuaire local. Ne publiez pas de coordonnées ni d’informations privées. Un seul avis est autorisé par garde.',
          ),
          serviceDropdown(
            rating,
            [1, 2, 3, 4, 5],
            'Note',
            (n) => '$n / 5',
            (v) => setState(() => rating = v!),
          ),
          serviceField(comment, 'Votre avis (5 caractères minimum)', lines: 4),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!await serviceConfirm(
                      c,
                      'Publier cet avis dans l’annuaire local ?',
                    )) {
                      return;
                    }
                    if (!mounted || !c.mounted) return;
                    setState(() => busy = true);
                    final ok = await serviceAction(
                      c,
                      () => c.read<ServicesStore>().reviews.addReview(
                        widget.id,
                        rating,
                        comment.text,
                      ),
                    );
                    if (!mounted) return;
                    setState(() => busy = false);
                    if (ok && c.mounted) {
                      GuardedForm.savedGo(
                        c,
                        '/pet-sitting/${r.petSitterUserId}',
                      );
                    }
                  },
            child: const Text('Publier mon avis'),
          ),
        ],
      );
    },
  );
}
