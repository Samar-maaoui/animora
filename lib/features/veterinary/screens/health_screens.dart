import '../../../core/widgets/guarded_form.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../animal_services/widgets/services_widgets.dart';
import '../models/vaccination.dart';
import '../models/care.dart';
import '../../adoption/widgets/animal_photo.dart';

class HealthAnimalsScreen extends StatelessWidget {
  const HealthAnimalsScreen({super.key});
  @override
  Widget build(BuildContext c) => ServiceView(
    load: (s) => s.veterinary.getHealthAnimals(),
    builder: (c, animals) => ServicePage(
      title: 'Carnets de santé autorisés',
      children: [
        const Text(
          'Accès réservé au responsable, au vétérinaire traitant et à l’administration. Les données de santé ne sont pas publiques.',
        ),
        if (animals.isEmpty)
          const Text(
            'Aucun carnet accessible. Une adoption signée, un accueil actif ou un rendez-vous confirmé est nécessaire.',
          ),
        ...animals.map(
          (a) => serviceCard([
            Text(
              a.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8,
              children: [
                serviceLink(c, 'Soins', '/animals/${a.id}/health'),
                serviceLink(c, 'Vaccinations', '/animals/${a.id}/vaccinations'),
                serviceLink(c, 'Rappels', '/animals/${a.id}/reminders'),
              ],
            ),
          ]),
        ),
      ],
    ),
  );
}

