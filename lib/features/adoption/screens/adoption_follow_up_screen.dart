import '../../../core/widgets/guarded_form.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../models/suivi_adoption.dart';
import '../repositories/adoption_repository.dart';
import '../repositories/local_adoption_workflow_repository.dart';
import '../services/animal_image_picker.dart';
import '../state/adoption_workflow_store.dart';
import '../widgets/workflow_widgets.dart';
import '../widgets/animal_photo.dart';

class AdoptionFollowUpScreen extends StatefulWidget {
  const AdoptionFollowUpScreen({super.key, required this.id});
  final int id;
  @override
  State<AdoptionFollowUpScreen> createState() => _AdoptionFollowUpScreenState();
}

class _AdoptionFollowUpScreenState extends State<AdoptionFollowUpScreen> {
  final _form = GlobalKey<FormState>();
  final _news = TextEditingController();
  String? _type, _photo, _photoError;
  bool _picking = false;
  @override
  void dispose() {
    _news.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'Suivi post-adoption',
    child: WorkflowView<AdoptionDetails>(
      key: ValueKey(widget.id),
      load: (s) => s.adoptions.getAdoption(widget.id),
      builder: (context, details) {
        if (details.adoption.adoptionDate == null ||
            details.contract?.signed != true) {
          return const Text(
            'Le suivi est disponible uniquement après la signature du contrat.',
          );
        }
        final store = context.watch<AdoptionWorkflowStore>();
        final owner = details.adoption.userId == store.session.currentUser?.id;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Des nouvelles de ${details.animal.name}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (owner)
              GuardedForm(
                formKey: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: 'Nouvelles de l’animal',
                      controller: _news,
                      enabled: !store.busy && !_picking,
                      validator: (v) => v == null || v.trim().length < 10
                          ? 'Ajoutez au moins 10 caractères.'
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'Type de suivi',
                      ),
                      items: [
                        for (final type
                            in LocalAdoptionWorkflowRepository.followUpTypes)
                          DropdownMenuItem(value: type, child: Text(type)),
                      ],
                      onChanged: store.busy
                          ? null
                          : (v) => setState(() => _type = v),
                      validator: (v) =>
                          v == null ? 'Choisissez un type de suivi.' : null,
                    ),
                    const SizedBox(height: 12),
                    if (_photo != null)
                      AnimalPhoto(
                        source: _photo!,
                        name: details.animal.name,
                        height: 180,
                      ),
                    OutlinedButton(
                      onPressed: store.busy || _picking
                          ? null
                          : () async {
                              setState(() {
                                _picking = true;
                                _photoError = null;
                              });
                              try {
                                final image = await AnimalImagePicker().pick();
                                if (mounted && image != null) {
                                  setState(() => _photo = image);
                                }
                              } catch (_) {
                                if (mounted) {
                                  setState(
                                    () => _photoError = 'Impossible de lire la photo. Limite : 1 Mo.',
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _picking = false);
                              }
                            },
                      child: Text(
                        _picking
                            ? 'Lecture de la photo…'
                            : 'Ajouter une photo (facultatif)',
                      ),
                    ),
                    if (_photo != null)
                      TextButton(
                        onPressed: () => setState(() => _photo = null),
                        child: const Text('Retirer la photo sélectionnée'),
                      ),
                    if (_photoError != null) Text(_photoError!),
                    AppButton(
                      label: 'Publier les nouvelles',
                      loading: store.busy,
                      onPressed: _picking
                          ? null
                          : () async {
                              if (!_form.currentState!.validate()) return;
                              if (await runWorkflow(
                                    context,
                                    () => store.followUps.addFollowUp(
                                      widget.id,
                                      news: _news.text,
                                      visitType: _type!,
                                      photo: _photo,
                                    ),
                                    success: 'Nouvelles enregistrées.',
                                  ) &&
                                  mounted) {
                                _news.clear();
                                setState(() => _photo = null);
                              }
                            },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Text('Historique', style: Theme.of(context).textTheme.titleLarge),
            WorkflowView<List<SuiviAdoption>>(
              key: ValueKey('history-${widget.id}'),
              load: (s) => s.followUps.getFollowUps(widget.id),
              builder: (context, list) => Column(
                children: [
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Aucun suivi pour le moment.'),
                    ),
                  for (final entry in list)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${workflowDate(entry.date)} · ${entry.visitType}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(entry.news),
                            if (entry.photo != null)
                              AnimalPhoto(
                                source: entry.photo!,
                                name: details.animal.name,
                                height: 200,
                                fit: BoxFit.contain,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
