import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/adoption_status.dart';
import '../../../core/widgets/app_button.dart';
import '../models/adoption.dart';
import '../state/adoption_workflow_store.dart';
import 'workflow_widgets.dart';

class AdoptionRequestButton extends StatelessWidget {
  const AdoptionRequestButton({super.key, required this.animalId});
  final int animalId;
  @override
  Widget build(BuildContext context) => WorkflowView<List<Adoption>>(
    load: (store) => store.adoptions.getAdoptions(),
    builder: (context, list) {
      final userId = context
          .read<AdoptionWorkflowStore>()
          .session
          .currentUser
          ?.id;
      final existing = list
          .where(
            (a) =>
                a.userId == userId &&
                a.animalId == animalId &&
                [
                  AdoptionStatus.PENDING,
                  AdoptionStatus.ACCEPTED,
                ].contains(a.status),
          )
          .firstOrNull;
      if (existing != null) {
        return Column(
          children: [
            const Text(
              'Vous avez déjà une demande en attente ou acceptée pour cet animal.',
            ),
            TextButton(
              onPressed: () => context.push('/adoptions/${existing.id}'),
              child: const Text('Consulter ma demande'),
            ),
          ],
        );
      }
      return AppButton(
        label: 'Demander une adoption',
        onPressed: () => context.push('/adoptions/new/$animalId'),
      );
    },
  );
}
