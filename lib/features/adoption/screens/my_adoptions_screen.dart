import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/adoption_status.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../models/adoption.dart';
import '../state/adoption_store.dart';
import '../state/adoption_workflow_store.dart';
import '../widgets/workflow_widgets.dart';

class MyAdoptionsScreen extends StatelessWidget {
  const MyAdoptionsScreen({super.key});
  @override
  Widget build(BuildContext context) => const AdoptionListScreen();
}

class AdoptionListScreen extends StatefulWidget {
  const AdoptionListScreen({super.key, this.admin = false});
  final bool admin;
  @override
  State<AdoptionListScreen> createState() => _AdoptionListScreenState();
}

class _AdoptionListScreenState extends State<AdoptionListScreen> {
  AdoptionStatus? _status;
  @override
  Widget build(BuildContext context) {
    final animals = context.watch<AdoptionStore>();
    final userId = context
        .watch<AdoptionWorkflowStore>()
        .session
        .currentUser
        ?.id;
    return WorkflowPage(
      title: widget.admin
          ? 'Administration des adoptions'
          : 'Mes demandes d’adoption',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.admin) ...[
            DropdownButtonFormField<AdoptionStatus>(
              decoration: const InputDecoration(
                labelText: 'Filtrer par statut',
              ),
              items: [
                const DropdownMenuItem<AdoptionStatus>(
                  child: Text('Tous les statuts'),
                ),
                for (final status in AdoptionStatus.values)
                  DropdownMenuItem(value: status, child: Text(status.label)),
              ],
              onChanged: (value) => setState(() => _status = value),
            ),
            const SizedBox(height: 16),
            const Text(
              'Accepter une demande refuse les autres demandes encore en attente pour le même animal.',
            ),
          ],
          WorkflowView<List<Adoption>>(
            load: (store) => store.adoptions.getAdoptions(),
            builder: (context, data) {
              final list = data
                  .where(
                    (a) =>
                        (widget.admin || a.userId == userId) &&
                        (_status == null || a.status == _status),
                  )
                  .toList();
              if (list.isEmpty) {
                return const EmptyStateWidget(
                  title: 'Aucune demande',
                  message: 'Aucune demande ne correspond à cet espace.',
                );
              }
              return Column(
                children: [
                  for (final a in list)
                    Card(
                      child: ListTile(
                        title: Text(
                          animals.byId(a.animalId)?.name ??
                              'Animal n°${a.animalId}',
                        ),
                        subtitle: Text(
                          '${a.status.label}\nDemande du ${workflowDate(a.applicationDate)}\nCompatibilité : ${a.compatibilityScore.toStringAsFixed(1)} %',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/adoptions/${a.id}'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
