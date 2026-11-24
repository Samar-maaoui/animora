import '../../../core/widgets/app_notification.dart';
import '../../../core/widgets/guarded_form.dart';
import '../../../core/widgets/navigation_app_bar.dart';
import '../../../core/enums/material_type.dart';
import '../../../core/enums/material_need_status.dart';

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:provider/provider.dart';

import '../models/donation_campaign.dart';
import '../models/material_need.dart';
import 'donations_scope.dart';
import '../services/donation_rules.dart';
import '../../../core/enums/campaign_status.dart';
import '../../animal_services/widgets/services_widgets.dart' show serviceBadge;
export 'donations_scope.dart';
export '../services/donation_rules.dart';
export '../../auth/state/auth_session.dart';
export '../../../core/enums/user_profile.dart';
export '../../../core/enums/campaign_status.dart';
export '../../../core/enums/donation_type.dart';
export '../../../core/enums/donation_status.dart';
export '../../../core/enums/material_type.dart';
export '../../../core/enums/material_donation_status.dart';
export '../../../core/enums/donation_frequency.dart';
export '../../../core/enums/recurring_donation_status.dart';
export '../../../core/enums/material_need_status.dart';
export '../../animal_services/widgets/services_widgets.dart'
    show
        serviceDate,
        serviceDateTime,
        serviceTime,
        serviceLink,
        serviceBadge,
        serviceField,
        serviceDropdown,
        serviceConfirm,
        servicePickDate,
        ServicePhotoPicker;

const donationsColor = Color(0xFF8B5CF6);
Widget donationCard(List<Widget> children) => Card(
  semanticContainer: false,
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children.expand((w) => [w, const SizedBox(height: 8)]).toList(),
    ),
  ),
);
Widget donationProgress(double value) => Semantics(
  container: true,
  label: 'Progression de l’objectif',
  value: '${(value * 100).toStringAsFixed(1)} %',
  child: ExcludeSemantics(
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      color: donationsColor,
      backgroundColor: const Color(0xFFEDE9FE),
      minHeight: 8,
    ),
  ),
);

String newDonationRequestKey() =>
    '${DateTime.now().microsecondsSinceEpoch}-${List.generate(12, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';

class DonationsPage extends StatelessWidget {
  const DonationsPage({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext c) => Theme(
    data: Theme.of(c).copyWith(
      colorScheme: Theme.of(c).colorScheme.copyWith(primary: donationsColor),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF6D28D9),
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF6D28D9),
        ),
      ),
    ),
    child: Scaffold(
      appBar: NavigationAppBar(
        title: Text(title),
        backgroundColor: const Color(0xFFF3E8FF),
      ),
      body: GuardedForm(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Card(
                      color: Color(0xFFF3E8FF),
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          donationNotice,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const Text(
                      'Contributions enregistrées sur cet appareil uniquement • aucune synchronisation',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ...children.expand((w) => [w, const SizedBox(height: 12)]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class DonationsView<T> extends StatefulWidget {
  const DonationsView({super.key, required this.load, required this.builder});
  final Future<T> Function(DonationsStore) load;
  final Widget Function(BuildContext, T) builder;
  @override
  State<DonationsView<T>> createState() => _DonationsViewState<T>();
}

class _DonationsViewState<T> extends State<DonationsView<T>> {
  Future<T>? future;
  int? revision;
  @override
  Widget build(BuildContext c) {
    final store = c.watch<DonationsStore>();
    if (future == null || revision != store.revision) {
      revision = store.revision;
      future = widget.load(store);
    }
    return FutureBuilder<T>(
      future: future,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (s.hasError) {
          return DonationsPage(
            title: 'Information',
            children: [
              Text(donationError(s.error!)),
              TextButton(
                onPressed: () => setState(() => future = null),
                child: const Text('Réessayer'),
              ),
            ],
          );
        }
        if (!s.hasData) return const SizedBox.shrink();
        return widget.builder(c, s.data as T);
      },
    );
  }
}

Future<bool> donationAction(
  BuildContext c,
  Future<void> Function() task, {
  String message = 'Enregistré dans la démonstration locale.',
}) async {
  try {
    await task();
    if (c.mounted) {
      AppNotification.success(c, message);
    }
    GuardedForm.markSaved();
    return true;
  } catch (e) {
    if (c.mounted) {
      AppNotification.error(c, donationError(e));
    }
    return false;
  }
}

bool acceptsDonations(DonationCampaign campaign, DateTime now) =>
    campaign.status == CampaignStatus.ACTIVE &&
    !now.isBefore(campaign.startDate) &&
    now.isBefore(campaign.endDate);

class CampaignPhoto extends StatelessWidget {
  const CampaignPhoto(this.campaign, {super.key});
  final DonationCampaign campaign;
  @override
  Widget build(BuildContext c) {
    if (campaign.image == null) return const SizedBox.shrink();
    return FutureBuilder<Uint8List?>(
      future: c.read<DonationsStore>().campaigns.readCampaignImage(campaign.id),
      builder: (c, s) => s.connectionState == ConnectionState.done && s.hasData
          ? Image.memory(
              s.data!,
              height: 220,
              fit: BoxFit.contain,
              semanticLabel: 'Image de la campagne',
            )
          : const SizedBox(
              height: 60,
              child: Center(
                child: Text('Image en cours de chargement ou indisponible'),
              ),
            ),
    );
  }
}

Widget campaignProgress(DonationCampaign campaign) {
  final ratio = campaign.collectedAmount / campaign.targetAmount;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Contributions financières simulées confirmées : ${DonationMoney.format(campaign.collectedAmount)}',
      ),
      Text('Objectif : ${DonationMoney.format(campaign.targetAmount)}'),
      const SizedBox(height: 8),
      donationProgress(ratio),
      const SizedBox(height: 8),
      Text(
        '${(ratio * 100).toStringAsFixed(1)} % de l’objectif • matériel suivi séparément',
      ),
    ],
  );
}

Widget materialNeedCard(MaterialNeed need) => donationCard([
  Text(
    need.description,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  ),
  Text(
    '${need.itemType.label} • ${need.receivedQuantity} / ${need.requestedQuantity} unité(s) réceptionnée(s)',
  ),
  serviceBadge(need.status.label),
  donationProgress(need.receivedQuantity / need.requestedQuantity),
]);
