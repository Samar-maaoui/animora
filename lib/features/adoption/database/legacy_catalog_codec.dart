import 'dart:convert';

import '../../../core/constants/demo_data.dart';
import '../../users/models/user.dart';
import '../models/animal.dart';
import '../models/favorite.dart';
import '../models/workflow_data.dart';
import '../repositories/local_catalog_database.dart';
import '../repositories/animal_repository.dart';
import '../services/animal_validation.dart';
import '../services/adoption_compatibility_service.dart';

/// Strict import: no silently filtered favorites, overwritten duplicate IDs or reset.
abstract final class LegacyCatalogCodec {
  static CatalogData decode(String? raw) {
    if (raw == null) {
      return CatalogData(
        animals: {for (final a in DemoData.animals) a.id: a},
        favorites: [],
        nextId: 9,
      );
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['version'] != 1) throw const FormatException();
      void unique(List values, String key) {
        final seen = <Object?>{};
        for (final row in values) {
          if (!seen.add((row as Map)[key])) {
            throw const FormatException('Duplicate identifier');
          }
        }
      }

      unique(j['animals'] as List, 'id');
      final workflow = j['workflow'] as Map<String, dynamic>?;
      if (workflow != null) {
        for (final table in [
          'adoptions',
          'questionnaires',
          'contracts',
          'followUps',
          'placements',
        ]) {
          unique(workflow[table] as List, 'id');
        }
        unique(workflow['questionnaires'] as List, 'adoptionId');
        unique(workflow['contracts'] as List, 'adoptionId');
      }
      final animals = (j['animals'] as List).map(
        (v) => Animal.fromJson(Map<String, dynamic>.from(v as Map)),
      );
      return CatalogData(
        animals: {for (final a in animals) a.id: a},
        favorites: (j['favorites'] as List)
            .map((v) => Favorite.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList(),
        nextId: j['nextId'] as int,
        workflow: workflow == null
            ? WorkflowData()
            : WorkflowData.fromJson(workflow),
      );
    } catch (_) {
      throw const CatalogFailure(
        'Le catalogue existant est invalide. Aucune donnée n’a été effacée ; corrigez la source puis réessayez.',
      );
    }
  }

  static void validate(CatalogData d, Map<String, User> users) {
    Never invalid() => throw const CatalogFailure(
      'Relations ou données du catalogue invalides. Le transfert SQLite est annulé sans effacer la source.',
    );
    final w = d.workflow;
    if (d.nextId < 1 || d.animals.keys.any((id) => id < 1 || id >= d.nextId)) {
      invalid();
    }
    for (final e in d.animals.entries) {
      if (e.key != e.value.id) invalid();
      AnimalValidation.validate(e.value);
    }
    final favorites = <String>{};
    for (final f in d.favorites) {
      if (!users.containsKey(f.userId) ||
          !d.animals.containsKey(f.animalId) ||
          !favorites.add(jsonEncode([f.userId, f.animalId]))) {
        invalid();
      }
    }
    for (final e in w.adoptions.entries) {
      final a = e.value;
      if (e.key != a.id ||
          a.id < 1 ||
          !users.containsKey(a.userId) ||
          !d.animals.containsKey(a.animalId) ||
          !a.compatibilityScore.isFinite ||
          a.compatibilityScore < 0 ||
          a.compatibilityScore > 100 ||
          w.applicants[a.id]?.id != a.userId ||
          w.questionnaires[a.id] == null) {
        invalid();
      }
    }
    if (w.applicants.keys.any((id) => !w.adoptions.containsKey(id))) invalid();
    final qids = <int>{};
    for (final e in w.questionnaires.entries) {
      final q = e.value;
      if (e.key != q.adoptionId ||
          q.id < 1 ||
          !qids.add(q.id) ||
          !w.adoptions.containsKey(q.adoptionId)) {
        invalid();
      }
      AdoptionCompatibilityService().validate(q);
    }
    final cids = <int>{};
    for (final e in w.contracts.entries) {
      final c = e.value;
      if (e.key != c.adoptionId ||
          c.id < 1 ||
          !cids.add(c.id) ||
          !w.adoptions.containsKey(c.adoptionId) ||
          c.signed != (c.signatureDate != null)) {
        invalid();
      }
    }
    for (final e in w.followUps.entries) {
      final f = e.value;
      if (e.key != f.id || f.id < 1 || !w.adoptions.containsKey(f.adoptionId)) {
        invalid();
      }
    }
    for (final e in w.placements.entries) {
      final p = e.value;
      if (e.key != p.id ||
          p.id < 1 ||
          !d.animals.containsKey(p.animalId) ||
          !users.containsKey(p.fosterFamilyUserId) ||
          (p.endDate != null && p.endDate!.isBefore(p.startDate))) {
        invalid();
      }
    }
    final ids = [
      ...w.adoptions.values.map((x) => x.id),
      ...w.questionnaires.values.map((x) => x.id),
      ...w.contracts.values.map((x) => x.id),
      ...w.followUps.values.map((x) => x.id),
      ...w.placements.values.map((x) => x.id),
    ];
    if (w.nextId < 1 || ids.any((id) => id >= w.nextId)) invalid();
  }

  static Map<String, int> counts(CatalogData d, Map<String, User> users) => {
    'users': users.length,
    'animals': d.animals.length,
    'favorites': d.favorites.length,
    'adoptions': d.workflow.adoptions.length,
    'adoption_questionnaires': d.workflow.questionnaires.length,
    'adoption_contracts': d.workflow.contracts.length,
    'adoption_followups': d.workflow.followUps.length,
    'foster_placements': d.workflow.placements.length,
  };
}
