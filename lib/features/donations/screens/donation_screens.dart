import '../../../core/widgets/guarded_form.dart';
import '../widgets/currency_conversion.dart';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../widgets/donation_widgets.dart';
import '../models/donation.dart';
import '../services/donation_receipt_pdf.dart';

class DonationCampaignsScreen extends StatefulWidget {
  const DonationCampaignsScreen({super.key});
  @override
  State<DonationCampaignsScreen> createState() =>
      _DonationCampaignsScreenState();
}

class _DonationCampaignsScreenState extends State<DonationCampaignsScreen> {
  String search = '';
  CampaignStatus? status;
  @override
  Widget build(BuildContext c) => DonationsView(
    load: (s) => s.campaigns.getCampaigns(),
    builder: (c, all) {
      final campaigns = all
          .where(
            (x) =>
                x.title.toLowerCase().contains(search.toLowerCase().trim()) &&
                (status == null || x.status == status),
          )
          .toList();
      return DonationsPage(
        title: 'Dons et campagnes',
        children: [
          const Text(
            'Ensemble, soutenons les animaux',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            children: [
              serviceLink(c, 'Mes dons', '/donations/my'),
              serviceLink(
                c,
                'Mes programmes récurrents',
                '/donations/recurring',
              ),
              if (c.watch<AuthSession>().currentUser?.profile ==
                  UserProfile.admin)
                serviceLink(c, 'Administration des dons', '/admin/donations'),
            ],
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Rechercher une campagne',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => search = v),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Tous les statuts'),
                selected: status == null,
                onSelected: (_) => setState(() => status = null),
              ),
              ...CampaignStatus.values
                  .where(
                    (s) =>
                        s != CampaignStatus.DRAFT ||
                        c.watch<AuthSession>().currentUser?.profile ==
                            UserProfile.admin,
                  )
                  .map(
                    (s) => FilterChip(
                      label: Text(s.label),
                      selected: status == s,
                      onSelected: (_) => setState(() => status = s),
                    ),
                  ),
            ],
          ),
          if (campaigns.isEmpty)
            const Text(
              'Aucune campagne pour ces critères. ADMIN peut créer puis publier une campagne.',
            ),
          ...campaigns.map(
            (x) => donationCard([
              CampaignPhoto(x),
              Text(
                x.title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(x.description, maxLines: 3, overflow: TextOverflow.ellipsis),
              serviceBadge(x.status.label),
              campaignProgress(x),
              Text('Fin : ${serviceDate(x.endDate)}'),
              serviceLink(
                c,
                'Voir la campagne',
                '/donations/campaigns/${x.id}',
              ),
            ]),
          ),
        ],
      );
    },
  );
}

class DonationCampaignDetailsScreen extends StatelessWidget {
  const DonationCampaignDetailsScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext c) => DonationsView(
    load: (s) async => (
      await s.campaigns.getCampaign(id),
      await s.needs.getMaterialNeeds(id),
      await s.reports.getTransparencyReports(id),
    ),
    builder: (c, data) {
      final x = data.$1;
      final open = acceptsDonations(x, c.read<DonationsStore>().now);
      return DonationsPage(
        title: x.title,
        children: [
          CampaignPhoto(x),
          serviceBadge(x.status.label),
          Text(x.description, style: const TextStyle(fontSize: 19)),
          campaignProgress(x),
          Text(
            'Du ${serviceDate(x.startDate)} au ${serviceDate(x.endDate)} (fin exclue)',
          ),
          if (open)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                serviceLink(
                  c,
                  'Faire un don financier',
                  '/donations/financial/$id',
                ),
                serviceLink(
                  c,
                  'Faire un don matériel',
                  '/donations/material/$id',
                ),
              ],
            )
          else
            const Text(
              'Cette campagne n’accepte pas de contributions actuellement.',
            ),
          if (c.watch<AuthSession>().currentUser?.profile == UserProfile.admin)
            Wrap(
              spacing: 8,
              children: [
                serviceLink(
                  c,
                  'Gérer la campagne',
                  '/admin/donations/campaigns',
                ),
                serviceLink(
                  c,
                  'Contributions',
                  '/admin/donations/campaigns/$id/contributions',
                ),
                serviceLink(
                  c,
                  'Rapports de transparence',
                  '/admin/donations/reports?campaignId=$id',
                ),
              ],
            ),
          const Text(
            'Besoins matériels',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          if (data.$2.isEmpty)
            const Text(
              'Aucun besoin matériel publié. Une proposition libre reste possible si la campagne est ouverte.',
            ),
          ...data.$2.map(materialNeedCard),
          const Text(
            'Rapports de transparence publiés',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          if (data.$3.isEmpty)
            const Text(
              'Aucun rapport publié. Aucune dépense ni utilisation des ressources n’est inventée.',
            ),
          ...data.$3.map(
            (r) => donationCard([
              Text(
                r.description,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Publié le ${serviceDateTime(r.createdAt)} • chiffres arrêtés à cette date',
              ),
              Text(
                'Financier simulé confirmé : ${DonationMoney.format(r.financialTotal)}',
              ),
              Text(
                '${r.receivedMaterialCount} proposition(s) de matériel réceptionnée(s)',
              ),
              Text(r.receivedMaterialSummary),
              const Text(
                'Utilisation déclarée par ADMIN, non auditée :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(r.content),
            ]),
          ),
        ],
      );
    },
  );
}

