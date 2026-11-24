import '../../../core/widgets/guarded_form.dart';
import '../../../core/widgets/navigation_app_bar.dart';
import '../../adoption/widgets/breed_information.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/animal_status.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../adoption/models/animal.dart';
import '../../adoption/repositories/animal_repository.dart';
import '../../adoption/services/animal_image_picker.dart';
import '../../adoption/services/animal_validation.dart';
import '../../adoption/state/adoption_store.dart';
import '../../adoption/widgets/animal_photo.dart';

class AnimalFormScreen extends StatefulWidget {
  const AnimalFormScreen({super.key, this.id});
  final int? id;
  @override
  State<AnimalFormScreen> createState() => _AnimalFormScreenState();
}

class _AnimalFormScreenState extends State<AnimalFormScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in [
      'name',
      'breed',
      'age',
      'weight',
      'color',
      'health',
      'character',
      'microchip',
      'city',
    ])
      key: TextEditingController(),
  };
  String? _species, _sex;
  AnimalStatus? _status;
  bool _sterilized = false, _loading = false, _picking = false;
  String _photo = '';
  String? _error, _loadError;
  Animal? _original;
  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      _loading = true;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    try {
      final animal = await context
          .read<AdoptionStore>()
          .animalsRepository
          .getAnimalById(widget.id!);
      if (!mounted) return;
      if (animal == null) {
        setState(() {
          _loadError = 'Cet animal n’existe plus.';
          _loading = false;
        });
        return;
      }
      final values = {
        'name': animal.name,
        'breed': animal.breed,
        'age': animal.age.toString(),
        'weight': animal.weight.toString(),
        'color': animal.color,
        'health': animal.health,
        'character': animal.character,
        'microchip': animal.microchipNumber,
        'city': animal.city,
      };
      for (final entry in values.entries) {
        _fields[entry.key]!.text = entry.value;
      }
      setState(() {
        _original = animal;
        _species = animal.species;
        _sex = animal.sex;
        _status = animal.status;
        _sterilized = animal.sterilized;
        _photo = animal.animalPhoto;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = catalogErrorMessage(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickPhoto() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final image = await AnimalImagePicker().pick();
      if (mounted && image != null) setState(() => _photo = image);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is CatalogFailure
              ? error.message
              : 'Impossible de lire cette image. Choisissez une autre photo.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_photo.isEmpty) {
      setState(() => _error = 'Choisissez une photo de l’animal.');
      return;
    }
    try {
      final animal = Animal(
        id: _original?.id ?? 0,
        name: _fields['name']!.text.trim(),
        species: _species!,
        breed: _fields['breed']!.text.trim(),
        sex: _sex!,
        age: int.parse(_fields['age']!.text.trim()),
        weight: double.parse(_fields['weight']!.text.replaceAll(',', '.')),
        color: _fields['color']!.text.trim(),
        sterilized: _sterilized,
        health: _fields['health']!.text.trim(),
        character: _fields['character']!.text.trim(),
        microchipNumber: _fields['microchip']!.text.trim(),
        animalPhoto: _photo,
        city: _fields['city']!.text.trim(),
        status: _status!,
        arrivalDate: _original?.arrivalDate ?? DateTime.now().toUtc(),
      );
      await context.read<AdoptionStore>().save(
        animal,
        creating: widget.id == null,
      );
      if (mounted) GuardedForm.savedGo(context, '/admin/animals');
    } catch (error) {
      if (mounted) setState(() => _error = catalogErrorMessage(error));
    }
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String name,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
  }) => AppTextField(
    key: ValueKey('animal-$name'),
    label: label,
    controller: _fields[name],
    validator: validator ?? FormValidators.requiredText,
    keyboardType: keyboard,
    enabled: !context.read<AdoptionStore>().busy && !_picking,
  );
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdoptionStore>();
    final disabled = store.busy || _picking;
    return Scaffold(
      appBar: NavigationAppBar(
        title: Text(
          widget.id == null ? 'Ajouter un animal' : 'Modifier un animal',
        ),
      ),
      body: _loading
          ? const LoadingWidget()
          : _loadError != null
          ? Center(child: Text(_loadError!, textAlign: TextAlign.center))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: GuardedForm(
                    formKey: _form,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_photo.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: AnimalPhoto(
                              source: _photo,
                              name: _fields['name']!.text,
                              height: 200,
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: disabled ? null : _pickPhoto,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            _picking
                                ? 'Lecture de la photo…'
                                : 'Choisir une photo',
                          ),
                        ),
                        const Text(
                          'Photo obligatoire · 1 Mo maximum · stockage local temporaire.',
                        ),
                        const SizedBox(height: 16),
                        _field('name', 'Nom'),
                        DropdownButtonFormField<String>(
                          initialValue: _species,
                          decoration: const InputDecoration(
                            labelText: 'Espèce',
                          ),
                          items: [
                            for (final species in {
                              'Chien',
                              'Chat',
                              'Lapin',
                              'Autre',
                              ?_species,
                            })
                              DropdownMenuItem(
                                value: species,
                                child: Text(species),
                              ),
                          ],
                          onChanged: disabled
                              ? null
                              : (value) => setState(() => _species = value),
                          validator: (value) =>
                              value == null ? 'Choisissez une espèce.' : null,
                        ),
                        const SizedBox(height: 16),
                        _field('breed', 'Race'),
                        if (_species == 'Chien' || _species == 'Chat')
                          BreedInformation(
                            species: _species!,
                            onSelected: (v) =>
                                setState(() => _fields['breed']!.text = v),
                          ),
                        DropdownButtonFormField<String>(
                          initialValue: _sex,
                          decoration: const InputDecoration(labelText: 'Sexe'),
                          items: [
                            for (final sex in {
                              'Femelle',
                              'Mâle',
                              'Inconnu',
                              ?_sex,
                            })
                              DropdownMenuItem(value: sex, child: Text(sex)),
                          ],
                          onChanged: disabled
                              ? null
                              : (value) => setState(() => _sex = value),
                          validator: (value) =>
                              value == null ? 'Choisissez le sexe.' : null,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          'age',
                          'Âge (années entières)',
                          validator: AnimalValidation.nonNegativeInteger,
                          keyboard: TextInputType.number,
                        ),
                        _field(
                          'weight',
                          'Poids (kg)',
                          validator: AnimalValidation.positiveWeight,
                          keyboard: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        _field('color', 'Couleur'),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Stérilisé'),
                          value: _sterilized,
                          onChanged: GuardedForm.track<bool>(
                            disabled
                                ? null
                                : (value) =>
                                      setState(() => _sterilized = value),
                          ),
                        ),
                        _field('health', 'Santé'),
                        _field('character', 'Caractère'),
                        _field(
                          'microchip',
                          'Numéro de puce (facultatif)',
                          validator: (_) => null,
                        ),
                        _field('city', 'Ville'),
                        DropdownButtonFormField<AnimalStatus>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Statut',
                          ),
                          items: [
                            for (final status in AnimalStatus.values)
                              DropdownMenuItem(
                                value: status,
                                child: Text(status.label),
                              ),
                          ],
                          onChanged: disabled
                              ? null
                              : (value) => setState(() => _status = value),
                          validator: (value) =>
                              value == null ? 'Choisissez un statut.' : null,
                        ),
                        const SizedBox(height: 20),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        AppButton(
                          label: 'Enregistrer l’animal',
                          loading: store.busy,
                          onPressed: disabled ? null : _save,
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
