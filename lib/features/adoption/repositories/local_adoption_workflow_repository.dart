import 'package:flutter/foundation.dart';

import '../../../core/enums/account_status.dart';
import '../../../core/enums/user_profile.dart';
import '../../../core/enums/animal_status.dart';
import '../../../core/enums/adoption_status.dart';
import '../../../core/enums/hebergement_status.dart';
import '../../users/models/user.dart';
import '../models/adoption.dart';
import '../models/questionnaire_adoptant.dart';
import '../models/contrat_adoption.dart';
import '../models/suivi_adoption.dart';
import '../models/hebergement.dart';
import '../models/workflow_data.dart';
import '../services/adoption_compatibility_service.dart';
import 'animal_repository.dart';
import 'local_catalog_database.dart';
import 'adoption_repository.dart';
import 'questionnaire_repository.dart';
import 'adoption_contract_repository.dart';
import 'adoption_follow_up_repository.dart';
import 'foster_placement_repository.dart';

/// All workflow and animal mutations share the existing atomic catalog snapshot.
class LocalAdoptionWorkflowRepository extends ChangeNotifier
    implements
        AdoptionRepository,
        QuestionnaireRepository,
        AdoptionContractRepository,
        AdoptionFollowUpRepository,
        FosterPlacementRepository {
  LocalAdoptionWorkflowRepository(
    this.database,
    this.currentUser, {
    this.listUsers,
    AdoptionCompatibilityService? compatibility,
    DateTime Function()? clock,
  }) : compatibility = compatibility ?? AdoptionCompatibilityService(),
       clock = clock ?? DateTime.now {
    database.addListener(_changed);
  }
  final LocalCatalogDatabase database;
  final User? Function() currentUser;
  final Future<List<User>> Function()? listUsers;
  final AdoptionCompatibilityService compatibility;
  final DateTime Function() clock;
  DateTime _now() => clock().toUtc();
  static const followUpTypes = [
    'Nouvelles à domicile',
    'Visite vétérinaire',
    'Appel de suivi',
  ];
  static const contractConditions =
      'DOCUMENT DE DÉMONSTRATION — aucune valeur juridique revendiquée.\n'
      'L’adoptant confirme pouvoir accueillir cet animal, assurer son alimentation, ses soins et son bien-être, '
      'ne pas l’abandonner et donner des nouvelles après son accueil. '
      'Ces conditions devront être remplacées et validées avant une utilisation réelle.';
  User _actor({String? expected, bool admin = false}) {
    final actor = currentUser();
    if (actor == null ||
        actor.status != AccountStatus.active ||
        (expected != null && actor.id != expected) ||
        (admin && actor.profile != UserProfile.admin)) {
      throw const CatalogFailure(
        'Accès refusé : session active et autorisations requises.',
      );
    }
    return actor;
  }

  bool _admin(User actor) => actor.profile == UserProfile.admin;
  Future<T> _read<T>(T Function(CatalogData, User) action) async {
    final id = _actor().id;
    return database.read((data) => action(data, _actor(expected: id)));
  }

  Future<T> _write<T>(T Function(CatalogData, User) action) async {
    final id = _actor().id;
    return database.mutate((data) => action(data, _actor(expected: id)));
  }

  int _id(WorkflowData data) {
    if (data.nextId >= 9007199254740991) {
      throw const CatalogFailure('Limite des identifiants atteinte.');
    }
    return data.nextId++;
  }

  Adoption _adoption(CatalogData data, int id, User actor) {
    final adoption = data.workflow.adoptions[id];
    if (adoption == null || (!_admin(actor) && adoption.userId != actor.id)) {
      throw const CatalogFailure('Demande introuvable ou accès refusé.');
    }
    return adoption;
  }

  Hebergement _placement(CatalogData data, int id, User actor) {
    final placement = data.workflow.placements[id];
    if (placement == null ||
        (!_admin(actor) &&
            (actor.profile != UserProfile.fosterFamily ||
                placement.fosterFamilyUserId != actor.id))) {
      throw const CatalogFailure('Hébergement introuvable ou accès refusé.');
    }
    return placement;
  }

  @override
  Future<List<Adoption>> getAdoptions() => _read(
    (data, actor) =>
        data.workflow.adoptions.values
            .where((a) => _admin(actor) || a.userId == actor.id)
            .toList()
          ..sort((a, b) => b.applicationDate.compareTo(a.applicationDate)),
  );
  @override
  Future<AdoptionDetails> getAdoption(int id) => _read((data, actor) {
    final a = _adoption(data, id, actor), w = data.workflow;
    final animal = data.animals[a.animalId],
        applicant = w.applicants[id],
        q = w.questionnaires[id];
    if (animal == null || applicant == null || q == null) {
      throw const CatalogFailure('La fiche est incomplète.');
    }
    return AdoptionDetails(
      adoption: a,
      animal: animal,
      applicant: applicant,
      questionnaire: q,
      contract: w.contracts[id],
    );
  });
  Adoption _submit(
    CatalogData data,
    User actor,
    int animalId,
    QuestionnaireAdoptant? q,
    String motivation, {
    int? placementId,
  }) {
    compatibility.validate(q);
    if (motivation.trim().length < 20) {
      throw const CatalogFailure(
        'Expliquez votre motivation en au moins 20 caractères.',
      );
    }
    final animal = data.animals[animalId];
    if (animal == null) throw const CatalogFailure('Animal introuvable.');
    final conversion = placementId == null
        ? null
        : _placement(data, placementId, actor);
    if (conversion != null &&
        (actor.profile != UserProfile.fosterFamily ||
            conversion.fosterFamilyUserId != actor.id ||
            conversion.status != HebergementStatus.ACTIVE ||
            conversion.animalId != animalId)) {
      throw const CatalogFailure(
        'Seule la famille actuellement responsable peut demander cette conversion.',
      );
    }
    if (animal.status != AnimalStatus.AVAILABLE &&
        !(conversion != null && animal.status == AnimalStatus.FOSTERED)) {
      throw const CatalogFailure(
        'Cet animal n’est pas disponible pour une demande.',
      );
    }
    final w = data.workflow;
    if (w.adoptions.values.any(
      (a) =>
          a.animalId == animalId &&
          (a.status == AdoptionStatus.ACCEPTED ||
              (a.userId == actor.id && a.status == AdoptionStatus.PENDING)),
    )) {
      throw const CatalogFailure(
        'Une demande en attente ou acceptée existe déjà.',
      );
    }
    final id = _id(w);
    final adoption = Adoption(
      id: id,
      userId: actor.id,
      animalId: animalId,
      applicationDate: _now(),
      motivation: motivation.trim(),
      compatibilityScore: compatibility.calculate(animal, q!).score,
      status: AdoptionStatus.PENDING,
    );
    w.adoptions[id] = adoption;
    w.questionnaires[id] = QuestionnaireAdoptant(
      id: _id(w),
      adoptionId: id,
      housingType: q.housingType,
      hasChildren: q.hasChildren,
      hasOtherAnimals: q.hasOtherAnimals,
      experience: q.experience,
      availableTime: q.availableTime,
    );
    w.applicants[id] = actor;
    return adoption;
  }

  @override
  Future<Adoption> submitAdoption(
    int animalId,
    QuestionnaireAdoptant? answers,
    String motivation,
  ) => _write(
    (data, actor) => _submit(data, actor, animalId, answers, motivation),
  );
  @override
  Future<void> cancelAdoption(int id) => _write<void>((data, actor) {
    final a = _adoption(data, id, actor);
    if (a.userId != actor.id || a.status != AdoptionStatus.PENDING) {
      throw const CatalogFailure(
        'Seule votre demande en attente peut être annulée.',
      );
    }
    data.workflow.adoptions[id] = a.copyWith(
      status: AdoptionStatus.CANCELLED,
      decisionDate: _now(),
    );
  });
  @override
  Future<void> decideAdoption(int id, {required bool accept}) =>
      _write<void>((data, actor) {
        if (!_admin(actor)) {
          throw const CatalogFailure('Décision réservée à l’administrateur.');
        }
        final a = _adoption(data, id, actor), w = data.workflow;
        if (a.status != AdoptionStatus.PENDING) {
          throw const CatalogFailure('Cette demande a déjà reçu une décision.');
        }
        final now = _now();
        if (!accept) {
          w.adoptions[id] = a.copyWith(
            status: AdoptionStatus.REJECTED,
            decisionDate: now,
          );
          return;
        }
        final animal = data.animals[a.animalId];
        if (animal == null ||
            ![
              AnimalStatus.AVAILABLE,
              AnimalStatus.FOSTERED,
            ].contains(animal.status) ||
            w.adoptions.values.any(
              (other) =>
                  other.animalId == a.animalId &&
                  other.status == AdoptionStatus.ACCEPTED,
            )) {
          throw const CatalogFailure(
            'Cet animal est déjà réservé ou n’est plus disponible.',
          );
        }
        if (w.questionnaires[id] == null) {
          throw const CatalogFailure('Le questionnaire est obligatoire.');
        }
        w.adoptions[id] = a.copyWith(
          status: AdoptionStatus.ACCEPTED,
          decisionDate: now,
        );
        w.contracts[id] = ContratAdoption(
          id: _id(w),
          adoptionId: id,
          conditions: contractConditions,
          signed: false,
        );
        for (final other in w.adoptions.values.toList()) {
          if (other.id != id &&
              other.animalId == a.animalId &&
              other.status == AdoptionStatus.PENDING) {
            w.adoptions[other.id] = other.copyWith(
              status: AdoptionStatus.REJECTED,
              decisionDate: now,
            );
          }
        }
        data.animals[animal.id] = animal.copyWith(
          status: AnimalStatus.PENDING_ADOPTION,
        );
      });
  @override
  Future<QuestionnaireAdoptant> updateQuestionnaire(
    int adoptionId,
    QuestionnaireAdoptant answers,
  ) => _write((data, actor) {
    final a = _adoption(data, adoptionId, actor);
    if (a.userId != actor.id || a.status != AdoptionStatus.PENDING) {
      throw const CatalogFailure(
        'Seul le demandeur peut modifier son questionnaire en attente.',
      );
    }
    compatibility.validate(answers);
    final old = data.workflow.questionnaires[adoptionId];
    if (old == null) throw const CatalogFailure('Questionnaire introuvable.');
    final q = QuestionnaireAdoptant(
      id: old.id,
      adoptionId: adoptionId,
      housingType: answers.housingType,
      hasChildren: answers.hasChildren,
      hasOtherAnimals: answers.hasOtherAnimals,
      experience: answers.experience,
      availableTime: answers.availableTime,
    );
    data.workflow.questionnaires[adoptionId] = q;
    data.workflow.adoptions[adoptionId] = Adoption(
      id: a.id,
      userId: a.userId,
      animalId: a.animalId,
      applicationDate: a.applicationDate,
      motivation: a.motivation,
      compatibilityScore: compatibility
          .calculate(data.animals[a.animalId]!, q)
          .score,
      status: a.status,
      decisionDate: a.decisionDate,
      adoptionDate: a.adoptionDate,
    );
    return q;
  });
  @override
  Future<QuestionnaireAdoptant> getQuestionnaire(int adoptionId) async =>
      (await getAdoption(adoptionId)).questionnaire;
  @override
  Future<ContratAdoption> getContract(int adoptionId) async {
    final details = await getAdoption(adoptionId);
    if (details.adoption.status != AdoptionStatus.ACCEPTED ||
        details.contract == null) {
      throw const CatalogFailure('Aucun contrat pour cette demande.');
    }
    return details.contract!;
  }

  @override
  Future<void> signContract(
    int adoptionId, {
    required bool confirmed,
  }) => _write<void>((data, actor) {
    final a = _adoption(data, adoptionId, actor), w = data.workflow;
    final contract = w.contracts[adoptionId], animal = data.animals[a.animalId];
    if (!confirmed ||
        a.userId != actor.id ||
        a.status != AdoptionStatus.ACCEPTED ||
        contract == null ||
        contract.signed ||
        animal?.status != AnimalStatus.PENDING_ADOPTION) {
      throw const CatalogFailure(
        'Signature impossible : confirmation explicite de l’adoptant requise.',
      );
    }
    final now = _now();
    w.contracts[adoptionId] = contract.sign(now);
    w.adoptions[adoptionId] = a.copyWith(adoptionDate: now);
    data.animals[a.animalId] = animal!.copyWith(status: AnimalStatus.ADOPTED);
    for (final placement in w.placements.values.toList()) {
      if (placement.animalId == a.animalId &&
          placement.status == HebergementStatus.ACTIVE) {
        w.placements[placement.id] = placement.copyWith(
          status: HebergementStatus.COMPLETED,
          endDate: now,
        );
      }
    }
  });
  Adoption _effective(CatalogData data, int id, User actor) {
    final a = _adoption(data, id, actor);
    if (a.status != AdoptionStatus.ACCEPTED ||
        a.adoptionDate == null ||
        data.workflow.contracts[id]?.signed != true) {
      throw const CatalogFailure(
        'Le suivi est disponible après signature du contrat.',
      );
    }
    return a;
  }

  @override
  Future<List<SuiviAdoption>> getFollowUps(int adoptionId) =>
      _read((data, actor) {
        _effective(data, adoptionId, actor);
        return data.workflow.followUps.values
            .where((f) => f.adoptionId == adoptionId)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      });
  @override
  Future<void> addFollowUp(
    int adoptionId, {
    required String news,
    required String visitType,
    String? photo,
  }) => _write<void>((data, actor) {
    final a = _effective(data, adoptionId, actor);
    if (a.userId != actor.id) {
      throw const CatalogFailure('Seul l’adoptant peut ajouter ses nouvelles.');
    }
    if (news.trim().length < 10 || !followUpTypes.contains(visitType)) {
      throw const CatalogFailure(
        'Ajoutez au moins 10 caractères et un type de suivi.',
      );
    }
    if (photo != null &&
        (!photo.startsWith('data:image/') || photo.length > 1500000)) {
      throw const CatalogFailure(
        'Photo de suivi invalide ou trop volumineuse.',
      );
    }
    final id = _id(data.workflow);
    data.workflow.followUps[id] = SuiviAdoption(
      id: id,
      adoptionId: adoptionId,
      date: _now(),
      news: news.trim(),
      visitType: visitType,
      photo: photo,
    );
  });
  @override
  Future<List<Hebergement>> getPlacements() => _read((data, actor) {
    if (!_admin(actor) && actor.profile != UserProfile.fosterFamily) {
      throw const CatalogFailure('Espace réservé aux familles d’accueil.');
    }
    return data.workflow.placements.values
        .where((p) => _admin(actor) || p.fosterFamilyUserId == actor.id)
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  });
  @override
  Future<Hebergement> getPlacement(int id) =>
      _read((data, actor) => _placement(data, id, actor));
  @override
  Future<List<User>> getActiveFamilies() async {
    final actor = _actor(admin: true);
    final users = await listUsers?.call() ?? <User>[];
    _actor(expected: actor.id, admin: true);
    return users
        .where(
          (u) =>
              u.profile == UserProfile.fosterFamily &&
              u.status == AccountStatus.active,
        )
        .toList();
  }

  @override
  Future<Hebergement> assignPlacement(
    int animalId,
    String familyId,
    DateTime startDate, {
    String remarks = '',
  }) async {
    final actor = _actor(admin: true);
    final families = await getActiveFamilies();
    _actor(expected: actor.id, admin: true);
    if (!families.any((f) => f.id == familyId)) {
      throw const CatalogFailure('Choisissez une famille d’accueil active.');
    }
    return _write((data, user) {
      if (!_admin(user)) {
        throw const CatalogFailure('Affectation réservée à l’administrateur.');
      }
      final animal = data.animals[animalId], w = data.workflow;
      if (animal?.status != AnimalStatus.AVAILABLE ||
          w.placements.values.any(
            (p) =>
                p.animalId == animalId && p.status == HebergementStatus.ACTIVE,
          ) ||
          w.adoptions.values.any(
            (a) =>
                a.animalId == animalId && a.status == AdoptionStatus.ACCEPTED,
          )) {
        throw const CatalogFailure(
          'Cet animal est déjà hébergé, réservé ou indisponible.',
        );
      }
      if (startDate.toUtc().isAfter(_now())) {
        throw const CatalogFailure('La date de début ne peut pas être future.');
      }
      final id = _id(w);
      final placement = Hebergement(
        id: id,
        animalId: animalId,
        fosterFamilyUserId: familyId,
        startDate: startDate.toUtc(),
        status: HebergementStatus.ACTIVE,
        remarks: remarks.trim(),
      );
      w.placements[id] = placement;
      data.animals[animalId] = animal!.copyWith(status: AnimalStatus.FOSTERED);
      return placement;
    });
  }

  @override
  Future<void> addPlacementRemark(int id, String remark) => _write<void>((
    data,
    actor,
  ) {
    final p = _placement(data, id, actor);
    if (p.status != HebergementStatus.ACTIVE || remark.trim().isEmpty) {
      throw const CatalogFailure(
        'Ajoutez une remarque à un hébergement en cours.',
      );
    }
    data.workflow.placements[id] = p.copyWith(
      remarks:
          '${p.remarks}${p.remarks.isEmpty ? '' : '\n'}${_now().toIso8601String()} — ${remark.trim()}',
    );
  });
  @override
  Future<void> finishPlacement(
    int id, {
    bool cancel = false,
    AnimalStatus releaseStatus = AnimalStatus.AVAILABLE,
  }) => _write<void>((data, actor) {
    final p = _placement(data, id, actor), w = data.workflow;
    if (p.status != HebergementStatus.ACTIVE || (cancel && !_admin(actor))) {
      throw const CatalogFailure('Cette action n’est pas autorisée.');
    }
    if (!_admin(actor) && releaseStatus != AnimalStatus.AVAILABLE) {
      throw const CatalogFailure(
        'La famille termine l’accueil avec remise à disposition.',
      );
    }
    if (![
      AnimalStatus.AVAILABLE,
      AnimalStatus.LOST,
      AnimalStatus.FOUND,
    ].contains(releaseStatus)) {
      throw const CatalogFailure('Statut de sortie invalide.');
    }
    final animal = data.animals[p.animalId];
    if (animal == null || _now().isBefore(p.startDate)) {
      throw const CatalogFailure('Date de fin ou animal invalide.');
    }
    final accepted = w.adoptions.values
        .where(
          (a) =>
              a.animalId == p.animalId && a.status == AdoptionStatus.ACCEPTED,
        )
        .firstOrNull;
    final status = accepted == null
        ? releaseStatus
        : accepted.adoptionDate == null
        ? AnimalStatus.PENDING_ADOPTION
        : AnimalStatus.ADOPTED;
    w.placements[id] = p.copyWith(
      status: cancel
          ? HebergementStatus.CANCELLED
          : HebergementStatus.COMPLETED,
      endDate: _now(),
    );
    data.animals[p.animalId] = animal.copyWith(status: status);
  });
  @override
  Future<Adoption> convertToAdoption(
    int placementId,
    QuestionnaireAdoptant? answers,
    String motivation,
  ) => _write((data, actor) {
    final p = _placement(data, placementId, actor);
    return _submit(
      data,
      actor,
      p.animalId,
      answers,
      motivation,
      placementId: placementId,
    );
  });
  void _changed() => notifyListeners();
  @override
  void dispose() {
    database.removeListener(_changed);
    super.dispose();
  }
}
