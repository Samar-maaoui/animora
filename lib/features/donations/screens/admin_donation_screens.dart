import '../../../core/widgets/guarded_form.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:provider/provider.dart';

import '../widgets/donation_widgets.dart';
import '../models/donation_campaign.dart';
import '../models/material_need.dart';
import '../models/material_donation.dart';

bool donationAdmin(BuildContext c) =>
    c.watch<AuthSession>().currentUser?.profile == UserProfile.admin;
const donationAdminDenied = DonationsPage(
  title: 'Accès refusé',
  children: [Text('Administration des dons réservée à ADMIN.')],
);

class AdminDonationsDashboardScreen extends StatelessWidget {
  const AdminDonationsDashboardScreen({super.key});
  @override
  Widget build(BuildContext c) {
    if (!donationAdmin(c)) return donationAdminDenied;
    return DonationsView(
      load: (s) async => (
        await s.campaigns.getCampaigns(),
        await s.donations.getDonations(),
        await s.materials.getMaterialDonations(),
      ),
      builder: (c, data) {
        final confirmed = data.$2.where(
          (x) =>
              x.type == DonationType.FINANCIAL &&
              x.status == DonationStatus.CONFIRMED,
        );
        final total =
            confirmed.fold(
              0,
              (sum, x) => sum + DonationMoney.mills(x.amount!),
            ) /
            1000;
        final received = data.$3
            .where((m) => m.status == MaterialDonationStatus.RECEIVED)
            .length;
        return DonationsPage(
          title: 'Administration des dons',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                serviceLink(
                  c,
                  'Gérer les campagnes',
                  '/admin/donations/campaigns',
                ),
                serviceLink(
                  c,
                  'Réceptions de matériel',
                  '/admin/donations/material',
                ),
                serviceLink(c, 'Transparence', '/admin/donations/reports'),
                serviceLink(c, 'Catalogue public', '/donations'),
              ],
            ),
            donationCard([
              Text(
                '${data.$1.length} campagne(s)',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${data.$1.where((x) => x.status == CampaignStatus.ACTIVE).length} active(s)',
              ),
              Text(
                'Total financier simulé confirmé : ${DonationMoney.format(total)}',
              ),
              Text('$received don(s) matériel(s) réceptionné(s)'),
              Text(
                '${data.$2.where((x) => x.status == DonationStatus.PENDING).length} contribution(s) en attente',
              ),
            ]),
            const Text(
              'Progression par campagne',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            if (data.$1.isEmpty)
              const Text('Aucune campagne. Créez un brouillon pour commencer.'),
            ...data.$1.map(
              (x) => donationCard([
                Text(
                  x.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                campaignProgress(x),
                serviceLink(
                  c,
                  'Voir les contributions',
                  '/admin/donations/campaigns/${x.id}/contributions',
                ),
              ]),
            ),
          ],
        );
      },
    );
  }
}

