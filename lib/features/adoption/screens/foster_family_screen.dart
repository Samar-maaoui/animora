import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/animal_status.dart';
import '../../../core/enums/hebergement_status.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../users/models/user.dart';
import '../models/hebergement.dart';
import '../state/adoption_store.dart';
import '../state/adoption_workflow_store.dart';
import '../widgets/workflow_widgets.dart';

class FosterFamilyScreen extends StatefulWidget {
  const FosterFamilyScreen({super.key, this.admin = false});
  final bool admin;
  @override
  State<FosterFamilyScreen> createState() => _FosterFamilyScreenState();
}

class _FosterFamilyScreenState extends State<FosterFamilyScreen> {
  int? _animalId;
  String? _familyId;
  DateTime _start = DateTime.now();
  final _remarks = TextEditingController();
  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<AdoptionStore>(),
        store = context.watch<AdoptionWorkflowStore>();
    final available = catalog.animals
        .where((a) => a.status == AnimalStatus.AVAILABLE)
        .toList();
    return WorkflowPage(
      title: widget.admin
          ? 'Administration des hébergements'
          : 'Mes hébergements',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.admin) ...[
            Text(
              'Affecter un animal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            WorkflowView<List<User>>(
              load: (s) => s.placements.getActiveFamilies(),
              builder: (context, families) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (available.isEmpty)
                    const Text('Aucun animal disponible pour un hébergement.')
                  else
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      key: ValueKey(
                        'animal-${available.map((a) => a.id).join(',')}',
                      ),
                      initialValue: available.any((a) => a.id == _animalId)
                          ? _animalId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Animal à héberger',
                      ),
                      items: [
                        for (final animal in available)
                          DropdownMenuItem(
                            value: animal.id,
                            child: Text(animal.name),
                          ),
                      ],
                      onChanged: store.busy
                          ? null
                          : (v) => setState(() => _animalId = v),
                    ),
                  const SizedBox(height: 12),
                  if (families.isEmpty)
                    const Text('Aucune famille d’accueil active.')
                  else
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Famille d’accueil active',
                      ),
                      items: [
                        for (final user in families)
                          DropdownMenuItem(
                            value: user.id,
                            child: Text(user.fullName),
                          ),
                      ],
                      onChanged: store.busy
                          ? null
                          : (v) => setState(() => _familyId = v),
                    ),
                  TextButton.icon(
                    onPressed: store.busy
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _start,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null && mounted) {
                              setState(() => _start = date);
                            }
                          },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text('Début : ${workflowDate(_start)}'),
                  ),
                  AppTextField(
                    label: 'Remarques initiales (facultatif)',
                    controller: _remarks,
                  ),
                  AppButton(
                    label: 'Affecter à la famille',
                    loading: store.busy,
                    onPressed:
                        !available.any((a) => a.id == _animalId) ||
                            !families.any((u) => u.id == _familyId)
                        ? null
                        : () async {
                            if (await confirmWorkflow(
                                  context,
                                  'Confirmer cet hébergement ?',
                                  'L’animal sera confié à cette famille et son statut passera en famille d’accueil.',
                                ) &&
                                context.mounted) {
                              final saved = await runWorkflow(
                                context,
                                () async {
                                  await store.placements.assignPlacement(
                                    _animalId!,
                                    _familyId!,
                                    _start,
                                    remarks: _remarks.text,
                                  );
                                },
                                success: 'Hébergement créé.',
                              );
                              if (saved && mounted) {
                                _remarks.clear();
                                setState(() {
                                  _animalId = null;
                                  _familyId = null;
                                });
                              }
                            }
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ] else ...[
            Text(
              'Animaux pouvant être hébergés',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Les affectations sont réalisées par un administrateur.',
            ),
            if (available.isEmpty)
              const Text('Aucun animal disponible actuellement.'),
            for (final animal in available)
              Card(
                child: ListTile(
                  title: Text(animal.name),
                  subtitle: Text('${animal.species} · ${animal.city}'),
                  onTap: () => context.push('/animals/${animal.id}'),
                ),
              ),
            const SizedBox(height: 20),
          ],
          Text(
            widget.admin ? 'Tous les hébergements' : 'Mes accueils',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          WorkflowView<List<Hebergement>>(
            load: (s) => s.placements.getPlacements(),
            builder: (context, list) => Column(
              children: [
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Aucun hébergement pour le moment.'),
                  ),
                for (final p in list)
                  Card(
                    child: ListTile(
                      title: Text(
                        catalog.byId(p.animalId)?.name ??
                            'Animal n°${p.animalId}',
                      ),
                      subtitle: Text(
                        '${p.status.label}\nDepuis le ${workflowDate(p.startDate)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/foster-family/${p.id}'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