class FinancialDonationScreen extends StatefulWidget {
  const FinancialDonationScreen({super.key, required this.campaignId});
  final int campaignId;
  @override
  State<FinancialDonationScreen> createState() =>
      _FinancialDonationScreenState();
}

class _FinancialDonationScreenState extends State<FinancialDonationScreen> {
  final amount = TextEditingController(text: '20');
  final keyValue = newDonationRequestKey();
  bool recurring = false, busy = false;
  DonationFrequency frequency = DonationFrequency.MONTHLY;
  DateTime next = DateTime.now().add(const Duration(days: 7));
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final value = double.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (value == null) {
      await donationAction(
        context,
        () async =>
            throw const DonationFailure('Saisissez un montant numérique.'),
      );
      return;
    }
    try {
      DonationMoney.mills(value);
    } catch (e) {
      await donationAction(context, () async => throw e);
      return;
    }
    if (!mounted) return;
    if (!await serviceConfirm(
      context,
      recurring
          ? 'Créer un programme local de ${DonationMoney.format(value)}, ${frequency.label.toLowerCase()}, sans contribution immédiate ni paiement ?'
          : 'Confirmer une contribution simulée de ${DonationMoney.format(value)} ? Aucun paiement réel ne sera effectué.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    final s = context.read<DonationsStore>();
    final ok = await donationAction(context, () async {
      if (recurring) {
        await s.recurring.createRecurringDonation(
          widget.campaignId,
          value,
          frequency,
          next,
          requestKey: keyValue,
        );
      } else {
        await s.donations.createFinancialDonation(
          widget.campaignId,
          value,
          confirmSimulation: true,
          requestKey: keyValue,
        );
      }
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) {
      GuardedForm.savedGo(
        context,
        recurring ? '/donations/recurring' : '/donations/my',
      );
    }
  }

  @override
  Widget build(BuildContext c) => DonationsView(
    load: (s) => s.campaigns.getCampaign(widget.campaignId),
    builder: (c, x) => DonationsPage(
      title: 'Contribution financière simulée',
      children: [
        Text(
          x.title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        if (!acceptsDonations(x, c.read<DonationsStore>().now))
          const Text('La campagne est actuellement fermée aux contributions.')
        else ...[
          Wrap(
            spacing: 8,
            children: [5, 10, 20, 50, 100]
                .map(
                  (n) => ChoiceChip(
                    label: Text('$n TND'),
                    selected: amount.text == n.toString(),
                    onSelected: (_) =>
                        setState(() => amount.text = n.toString()),
                  ),
                )
                .toList(),
          ),
          TextField(
            controller: amount,
            decoration: const InputDecoration(
              labelText: 'Montant personnalisé en TND (3 décimales maximum)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          CurrencyConversion(amount: amount),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Programme récurrent simulé'),
            subtitle: const Text(
              'Aucune contribution immédiate et aucun débit automatique.',
            ),
            value: recurring,
            onChanged: GuardedForm.track<bool>(
              (v) => setState(() => recurring = v),
            ),
          ),
          if (recurring) ...[
            serviceDropdown(
              frequency,
              DonationFrequency.values,
              'Fréquence',
              (f) => f.label,
              (v) => setState(() => frequency = v!),
            ),
            OutlinedButton(
              onPressed: () async {
                final d = await servicePickDate(c, next, time: true);
                if (d != null && mounted) setState(() => next = d);
              },
              child: Text('Première date : ${serviceDateTime(next)}'),
            ),
          ],
          donationCard([
            const Text(
              'Récapitulatif',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            Text('Campagne : ${x.title}'),
            Text(
              'Donateur : ${c.watch<AuthSession>().currentUser?.fullName ?? ''}',
            ),
            Text('Montant saisi : ${amount.text} TND'),
            Text(
              recurring
                  ? 'Programmation uniquement. Chaque occurrence devra être préparée et confirmée manuellement.'
                  : 'Contribution ponctuelle de démonstration. Un reçu non fiscal sera disponible après confirmation.',
            ),
          ]),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(
              recurring
                  ? 'Créer le programme simulé'
                  : 'Confirmer la simulation',
            ),
          ),
        ],
      ],
    ),
  );
}

class MaterialDonationScreen extends StatefulWidget {
  const MaterialDonationScreen({super.key, required this.campaignId});
  final int campaignId;
  @override
  State<MaterialDonationScreen> createState() => _MaterialDonationScreenState();
}

class _MaterialDonationScreenState extends State<MaterialDonationScreen> {
  MaterialType type = MaterialType.FOOD;
  int needId = 0;
  final quantity = TextEditingController(text: '1'),
      description = TextEditingController();
  final keyValue = newDonationRequestKey();
  bool busy = false;
  @override
  void dispose() {
    quantity.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => DonationsView(
    load: (s) async => (
      await s.campaigns.getCampaign(widget.campaignId),
      await s.needs.getMaterialNeeds(widget.campaignId),
    ),
    builder: (c, data) => DonationsPage(
      title: 'Proposer un don matériel',
      children: [
        Text(
          data.$1.title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        if (!acceptsDonations(data.$1, c.read<DonationsStore>().now))
          const Text('La campagne n’accepte pas de proposition actuellement.')
        else ...[
          serviceDropdown(
            type,
            MaterialType.values,
            'Type de matériel',
            (t) => t.label,
            (v) => setState(() {
              type = v!;
              needId = 0;
            }),
          ),
          serviceDropdown(
            needId,
            [0, ...data.$2.where((n) => n.itemType == type).map((n) => n.id)],
            'Besoin lié',
            (id) => id == 0
                ? 'Proposition libre, sans besoin lié'
                : data.$2.firstWhere((n) => n.id == id).description,
            (v) => setState(() => needId = v!),
          ),
          serviceField(quantity, 'Quantité entière'),
          serviceField(
            description,
            'Description (10 caractères minimum)',
            lines: 4,
          ),
          const Text(
            'Votre proposition restera en attente jusqu’à sa réception par ADMIN. Aucun montant financier ne sera ajouté.',
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!await serviceConfirm(
                      c,
                      'Soumettre cette proposition de matériel, en attente de réception ?',
                    )) {
                      return;
                    }
                    if (!mounted || !c.mounted) return;
                    setState(() => busy = true);
                    final ok = await donationAction(c, () async {
                      final q = int.tryParse(quantity.text.trim());
                      if (q == null) {
                        throw const DonationFailure(
                          'Saisissez une quantité entière.',
                        );
                      }
                      await c
                          .read<DonationsStore>()
                          .materials
                          .createMaterialDonation(
                            widget.campaignId,
                            type,
                            q,
                            description.text,
                            needId: needId == 0 ? null : needId,
                            requestKey: keyValue,
                          );
                    });
                    if (!mounted) return;
                    setState(() => busy = false);
                    if (ok && c.mounted) {
                      GuardedForm.savedGo(c, '/donations/my');
                    }
                  },
            child: const Text('Soumettre la proposition'),
          ),
        ],
        const Text(
          'Besoins de la campagne',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        ...data.$2.map(materialNeedCard),
      ],
    ),
  );
}

class MyDonationsScreen extends StatelessWidget {
  const MyDonationsScreen({super.key});
  @override
  Widget build(BuildContext c) => DonationsView(
    load: (s) async => (
      await s.donations.getDonations(),
      await s.materials.getMaterialDonations(),
    ),
    builder: (c, data) {
      final uid = c.watch<AuthSession>().currentUser?.id;
      final mine = data.$1.where((x) => x.donorUserId == uid);
      return DonationsPage(
        title: 'Mes dons de démonstration',
        children: [
          Wrap(
            spacing: 8,
            children: [
              serviceLink(c, 'Campagnes', '/donations'),
              serviceLink(
                c,
                'Mes programmes récurrents',
                '/donations/recurring',
              ),
            ],
          ),
          if (mine.isEmpty)
            const Text('Vous n’avez pas encore de contribution.'),
          ...mine.map(
            (x) => donationCard([
              Text(
                x.campaignTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(donationReference(x.id)),
              serviceBadge(x.status.label),
              Text('${x.type.label} • ${serviceDateTime(x.donationDate)}'),
              if (x.amount != null)
                Text(DonationMoney.format(x.amount!))
              else
                ...data.$2
                    .where((m) => m.donationId == x.id)
                    .map(
                      (m) => Text(
                        '${m.itemType.label} • ${m.quantity} unité(s) • ${m.status.label}',
                      ),
                    ),
              serviceLink(c, 'Consulter mon don', '/donations/details/${x.id}'),
            ]),
          ),
        ],
      );
    },
  );
}

class DonationDetailsScreen extends StatelessWidget {
  const DonationDetailsScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext c) => DonationsView(
    load: (s) async => (
      await s.donations.getDonation(id),
      await s.materials.getMaterialForDonation(id),
      await s.receipts.getReceiptForDonation(id),
    ),
    builder: (c, data) {
      final x = data.$1, m = data.$2, r = data.$3;
      return DonationsPage(
        title: donationReference(x.id),
        children: [
          Text(
            x.campaignTitle,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text('Donateur : ${x.donorName}'),
          Text(serviceDateTime(x.donationDate)),
          serviceBadge(x.status.label),
          Text(x.type.label),
          if (x.amount != null)
            Text('Montant simulé : ${DonationMoney.format(x.amount!)}'),
          if (m != null) ...[
            Text('${m.itemType.label} • ${m.quantity} unité(s)'),
            Text(m.description),
            serviceBadge(m.status.label),
          ],
          if (x.status == DonationStatus.PENDING) PendingDonationActions(x),
          if (r != null)
            serviceLink(
              c,
              'Consulter le reçu de démonstration',
              '/donations/receipts/${r.id}',
            )
          else
            const Text(
              'Aucun reçu : seule une contribution confirmée peut en avoir un.',
            ),
        ],
      );
    },
  );
}

class PendingDonationActions extends StatefulWidget {
  const PendingDonationActions(this.donation, {super.key});
  final Donation donation;
  @override
  State<PendingDonationActions> createState() => _PendingDonationActionsState();
}

class _PendingDonationActionsState extends State<PendingDonationActions> {
  bool busy = false;
  Future<void> act(bool confirm) async {
    if (!await serviceConfirm(
      context,
      confirm
          ? 'Confirmer uniquement cette simulation ? Aucun paiement réel ne sera effectué.'
          : 'Annuler cette contribution en attente ?',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    final s = context.read<DonationsStore>();
    await donationAction(
      context,
      () => confirm
          ? s.donations.confirmFinancialDonation(widget.donation.id)
          : s.donations.cancelDonation(widget.donation.id),
    );
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Wrap(
    spacing: 8,
    children: [
      if (widget.donation.type == DonationType.FINANCIAL)
        FilledButton(
          onPressed: busy ? null : () => act(true),
          child: const Text('Confirmer cette simulation'),
        ),
      OutlinedButton(
        onPressed: busy ? null : () => act(false),
        child: const Text('Annuler le don en attente'),
      ),
    ],
  );
}

class RecurringDonationsScreen extends StatelessWidget {
  const RecurringDonationsScreen({super.key});
  @override
  Widget build(BuildContext c) => DonationsView(
    load: (s) => s.recurring.getRecurringDonations(),
    builder: (c, all) {
      final uid = c.watch<AuthSession>().currentUser?.id;
      final mine = all.where((r) => r.donorUserId == uid);
      return DonationsPage(
        title: 'Mes programmes récurrents simulés',
        children: [
          const Text(
            'Aucun paiement et aucune contribution confirmée ne sont créés automatiquement, même après une échéance. Chaque occurrence exige vos actions explicites.',
          ),
          if (mine.isEmpty)
            const Text(
              'Aucun programme récurrent. Créez-en un depuis une campagne ouverte.',
            ),
          ...mine.map(
            (r) => donationCard([
              Text(
                r.campaignTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('${DonationMoney.format(r.amount)} • ${r.frequency.label}'),
              serviceBadge(r.status.label),
              Text(
                'Prochaine date planifiée : ${serviceDateTime(r.nextDonationDate)}',
              ),
              if (r.terminationReason != null) Text(r.terminationReason!),
              if (r.status != RecurringDonationStatus.CANCELLED)
                RecurringActions(
                  id: r.id,
                  status: r.status,
                  due: !r.nextDonationDate.isAfter(
                    c.read<DonationsStore>().now,
                  ),
                ),
            ]),
          ),
        ],
      );
    },
  );
}

class RecurringActions extends StatefulWidget {
  const RecurringActions({
    super.key,
    required this.id,
    required this.status,
    required this.due,
  });
  final int id;
  final RecurringDonationStatus status;
  final bool due;
  @override
  State<RecurringActions> createState() => _RecurringActionsState();
}

class _RecurringActionsState extends State<RecurringActions> {
  bool busy = false;
  Future<void> status(RecurringDonationStatus next) async {
    if (!await serviceConfirm(
      context,
      '${next.label} ce programme simulé ? Les occurrences en attente seront annulées lors d’une suspension ou d’une annulation.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    await donationAction(
      context,
      () => context.read<DonationsStore>().recurring.changeRecurringStatus(
        widget.id,
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
      OutlinedButton(
        onPressed: busy
            ? null
            : () => status(
                widget.status == RecurringDonationStatus.ACTIVE
                    ? RecurringDonationStatus.PAUSED
                    : RecurringDonationStatus.ACTIVE,
              ),
        child: Text(
          widget.status == RecurringDonationStatus.ACTIVE
              ? 'Suspendre'
              : 'Reprendre',
        ),
      ),
      OutlinedButton(
        onPressed: busy
            ? null
            : () => status(RecurringDonationStatus.CANCELLED),
        child: const Text('Annuler le programme'),
      ),
      if (widget.status == RecurringDonationStatus.ACTIVE && widget.due)
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if (!await serviceConfirm(
                    c,
                    'Préparer une contribution en attente pour cette échéance ? Elle ne sera ni payée ni confirmée automatiquement.',
                  )) {
                    return;
                  }
                  if (!mounted || !c.mounted) return;
                  setState(() => busy = true);
                  int? donationId;
                  final ok = await donationAction(c, () async {
                    donationId =
                        (await c
                                .read<DonationsStore>()
                                .recurring
                                .prepareRecurringOccurrence(widget.id))
                            .id;
                  });
                  if (!mounted) return;
                  setState(() => busy = false);
                  if (ok && c.mounted) {
                    GuardedForm.savedGo(c, '/donations/details/$donationId');
                  }
                },
          child: const Text('Préparer cette occurrence'),
        ),
    ],
  );
}

class DonationReceiptScreen extends StatefulWidget {
  const DonationReceiptScreen({super.key, required this.id});
  final int id;
  @override
  State<DonationReceiptScreen> createState() => _DonationReceiptScreenState();
}

class _DonationReceiptScreenState extends State<DonationReceiptScreen> {
  bool busy = false;
  Future<void> export() async {
    setState(() => busy = true);
    final store = context.read<DonationsStore>();
    final identity = store.session.currentUser?.id;
    await donationAction(context, () async {
      final receipt = await store.receipts.getReceipt(widget.id);
      final bytes = await DonationReceiptPdf.build(receipt);
      if (!mounted || store.session.currentUser?.id != identity) {
        throw const DonationFailure('La session a changé.');
      }
      await store.receipts.getReceipt(widget.id);
      if (!mounted || store.session.currentUser?.id != identity) {
        throw const DonationFailure('La session a changé.');
      }
      final exported = await Printing.sharePdf(
        bytes: bytes,
        filename: '${receipt.reference}.pdf',
      );
      if (!exported) {
        throw const DonationFailure(
          'Export annulé ou indisponible sur cette plateforme.',
        );
      }
    }, message: 'Export PDF de démonstration préparé.');
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => DonationsView(
    load: (s) => s.receipts.getReceipt(widget.id),
    builder: (c, r) => DonationsPage(
      title: 'Reçu de démonstration',
      children: [
        const Text(
          receiptNotice,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Document non fiscal • ne constitue pas une preuve de paiement réel.',
        ),
        donationCard([
          Text(
            r.reference,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          Text('Don : ${r.donationReference}'),
          Text('Date : ${serviceDateTime(r.issueDate)}'),
          Text('Donateur : ${r.donorName}'),
          Text('Campagne : ${r.campaignTitle}'),
          Text('Type : ${r.type.label}'),
          if (r.amount != null) Text(DonationMoney.format(r.amount!)),
          if (r.materialDescription != null) Text(r.materialDescription!),
        ]),
        FilledButton.icon(
          onPressed: busy ? null : export,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Exporter le reçu PDF de démonstration'),
        ),
      ],
    ),
  );
}