class AdminDonationCampaignsScreen extends StatelessWidget {
  const AdminDonationCampaignsScreen({super.key});
  @override
  Widget build(BuildContext c) {
    if (!donationAdmin(c)) return donationAdminDenied;
    return DonationsView(
      load: (s) => s.campaigns.getCampaigns(),
      builder: (c, rows) => DonationsPage(
        title: 'Gestion des campagnes',
        children: [
          serviceLink(
            c,
            'Créer une campagne',
            '/admin/donations/campaigns/new',
          ),
          if (rows.isEmpty) const Text('Aucune campagne.'),
          ...rows.map(
            (x) => donationCard([
              CampaignPhoto(x),
              Text(
                x.title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              serviceBadge(x.status.label),
              campaignProgress(x),
              Wrap(
                spacing: 8,
                children: [
                  serviceLink(c, 'Consulter', '/donations/campaigns/${x.id}'),
                  serviceLink(
                    c,
                    'Contributions',
                    '/admin/donations/campaigns/${x.id}/contributions',
                  ),
                  if ([
                    CampaignStatus.DRAFT,
                    CampaignStatus.ACTIVE,
                  ].contains(x.status)) ...[
                    serviceLink(
                      c,
                      'Modifier la campagne',
                      '/admin/donations/campaigns/${x.id}/edit',
                    ),
                    serviceLink(
                      c,
                      'Besoins matériels',
                      '/admin/donations/campaigns/${x.id}/needs',
                    ),
                  ],
                ],
              ),
              CampaignStatusActions(x),
            ]),
          ),
        ],
      ),
    );
  }
}

class CampaignStatusActions extends StatefulWidget {
  const CampaignStatusActions(this.campaign, {super.key});
  final DonationCampaign campaign;
  @override
  State<CampaignStatusActions> createState() => _CampaignStatusActionsState();
}

class _CampaignStatusActionsState extends State<CampaignStatusActions> {
  bool busy = false;
  Future<void> change(CampaignStatus next) async {
    if (!await serviceConfirm(
      context,
      '${next.label} la campagne « ${widget.campaign.title} » ? Une clôture ou annulation arrête les programmes et annule les contributions en attente. Les contributions déjà confirmées restent dans l’historique.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    await donationAction(
      context,
      () => context.read<DonationsStore>().campaigns.changeCampaignStatus(
        widget.campaign.id,
        next,
      ),
    );
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      if (widget.campaign.status == CampaignStatus.DRAFT)
        FilledButton(
          onPressed: busy ? null : () => change(CampaignStatus.ACTIVE),
          child: const Text('Publier la campagne'),
        ),
      if (widget.campaign.status == CampaignStatus.ACTIVE)
        FilledButton(
          onPressed: busy ? null : () => change(CampaignStatus.COMPLETED),
          child: const Text('Clôturer la campagne'),
        ),
      if ([
        CampaignStatus.DRAFT,
        CampaignStatus.ACTIVE,
      ].contains(widget.campaign.status))
        OutlinedButton(
          onPressed: busy ? null : () => change(CampaignStatus.CANCELLED),
          child: const Text('Annuler la campagne'),
        ),
    ],
  );
}

class AdminCampaignFormScreen extends StatelessWidget {
  const AdminCampaignFormScreen({super.key, this.id});
  final int? id;
  @override
  Widget build(BuildContext c) {
    if (!donationAdmin(c)) return donationAdminDenied;
    if (id == null) return const CampaignEditor();
    return DonationsView(
      load: (s) => s.campaigns.getCampaign(id!),
      builder: (c, x) => CampaignEditor(initial: x),
    );
  }
}

class CampaignEditor extends StatefulWidget {
  const CampaignEditor({super.key, this.initial});
  final DonationCampaign? initial;
  @override
  State<CampaignEditor> createState() => _CampaignEditorState();
}

class _CampaignEditorState extends State<CampaignEditor> {
  late final title = TextEditingController(text: widget.initial?.title),
      description = TextEditingController(text: widget.initial?.description),
      target = TextEditingController(
        text: widget.initial?.targetAmount.toString(),
      );
  late DateTime
  start =
      widget.initial?.startDate ??
      DateTime.now().subtract(const Duration(minutes: 1)),
  end = widget.initial?.endDate ?? DateTime.now().add(const Duration(days: 30));
  Uint8List? photo;
  bool removeImage = false, busy = false;
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => DonationsPage(
    title: widget.initial == null
        ? 'Créer une campagne'
        : 'Modifier la campagne',
    children: [
      serviceField(title, 'Titre (5 caractères minimum)'),
      serviceField(
        description,
        'Description (20 caractères minimum)',
        lines: 5,
      ),
      serviceField(target, 'Objectif financier en TND'),
      const Text(
        'Le montant collecté n’est pas modifiable : il est calculé à partir des contributions financières simulées confirmées.',
      ),
      OutlinedButton(
        onPressed: () async {
          final d = await servicePickDate(c, start, past: true, time: true);
          if (d != null && mounted) setState(() => start = d);
        },
        child: Text('Début : ${serviceDateTime(start)}'),
      ),
      OutlinedButton(
        onPressed: () async {
          final d = await servicePickDate(c, end, time: true);
          if (d != null && mounted) setState(() => end = d);
        },
        child: Text('Fin : ${serviceDateTime(end)} (exclue)'),
      ),
      if (widget.initial?.image != null) ...[
        if (!removeImage) CampaignPhoto(widget.initial!),
        CheckboxListTile(
          title: const Text('Retirer l’image existante'),
          value: removeImage,
          onChanged: GuardedForm.track<bool?>(
            (v) => setState(() => removeImage = v!),
          ),
        ),
      ],
      ServicePhotoPicker(
        onChanged: (v) {
          photo = v;
          if (v != null) setState(() => removeImage = false);
        },
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                final ok = await donationAction(c, () async {
                  final value = double.tryParse(
                    target.text.trim().replaceAll(',', '.'),
                  );
                  if (value == null) {
                    throw const DonationFailure(
                      'Saisissez un objectif numérique.',
                    );
                  }
                  await c.read<DonationsStore>().campaigns.saveCampaign(
                    DonationCampaign(
                      id: widget.initial?.id ?? 0,
                      title: title.text,
                      description: description.text,
                      targetAmount: value,
                      collectedAmount: 0,
                      startDate: start,
                      endDate: end,
                      status: CampaignStatus.DRAFT,
                    ),
                    creating: widget.initial == null,
                    imageBytes: photo,
                    removeImage: removeImage,
                  );
                });
                if (!mounted) return;
                setState(() => busy = false);
                if (ok && c.mounted) {
                  GuardedForm.savedGo(c, '/admin/donations/campaigns');
                }
              },
        child: Text(
          widget.initial == null
              ? 'Enregistrer le brouillon'
              : 'Enregistrer les modifications',
        ),
      ),
    ],
  );
}

