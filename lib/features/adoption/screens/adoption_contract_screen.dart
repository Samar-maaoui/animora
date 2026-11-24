import '../../../core/widgets/guarded_form.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/adoption_status.dart';
import '../../../core/widgets/app_button.dart';
import '../repositories/adoption_repository.dart';
import '../state/adoption_workflow_store.dart';
import '../widgets/workflow_widgets.dart';

class AdoptionContractScreen extends StatefulWidget {
  const AdoptionContractScreen({super.key, required this.id});
  final int id;
  @override
  State<AdoptionContractScreen> createState() => _AdoptionContractScreenState();
}

class _AdoptionContractScreenState extends State<AdoptionContractScreen> {
  bool _confirmed = false;
  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'Contrat d’adoption',
    child: WorkflowView<AdoptionDetails>(
      key: ValueKey(widget.id),
      load: (s) => s.adoptions.getAdoption(widget.id),
      builder: (context, details) {
        final store = context.watch<AdoptionWorkflowStore>();
        final c = details.contract, a = details.adoption;
        if (c == null || a.status != AdoptionStatus.ACCEPTED) {
          return const Text('Aucun contrat disponible pour cette demande.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Signature de démonstration uniquement — aucune valeur juridique revendiquée.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            WorkflowInfo(
              title: 'Adoptant et animal',
              values: {
                'Adoptant': details.applicant.fullName,
                'E-mail': details.applicant.email,
                'Téléphone': details.applicant.phone ?? 'Non renseigné',
                'Ville de l’adoptant': details.applicant.city,
                'Animal': details.animal.name,
                'Espèce et race':
                    '${details.animal.species} · ${details.animal.breed}',
                'Puce': details.animal.microchipNumber,
                'Date de décision': workflowDate(a.decisionDate),
              },
            ),
            WorkflowInfo(
              title: 'Conditions et engagements',
              values: {'Conditions': c.conditions},
            ),
            if (c.signed)
              WorkflowInfo(
                title: 'Contrat signé en démonstration',
                values: {
                  'Date de signature': workflowDate(c.signatureDate),
                  'Adoption effective': workflowDate(a.adoptionDate),
                },
              )
            else if (a.userId == store.session.currentUser?.id) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmed,
                title: const Text(
                  'J’ai lu les conditions et je confirme la signature de démonstration.',
                ),
                onChanged: GuardedForm.track<bool?>(
                  store.busy
                      ? null
                      : (value) => setState(() => _confirmed = value ?? false),
                ),
              ),
              AppButton(
                label: 'Accepter et signer le contrat',
                loading: store.busy,
                onPressed: !_confirmed
                    ? null
                    : () async {
                        if (await confirmWorkflow(
                              context,
                              'Confirmer la signature de démonstration ?',
                              'Cette simulation rendra l’adoption effective dans Animora. Elle ne constitue pas une signature juridique.',
                            ) &&
                            context.mounted) {
                          await runWorkflow(
                            context,
                            () => store.contracts.signContract(
                              widget.id,
                              confirmed: true,
                            ),
                            success: 'Contrat signé en démonstration. Adoption effective.',
                          );
                        }
                      },
              ),
            ] else
              const Text('La signature doit être effectuée par l’adoptant.'),
          ],
        );
      },
    ),
  );
}