class AnimalCareHistoryScreen extends StatelessWidget {
  const AnimalCareHistoryScreen({super.key, required this.animalId});
  final int animalId;
  @override
  Widget build(BuildContext c) => ServiceView(
    load: (s) async => (
      await s.veterinary.getHealthAnimal(animalId),
      await s.care.getCare(animalId),
      await s.veterinary.canTreatAnimal(animalId),
    ),
    builder: (c, data) => ServicePage(
      title: 'Santé • ${data.$1.name}',
      children: [
        AnimalPhoto(
          source: data.$1.animalPhoto,
          name: data.$1.name,
          height: 180,
          fit: BoxFit.contain,
        ),
        Wrap(
          spacing: 8,
          children: [
            serviceLink(c, 'Vaccinations', '/animals/$animalId/vaccinations'),
            serviceLink(c, 'Rappels internes', '/animals/$animalId/reminders'),
          ],
        ),
        if (data.$3)
          FilledButton(
            onPressed: () => showDialog<void>(
              context: c,
              builder: (_) => HealthRecordEditor(
                animalId: animalId,
                kind: HealthRecordKind.care,
              ),
            ),
            child: const Text('Enregistrer un soin'),
          ),
        if (data.$2.isEmpty) const Text('Aucun soin enregistré.'),
        ...data.$2.map(
          (v) => serviceCard([
            Text(
              v.type,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            Text('${serviceDate(v.date)} • ${v.veterinarianName}'),
            Text(v.description),
            if (v.cost != null)
              Text('Coût déclaré : ${v.cost!.toStringAsFixed(2)} TND'),
          ]),
        ),
      ],
    ),
  );
}

class VaccinationRecordScreen extends StatelessWidget {
  const VaccinationRecordScreen({super.key, required this.animalId});
  final int animalId;
  @override
  Widget build(BuildContext c) => ServiceView(
    load: (s) async => (
      await s.veterinary.getHealthAnimal(animalId),
      await s.vaccinations.getVaccinations(animalId),
      await s.veterinary.canTreatAnimal(animalId),
    ),
    builder: (c, data) {
      final uid = c.watch<AuthSession>().currentUser?.id;
      return ServicePage(
        title: 'Vaccinations • ${data.$1.name}',
        children: [
          const Text(
            'Seul le vétérinaire traitant enregistre une vaccination. Cette saisie locale ne remplace pas un carnet officiel.',
          ),
          Wrap(
            spacing: 8,
            children: [
              serviceLink(
                c,
                'Historique des soins',
                '/animals/$animalId/health',
              ),
              serviceLink(
                c,
                'Rappels internes',
                '/animals/$animalId/reminders',
              ),
            ],
          ),
          if (data.$3)
            FilledButton(
              onPressed: () => showDialog<void>(
                context: c,
                builder: (_) => HealthRecordEditor(
                  animalId: animalId,
                  kind: HealthRecordKind.vaccination,
                ),
              ),
              child: const Text('Ajouter une vaccination'),
            ),
          if (data.$2.isEmpty) const Text('Aucune vaccination enregistrée.'),
          ...data.$2.map(
            (v) => serviceCard([
              Text(
                v.vaccineName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('${serviceDate(v.vaccinationDate)} • ${v.veterinarianName}'),
              if (v.nextDoseDate != null)
                Text('Prochaine dose : ${serviceDate(v.nextDoseDate!)}'),
              if (v.notes?.isNotEmpty == true) Text(v.notes!),
              if (data.$3 && v.veterinarianUserId == uid)
                OutlinedButton(
                  onPressed: () => showDialog<void>(
                    context: c,
                    builder: (_) => HealthRecordEditor(
                      animalId: animalId,
                      kind: HealthRecordKind.vaccination,
                      initial: v,
                    ),
                  ),
                  child: const Text('Modifier la vaccination'),
                ),
            ]),
          ),
        ],
      );
    },
  );
}

class HealthRemindersScreen extends StatelessWidget {
  const HealthRemindersScreen({super.key, required this.animalId});
  final int animalId;
  @override
  Widget build(BuildContext c) => ServiceView(
    load: (s) async => (
      await s.veterinary.getHealthAnimal(animalId),
      await s.reminders.getReminders(animalId),
      await s.veterinary.canTreatAnimal(animalId) ||
          (await s.veterinary.getResponsibleAnimals()).any(
            (a) => a.id == animalId,
          ),
    ),
    builder: (c, data) => ServicePage(
      title: 'Rappels • ${data.$1.name}',
      children: [
        const Text(
          'Rappels internes uniquement : aucun SMS, e-mail ou notification push n’est envoyé.',
        ),
        Wrap(
          spacing: 8,
          children: [
            serviceLink(c, 'Vaccinations', '/animals/$animalId/vaccinations'),
            serviceLink(c, 'Soins', '/animals/$animalId/health'),
          ],
        ),
        if (data.$3)
          FilledButton(
            onPressed: () => showDialog<void>(
              context: c,
              builder: (_) => HealthRecordEditor(
                animalId: animalId,
                kind: HealthRecordKind.reminder,
              ),
            ),
            child: const Text('Planifier un soin ou un rappel'),
          ),
        if (data.$2.isEmpty)
          const Text(
            'Aucun rappel. Une prochaine dose de vaccin crée automatiquement un rappel.',
          ),
        for (final overdue in [false, true]) ...[
          Text(
            overdue ? 'Dates dépassées' : 'À venir',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          ...data.$2
              .where((r) => r.scheduledDate.isBefore(DateTime.now()) == overdue)
              .map(
                (r) => serviceCard([
                  Text(r.type),
                  Text(serviceDateTime(r.scheduledDate)),
                  serviceBadge(
                    overdue
                        ? 'Date dépassée • à vérifier'
                        : 'À venir • rappel interne',
                  ),
                  const Text('Aucun envoi de notification'),
                ]),
              ),
        ],
      ],
    ),
  );
}

enum HealthRecordKind { vaccination, care, reminder }

class HealthRecordEditor extends StatefulWidget {
  const HealthRecordEditor({
    super.key,
    required this.animalId,
    required this.kind,
    this.initial,
  });
  final int animalId;
  final HealthRecordKind kind;
  final Vaccination? initial;
  @override
  State<HealthRecordEditor> createState() => _HealthRecordEditorState();
}

class _HealthRecordEditorState extends State<HealthRecordEditor> {
  late final name = TextEditingController(text: widget.initial?.vaccineName),
      notes = TextEditingController(text: widget.initial?.notes);
  final cost = TextEditingController();
  late DateTime date =
          widget.initial?.vaccinationDate ??
          (widget.kind == HealthRecordKind.reminder
              ? DateTime.now().add(const Duration(days: 1))
              : DateTime.now()),
      next =
          widget.initial?.nextDoseDate ??
          DateTime.now().add(const Duration(days: 30));
  late bool nextDose = widget.initial?.nextDoseDate != null;
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    notes.dispose();
    cost.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    final s = context.read<ServicesStore>();
    final ok = await serviceAction(context, () async {
      switch (widget.kind) {
        case HealthRecordKind.vaccination:
          await s.vaccinations.saveVaccination(
            Vaccination(
              id: widget.initial?.id ?? 0,
              animalId: widget.animalId,
              veterinarianUserId: '',
              veterinarianName: '',
              vaccineName: name.text,
              vaccinationDate: date,
              nextDoseDate: nextDose ? next : null,
              notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
            ),
            creating: widget.initial == null,
          );
        case HealthRecordKind.care:
          final amount = cost.text.trim().isEmpty
              ? null
              : double.tryParse(cost.text.trim().replaceAll(',', '.'));
          if (cost.text.trim().isNotEmpty && amount == null) {
            throw const ServicesFailure('Saisissez un coût numérique.');
          }
          await s.care.addCare(
            Care(
              id: 0,
              animalId: widget.animalId,
              veterinarianUserId: '',
              veterinarianName: '',
              type: name.text,
              date: date,
              description: notes.text,
              cost: amount,
            ),
          );
        case HealthRecordKind.reminder:
          await s.reminders.addReminder(widget.animalId, name.text, date);
      }
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext c) {
    final vaccination = widget.kind == HealthRecordKind.vaccination,
        care = widget.kind == HealthRecordKind.care;
    return AlertDialog(
      title: Text(
        vaccination
            ? 'Vaccination'
            : care
            ? 'Enregistrer un soin'
            : 'Planifier un rappel',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              serviceField(
                name,
                vaccination
                    ? 'Nom du vaccin'
                    : care
                    ? 'Type de soin'
                    : 'Objet du rappel',
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final d = await servicePickDate(
                    c,
                    date,
                    past: widget.kind != HealthRecordKind.reminder,
                    time: widget.kind == HealthRecordKind.reminder,
                  );
                  if (d != null && mounted) setState(() => date = d);
                },
                child: Text('Date : ${serviceDateTime(date)}'),
              ),
              if (vaccination) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Prévoir une prochaine dose'),
                  value: nextDose,
                  onChanged: GuardedForm.track<bool?>(
                    (v) => setState(() => nextDose = v!),
                  ),
                ),
                if (nextDose)
                  OutlinedButton(
                    onPressed: () async {
                      final d = await servicePickDate(c, next, past: true);
                      if (d != null && mounted) setState(() => next = d);
                    },
                    child: Text('Prochaine dose : ${serviceDate(next)}'),
                  ),
              ],
              if (vaccination || care)
                serviceField(
                  notes,
                  care
                      ? 'Description (10 caractères minimum)'
                      : 'Notes facultatives',
                  lines: 4,
                ),
              if (care) ...[
                const SizedBox(height: 12),
                serviceField(cost, 'Coût en TND (facultatif)'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(c),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
