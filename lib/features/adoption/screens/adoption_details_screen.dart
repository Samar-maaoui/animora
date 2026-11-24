import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/adoption_status.dart';
import '../../../core/enums/user_profile.dart';
import '../../../core/widgets/app_button.dart';
import '../repositories/adoption_repository.dart';
import '../state/adoption_workflow_store.dart';
import '../widgets/workflow_widgets.dart';

class AdoptionDetailsScreen extends StatelessWidget {
  const AdoptionDetailsScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'Détails de la demande',
    child: WorkflowView<AdoptionDetails>(
      key: ValueKey(id),
      load: (store) => store.adoptions.getAdoption(id),
      builder: (context, details) {
        final store = context.watch<AdoptionWorkflowStore>();
        final actor = store.session.currentUser;
        final a = details.adoption, q = details.questionnaire;
        final admin = actor?.profile == UserProfile.admin;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkflowInfo(
              title: details.animal.name,
              values: {
                'Demande': a.status.label,
                'Date de demande': workflowDate(a.applicationDate),
                'Date de décision': workflowDate(a.decisionDate),
                'Adoption effective': workflowDate(a.adoptionDate),
                'Espèce': details.animal.species,
                'Ville': details.animal.city,
                'Motivation': a.motivation,
              },
            ),
            TextButton(
              onPressed: () => context.push('/animals/${a.animalId}'),
              child: const Text('Consulter la fiche de l’animal'),
            ),
            WorkflowInfo(
              title: 'Demandeur',
              values: {
                'Nom': details.applicant.fullName,
                'E-mail': details.applicant.email,
                'Téléphone': details.applicant.phone ?? 'Non renseigné',
                'Ville': details.applicant.city,
              },
            ),
            WorkflowInfo(
              title: 'Questionnaire',
              values: {
                'Logement': q.housingType,
                'Enfants': q.hasChildren ? 'Oui' : 'Non',
                'Autres animaux': q.hasOtherAnimals ? 'Oui' : 'Non',
                'Expérience': q.experience,
                'Temps disponible': q.availableTime,
              },
            ),
            CompatibilitySummary(score: a.compatibilityScore),
            if (a.status == AdoptionStatus.PENDING && a.userId == actor?.id)
              OutlinedButton(
                onPressed: store.busy
                    ? null
                    : () async {
                        if (await confirmWorkflow(
                              context,
                              'Annuler la demande ?',
                              'Votre demande ne sera plus examinée.',
                            ) &&
                            context.mounted) {
                          await runWorkflow(
                            context,
                            () => store.adoptions.cancelAdoption(id),
                            success: 'Demande annulée.',
                          );
                        }
                      },
                child: const Text('Annuler ma demande'),
              ),
            if (admin && a.status == AdoptionStatus.PENDING) ...[
              AppButton(
                label: 'Accepter la demande',
                onPressed: store.busy
                    ? null
                    : () async {
                        if (await confirmWorkflow(
                              context,
                              'Accepter cette demande ?',
                              'L’animal sera réservé, le contrat sera préparé et les autres demandes en attente pour cet animal seront refusées.',
                            ) &&
                            context.mounted) {
                          await runWorkflow(
                            context,
                            () => store.adoptions.decideAdoption(
                              id,
                              accept: true,
                            ),
                            success: 'Demande acceptée. Contrat préparé.',
                          );
                        }
                      },
              ),
              OutlinedButton(
                onPressed: store.busy
                    ? null
                    : () async {
                        if (await confirmWorkflow(
                              context,
                              'Refuser cette demande ?',
                              'Cette décision sera enregistrée.',
                            ) &&
                            context.mounted) {
                          await runWorkflow(
                            context,
                            () => store.adoptions.decideAdoption(
                              id,
                              accept: false,
                            ),
                            success: 'Demande refusée.',
                          );
                        }
                      },
                child: const Text('Refuser la demande'),
              ),
            ],
            if (a.status == AdoptionStatus.ACCEPTED)
              AppButton(
                label: 'Consulter le contrat',
                onPressed: () => context.push('/adoptions/$id/contract'),
              ),
            if (a.adoptionDate != null)
              TextButton(
                onPressed: () => context.push('/adoptions/$id/follow-up'),
                child: const Text('Suivi post-adoption'),
              ),
          ],
        );
      },
    ),
  );
}
