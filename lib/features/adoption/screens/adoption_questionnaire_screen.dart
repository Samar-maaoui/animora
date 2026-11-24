import '../../../core/widgets/guarded_form.dart';
import '../../../core/widgets/navigation_app_bar.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/animal_status.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../models/questionnaire_adoptant.dart';
import '../models/adoption.dart';
import '../services/adoption_compatibility_service.dart';
import '../state/adoption_store.dart';
import '../state/adoption_workflow_store.dart';
import '../widgets/workflow_widgets.dart';

class AdoptionQuestionnaireScreen extends StatefulWidget {
  const AdoptionQuestionnaireScreen({
    super.key,
    required this.animalId,
    this.placementId,
  });
  final int animalId;
  final int? placementId;
  @override
  State<AdoptionQuestionnaireScreen> createState() =>
      _AdoptionQuestionnaireScreenState();
}

class _AdoptionQuestionnaireScreenState
    extends State<AdoptionQuestionnaireScreen> {
  final _questions = GlobalKey<FormState>(),
      _motivationForm = GlobalKey<FormState>();
  final _motivation = TextEditingController();
  final _scroll = ScrollController();
  final _compatibility = AdoptionCompatibilityService();
  String? _housing, _experience, _time;
  bool? _children, _animals;
  int _step = 0;
  CompatibilityResult? _result;
  QuestionnaireAdoptant _answers() => QuestionnaireAdoptant(
    id: 0,
    adoptionId: 0,
    housingType: _housing!,
    hasChildren: _children!,
    hasOtherAnimals: _animals!,
    experience: _experience!,
    availableTime: _time!,
  );
  @override
  void dispose() {
    _motivation.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _move(int step) {
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Widget _choice<T>(
    String label,
    T? selected,
    List<T> values,
    String Function(T) display,
    ValueChanged<T?> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<T>(
      key: ValueKey(label),
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final value in values)
          DropdownMenuItem(value: value, child: Text(display(value))),
      ],
      onChanged: changed,
      validator: (value) => value == null ? 'Réponse obligatoire.' : null,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<AdoptionStore>();
    final store = context.watch<AdoptionWorkflowStore>();
    final animal = catalog.byId(widget.animalId);
    if (catalog.loading) {
      return const WorkflowPage(
        title: 'Questionnaire d’adoption',
        child: CircularProgressIndicator(),
      );
    }
    if (animal == null ||
        !(animal.status == AnimalStatus.AVAILABLE ||
            (widget.placementId != null &&
                animal.status == AnimalStatus.FOSTERED))) {
      return const WorkflowPage(
        title: 'Questionnaire d’adoption',
        child: Text('Cet animal n’est plus disponible pour cette demande.'),
      );
    }
    return Scaffold(
      appBar: NavigationAppBar(title: const Text('Questionnaire d’adoption')),
      body: GuardedForm(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pour ${animal.name}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('Étape ${_step + 1} sur 3'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_step + 1) / 3,
                    color: AppColors.adoption,
                  ),
                  const SizedBox(height: 24),
                  if (_step == 0)
                    GuardedForm(
                      formKey: _questions,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        children: [
                          _choice(
                            'Type de logement',
                            _housing,
                            AdoptionCompatibilityService.housingTypes,
                            (v) => v,
                            (v) => setState(() => _housing = v),
                          ),
                          _choice(
                            'Avez-vous des enfants ?',
                            _children,
                            [true, false],
                            (v) => v ? 'Oui' : 'Non',
                            (v) => setState(() => _children = v),
                          ),
                          _choice(
                            'Avez-vous d’autres animaux ?',
                            _animals,
                            [true, false],
                            (v) => v ? 'Oui' : 'Non',
                            (v) => setState(() => _animals = v),
                          ),
                          _choice(
                            'Expérience avec les animaux',
                            _experience,
                            AdoptionCompatibilityService.experiences,
                            (v) => v,
                            (v) => setState(() => _experience = v),
                          ),
                          _choice(
                            'Temps quotidien disponible',
                            _time,
                            AdoptionCompatibilityService.availableTimes,
                            (v) => v,
                            (v) => setState(() => _time = v),
                          ),
                        ],
                      ),
                    ),
                  if (_step == 1) ...[
                    CompatibilitySummary(
                      score: _result!.score,
                      explanations: _result!.explanations,
                    ),
                    const SizedBox(height: 16),
                    GuardedForm(
                      formKey: _motivationForm,
                      child: AppTextField(
                        label: 'Votre motivation',
                        controller: _motivation,
                        validator: (v) => v == null || v.trim().length < 20
                            ? 'Expliquez votre motivation en au moins 20 caractères.'
                            : null,
                      ),
                    ),
                  ],
                  if (_step == 2) ...[
                    WorkflowInfo(
                      title: 'Récapitulatif pour ${animal.name}',
                      values: {
                        'Logement': _housing!,
                        'Enfants': _children! ? 'Oui' : 'Non',
                        'Autres animaux': _animals! ? 'Oui' : 'Non',
                        'Expérience': _experience!,
                        'Temps disponible': _time!,
                        'Motivation': _motivation.text.trim(),
                      },
                    ),
                    CompatibilitySummary(score: _result!.score),
                    const Text(
                      'La demande sera examinée par un administrateur. Ce score ne vaut ni accord ni refus.',
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_step > 0)
                    TextButton(
                      onPressed: store.busy ? null : () => _move(_step - 1),
                      child: const Text('Précédent'),
                    ),
                  AppButton(
                    label: _step == 2 ? 'Confirmer la demande' : 'Continuer',
                    loading: store.busy,
                    onPressed: () async {
                      if (_step == 0) {
                        if (!_questions.currentState!.validate()) return;
                        _result = _compatibility.calculate(animal, _answers());
                        _move(1);
                      } else if (_step == 1) {
                        if (_motivationForm.currentState!.validate()) _move(2);
                      } else {
                        Adoption? created;
                        final success = await runWorkflow(context, () async {
                          created = widget.placementId == null
                              ? await store.adoptions.submitAdoption(
                                  animal.id,
                                  _answers(),
                                  _motivation.text,
                                )
                              : await store.placements.convertToAdoption(
                                  widget.placementId!,
                                  _answers(),
                                  _motivation.text,
                                );
                        }, success: 'Votre demande a été enregistrée.');
                        if (success && context.mounted) {
                          GuardedForm.savedGo(
                            context,
                            '/adoptions/${created!.id}',
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
