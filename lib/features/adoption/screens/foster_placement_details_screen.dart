import '../../../core/widgets/guarded_form.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/user_profile.dart';
import '../../../core/enums/animal_status.dart';
import '../../../core/enums/hebergement_status.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../models/hebergement.dart';
import '../state/adoption_store.dart';
import '../state/adoption_workflow_store.dart';
import '../widgets/workflow_widgets.dart';

class FosterPlacementDetailsScreen extends StatefulWidget {
  const FosterPlacementDetailsScreen({super.key, required this.id});
  final int id;
  @override
  State<FosterPlacementDetailsScreen> createState() =>
      _FosterPlacementDetailsScreenState();
}

class _FosterPlacementDetailsScreenState
    extends State<FosterPlacementDetailsScreen> {
  final _remark = TextEditingController();
  AnimalStatus _release = AnimalStatus.AVAILABLE;
  @override
  void dispose() {
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'Détails de l’hébergement',
    child: WorkflowView<Hebergement>(
      key: ValueKey(widget.id),
      load: (s) => s.placements.getPlacement(widget.id),
      builder: (context, p) {
        final store = context.watch<AdoptionWorkflowStore>(),
            catalog = context.watch<AdoptionStore>();
        final admin = store.session.currentUser?.profile == UserProfile.admin;
        final name = catalog.byId(p.animalId)?.name ?? 'Animal n°${p.animalId}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkflowInfo(
              title: name,
              values: {
                'Statut': p.status.label,
                'Début': workflowDate(p.startDate),
                'Fin': workflowDate(p.endDate),
                'Famille (identifiant)': p.fosterFamilyUserId,
                'Remarques': p.remarks.isEmpty ? 'Aucune remarque' : p.remarks,
              },
            ),
            TextButton(
              onPressed: () => context.push('/animals/${p.animalId}'),
              child: const Text('Consulter l’animal'),
            ),
            if (p.status == HebergementStatus.ACTIVE) ...[
              AppTextField(label: 'Ajouter une remarque', controller: _remark),
              OutlinedButton(
                onPressed: store.busy
                    ? null
                    : () async {
                        if (await runWorkflow(
                          context,
                          () => store.placements.addPlacementRemark(
                            p.id,
                            _remark.text,
                          ),
                          success: 'Remarque enregistrée.',
                        )) {
                          _remark.clear();
                          GuardedForm.markSaved();
                        }
                      },
                child: const Text('Enregistrer la remarque'),
              ),
              if (admin) ...[
                DropdownButtonFormField<AnimalStatus>(
                  initialValue: _release,
                  decoration: const InputDecoration(
                    labelText: 'Situation de l’animal à la sortie',
                  ),
                  items: [
                    for (final s in [
                      AnimalStatus.AVAILABLE,
                      AnimalStatus.LOST,
                      AnimalStatus.FOUND,
                    ])
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) =>
                      setState(() => _release = v ?? AnimalStatus.AVAILABLE),
                ),
                const Text(
                  'Une réservation d’adoption ou une adoption effective est conservée en priorité.',
                ),
              ],
              const SizedBox(height: 16),
              AppButton(
                label: 'Terminer l’hébergement',
                onPressed: store.busy
                    ? null
                    : () async {
                        if (await confirmWorkflow(
                              context,
                              'Terminer cet hébergement ?',
                              'La date de fin sera enregistrée. Sans réservation d’adoption, l’animal sera remis à disposition selon sa situation de sortie.',
                            ) &&
                            context.mounted) {
                          await runWorkflow(
                            context,
                            () => store.placements.finishPlacement(
                              p.id,
                              releaseStatus: admin
                                  ? _release
                                  : AnimalStatus.AVAILABLE,
                            ),
                            success: 'Hébergement terminé.',
                          );
                        }
                      },
              ),
              if (admin)
                OutlinedButton(
                  onPressed: store.busy
                      ? null
                      : () async {
                          if (await confirmWorkflow(
                                context,
                                'Annuler cet hébergement ?',
                                'La fin et le statut de sortie seront enregistrés.',
                              ) &&
                              context.mounted) {
                            await runWorkflow(
                              context,
                              () => store.placements.finishPlacement(
                                p.id,
                                cancel: true,
                                releaseStatus: _release,
                              ),
                              success: 'Hébergement annulé.',
                            );
                          }
                        },
                  child: const Text('Annuler l’hébergement'),
                ),
              if (!admin &&
                  p.fosterFamilyUserId == store.session.currentUser?.id)
                TextButton(
                  onPressed: () => context.push(
                    '/adoptions/new/${p.animalId}?placementId=${p.id}',
                  ),
                  child: const Text('Demander l’adoption définitive'),
                ),
            ],
          ],
        );
      },
    ),
  );
}