class AdminMaterialNeedsScreen extends StatelessWidget {
  const AdminMaterialNeedsScreen({super.key, required this.campaignId});
  final int campaignId;
  @override
  Widget build(BuildContext c) {
    if (!donationAdmin(c)) return donationAdminDenied;
    return DonationsView(
      load: (s) async => (
        await s.campaigns.getCampaign(campaignId),
        await s.needs.getMaterialNeeds(campaignId),
      ),
      builder: (c, data) => DonationsPage(
        title: 'Besoins • ${data.$1.title}',
        children: [
          FilledButton(
            onPressed: () => showDialog<void>(
              context: c,
              builder: (_) => MaterialNeedEditor(campaignId: campaignId),
            ),
            child: const Text('Ajouter un besoin matériel'),
          ),
          const Text(
            'Les quantités reçues sont calculées depuis les dons réceptionnés et explicitement liés à chaque besoin.',
          ),
          ...data.$2.map(
            (n) => donationCard([
              materialNeedCard(n),
              OutlinedButton(
                onPressed: () => showDialog<void>(
                  context: c,
                  builder: (_) =>
                      MaterialNeedEditor(campaignId: campaignId, initial: n),
                ),
                child: const Text('Modifier le besoin'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class MaterialNeedEditor extends StatefulWidget {
  const MaterialNeedEditor({super.key, required this.campaignId, this.initial});
  final int campaignId;
  final MaterialNeed? initial;
  @override
  State<MaterialNeedEditor> createState() => _MaterialNeedEditorState();
}

class _MaterialNeedEditorState extends State<MaterialNeedEditor> {
  late final description = TextEditingController(
        text: widget.initial?.description,
      ),
      quantity = TextEditingController(
        text: widget.initial?.requestedQuantity.toString() ?? '1',
      );
  late MaterialType type = widget.initial?.itemType ?? MaterialType.FOOD;
  bool busy = false;
  @override
  void dispose() {
    description.dispose();
    quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('Besoin matériel'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            serviceDropdown(
              type,
              MaterialType.values,
              'Type de matériel',
              (t) => t.label,
              (v) => setState(() => type = v!),
            ),
            const SizedBox(height: 12),
            serviceField(
              description,
              'Description du besoin (10 caractères minimum)',
              lines: 3,
            ),
            const SizedBox(height: 12),
            serviceField(quantity, 'Quantité entière demandée'),
          ],
        ),
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
                final ok = await donationAction(c, () async {
                  final q = int.tryParse(quantity.text.trim());
                  if (q == null) {
                    throw const DonationFailure('Quantité entière attendue.');
                  }
                  await c.read<DonationsStore>().needs.saveMaterialNeed(
                    MaterialNeed(
                      id: widget.initial?.id ?? 0,
                      campaignId: widget.campaignId,
                      description: description.text,
                      requestedQuantity: q,
                      receivedQuantity: 0,
                      status: MaterialNeedStatus.OPEN,
                      itemType: type,
                    ),
                    creating: widget.initial == null,
                  );
                });
                if (!mounted) return;
                setState(() => busy = false);
                if (ok && c.mounted) Navigator.pop(c);
              },
        child: const Text('Enregistrer le besoin'),
      ),
    ],
  );
}

class AdminCampaignContributionsScreen extends StatelessWidget {
  const AdminCampaignContributionsScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext c) {
    if (!donationAdmin(c)) return donationAdminDenied;
    return DonationsView(
      load: (s) async => (
        await s.campaigns.getCampaign(id),
        await s.donations.getDonations(campaignId: id),
      ),
      builder: (c, data) => DonationsPage(
        title: 'Contributions • ${data.$1.title}',
        children: [
          campaignProgress(data.$1),
          if (data.$2.isEmpty) const Text('Aucune contribution.'),
          ...data.$2.map(
            (x) => donationCard([
              Text(
                '${donationReference(x.id)} • ${x.donorName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('${x.type.label} • ${serviceDateTime(x.donationDate)}'),
              serviceBadge(x.status.label),
              if (x.amount != null) Text(DonationMoney.format(x.amount!)),
              serviceLink(
                c,
                'Consulter la contribution',
                '/donations/details/${x.id}',
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class AdminMaterialDonationsScreen extends StatefulWidget {
  const AdminMaterialDonationsScreen({super.key});
  @override
  State<AdminMaterialDonationsScreen> createState() =>
      _AdminMaterialDonationsScreenState();
}

class _AdminMaterialDonationsScreenState
    extends State<AdminMaterialDonationsScreen> {
  MaterialDonationStatus? status = MaterialDonationStatus.PENDING;
  @override
  Widget build(BuildContext c) {
    if (!donationAdmin(c)) return donationAdminDenied;
    return DonationsView(
      load: (s) async => (
        await s.materials.getMaterialDonations(),
        await s.donations.getDonations(),
        await s.campaigns.getCampaigns(),
      ),
      builder: (c, data) => DonationsPage(
        title: 'Réception des dons matériels',
        children: [
          const Text(
            'Marquez RECEIVED uniquement après constat de réception dans votre démonstration. Une proposition n’est comptée qu’une fois.',
          ),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Tout l’historique'),
                selected: status == null,
                onSelected: (_) => setState(() => status = null),
              ),
              ...MaterialDonationStatus.values.map(
                (s) => FilterChip(
                  label: Text(s.label),
                  selected: status == s,
                  onSelected: (_) => setState(() => status = s),
                ),
              ),
            ],
          ),
          if (data.$1
              .where((m) => status == null || m.status == status)
              .isEmpty)
            const Text('Aucune proposition pour ce statut.'),
          ...data.$1.where((m) => status == null || m.status == status).map((
            m,
          ) {
            final x = data.$2.firstWhere((x) => x.id == m.donationId);
            return donationCard([
              Text(
                '${x.campaignTitle} • ${x.donorName}',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('${m.itemType.label} • ${m.quantity} unité(s)'),
              Text(m.description),
              serviceBadge(m.status.label),
              Text(donationReference(x.id)),
              if (m.status == MaterialDonationStatus.PENDING &&
                  x.status == DonationStatus.PENDING)
                MaterialDecisionActions(m, campaignId: x.campaignId),
              serviceLink(c, 'Détails du don', '/donations/details/${x.id}'),
            ]);
          }),
        ],
      ),
    );
  }
}

class MaterialDecisionActions extends StatefulWidget {
  const MaterialDecisionActions(
    this.material, {
    super.key,
    required this.campaignId,
  });
  final MaterialDonation material;
  final int campaignId;
  @override
  State<MaterialDecisionActions> createState() =>
      _MaterialDecisionActionsState();
}

class _MaterialDecisionActionsState extends State<MaterialDecisionActions> {
  bool busy = false;
  @override
  Widget build(BuildContext c) => Wrap(
    spacing: 8,
    children: [
      FilledButton(
        onPressed: busy
            ? null
            : () => showDialog<void>(
                context: c,
                builder: (_) => MaterialReceptionDialog(
                  widget.material,
                  campaignId: widget.campaignId,
                ),
              ),
        child: const Text('Confirmer la réception'),
      ),
      OutlinedButton(
        onPressed: busy
            ? null
            : () async {
                if (!await serviceConfirm(
                  c,
                  'Rejeter cette proposition ? Elle ne sera pas comptabilisée et aucun reçu ne sera émis.',
                )) {
                  return;
                }
                if (!mounted || !c.mounted) return;
                setState(() => busy = true);
                await donationAction(
                  c,
                  () => c
                      .read<DonationsStore>()
                      .materials
                      .rejectMaterialDonation(widget.material.id),
                );
                if (mounted) setState(() => busy = false);
              },
        child: const Text('Rejeter la proposition'),
      ),
    ],
  );
}

class MaterialReceptionDialog extends StatefulWidget {
  const MaterialReceptionDialog(
    this.material, {
    super.key,
    required this.campaignId,
  });
  final MaterialDonation material;
  final int campaignId;
  @override
  State<MaterialReceptionDialog> createState() =>
      _MaterialReceptionDialogState();
}

class _MaterialReceptionDialogState extends State<MaterialReceptionDialog> {
  late int need = widget.material.materialNeedId ?? 0;
  bool busy = false;
  @override
  Widget build(BuildContext c) => DonationsView(
    load: (s) => s.needs.getMaterialNeeds(widget.campaignId),
    builder: (c, all) {
      final needs = all
          .where((n) => n.itemType == widget.material.itemType)
          .toList();
      return AlertDialog(
        title: const Text('Réception du matériel'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.material.quantity} unité(s) • ${widget.material.itemType.label}',
              ),
              Text(widget.material.description),
              serviceDropdown(
                need,
                [
                  if (widget.material.materialNeedId == null) 0,
                  ...needs.map((n) => n.id),
                ],
                'Affectation du besoin',
                (id) => id == 0
                    ? 'Sans besoin lié (suivi séparé)'
                    : needs.firstWhere((n) => n.id == id).description,
                (v) => setState(() => need = v!),
              ),
              const Text(
                'La réception confirmera le don et générera un reçu de démonstration. Seul le besoin lié sera augmenté.',
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
                    final ok = await donationAction(
                      c,
                      () => c
                          .read<DonationsStore>()
                          .materials
                          .receiveMaterialDonation(
                            widget.material.id,
                            needId: need == 0 ? null : need,
                          ),
                    );
                    if (!mounted) return;
                    setState(() => busy = false);
                    if (ok && c.mounted) Navigator.pop(c);
                  },
            child: const Text('Matériel réceptionné'),
          ),
        ],
      );
    },
  );
}

class AdminTransparencyReportsScreen extends StatefulWidget {
  const AdminTransparencyReportsScreen({super.key, this.initialCampaignId});
  final int? initialCampaignId;
  @override
  State<AdminTransparencyReportsScreen> createState() =>
      _AdminTransparencyReportsScreenState();
}

class _AdminTransparencyReportsScreenState
    extends State<AdminTransparencyReportsScreen> {
  late int? campaignId = widget.initialCampaignId;
  final description = TextEditingController(),
      content = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    description.dispose();
    content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    if (!donationAdmin(c)) return donationAdminDenied;
    return DonationsView(
      load: (s) async {
        final campaigns = await s.campaigns.getCampaigns();
        return (
          campaigns,
          {
            for (final x in campaigns)
              x.id: await s.reports.getTransparencyReports(x.id),
          },
          await s.materials.getMaterialDonations(),
          await s.donations.getDonations(),
        );
      },
      builder: (c, data) {
        if (data.$1.isEmpty) {
          return const DonationsPage(
            title: 'Transparence',
            children: [Text('Créez une campagne avant de publier un rapport.')],
          );
        }
        if (!data.$1.any((x) => x.id == campaignId)) {
          campaignId = data.$1.first.id;
        }
        final campaign = data.$1.firstWhere((x) => x.id == campaignId);
        final received = data.$3
            .where(
              (m) =>
                  m.status == MaterialDonationStatus.RECEIVED &&
                  data.$4.any(
                    (x) =>
                        x.id == m.donationId &&
                        x.campaignId == campaignId &&
                        x.status == DonationStatus.CONFIRMED,
                  ),
            )
            .length;
        return DonationsPage(
          title: 'Rapports de transparence',
          children: [
            serviceDropdown(
              campaignId,
              data.$1.map((x) => x.id).toList(),
              'Campagne',
              (id) => data.$1.firstWhere((x) => x.id == id).title,
              (v) => setState(() {
                campaignId = v;
                description.clear();
                content.clear();
              }),
            ),
            campaignProgress(campaign),
            Text('$received don(s) matériel(s) réceptionné(s)'),
            serviceLink(
              c,
              'Contributions confirmées et en attente',
              '/admin/donations/campaigns/$campaignId/contributions',
            ),
            const Text(
              'Les chiffres seront calculés au moment de la publication. Déclarez uniquement l’utilisation connue des ressources ; aucune dépense ni pièce justificative n’est générée.',
            ),
            if (campaign.status == CampaignStatus.DRAFT)
              const Text('Publiez d’abord la campagne.')
            else ...[
              serviceField(
                description,
                'Description du rapport (10 à 300 caractères)',
                lines: 2,
              ),
              serviceField(
                content,
                'Utilisation déclarée des ressources (20 caractères minimum)',
                lines: 6,
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!await serviceConfirm(
                          c,
                          'Publier ce rapport pour « ${campaign.title} » ? Les chiffres seront arrêtés à la date de publication.',
                        )) {
                          return;
                        }
                        if (!mounted || !c.mounted) return;
                        setState(() => busy = true);
                        final ok = await donationAction(
                          c,
                          () => c
                              .read<DonationsStore>()
                              .reports
                              .publishTransparencyReport(
                                campaign.id,
                                description.text,
                                content.text,
                              ),
                        );
                        if (!mounted) return;
                        setState(() {
                          busy = false;
                          if (ok) {
                            description.clear();
                            content.clear();
                          }
                        });
                      },
                child: const Text('Publier le rapport'),
              ),
            ],
            const Text(
              'Rapports précédents',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            ...data.$2[campaign.id]!.map(
              (r) => donationCard([
                Text(
                  r.description,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(serviceDateTime(r.createdAt)),
                Text(
                  'Total simulé à publication : ${DonationMoney.format(r.financialTotal)}',
                ),
                Text(r.receivedMaterialSummary),
                Text(r.content),
              ]),
            ),
          ],
        );
      },
    );
  }
}
