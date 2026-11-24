import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:animora/core/enums/adoption_status.dart';
import 'package:animora/core/enums/animal_status.dart';
import 'package:animora/core/enums/hebergement_status.dart';
import 'package:animora/features/adoption/models/questionnaire_adoptant.dart';
import 'package:animora/features/adoption/repositories/animal_repository.dart';
import 'package:animora/features/adoption/repositories/local_adoption_workflow_repository.dart';
import 'package:animora/features/adoption/services/adoption_compatibility_service.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';

import 'support/catalog_test_support.dart';
import 'adoption_repository_test.dart' show Harness;

QuestionnaireAdoptant answers({
  String? housing,
  String? experience,
  String? time,
}) => QuestionnaireAdoptant(
  id: 0,
  adoptionId: 0,
  housingType: housing ?? AdoptionCompatibilityService.housingTypes[1],
  hasChildren: false,
  hasOtherAnimals: false,
  experience: experience ?? AdoptionCompatibilityService.experiences[2],
  availableTime: time ?? AdoptionCompatibilityService.availableTimes[2],
);
const motivation =
    'Je souhaite accueillir cet animal et assurer son bien-être durablement.';
void main() {
  late Harness h;
  late LocalAdoptionWorkflowRepository repo;
  final citizen = DemoAccounts.users.first,
      foster = DemoAccounts.users.firstWhere((u) => u.id == 'demo-foster');
  final now = DateTime.utc(2026, 11, 9, 12);
  setUp(() {
    h = Harness();
    repo = LocalAdoptionWorkflowRepository(
      h.db,
      () => h.actor,
      listUsers: () async => DemoAccounts.users,
      clock: () => now,
    );
  });
  tearDown(() {
    repo.dispose();
    h.dispose();
  });
  test(
    'Mandatory questionnaire and motivation are persisted with one adoption',
    () async {
      await expectLater(
        repo.submitAdoption(1, null, motivation),
        throwsA(isA<CatalogFailure>()),
      );
      await expectLater(
        repo.submitAdoption(1, answers(housing: ''), motivation),
        throwsA(isA<CatalogFailure>()),
      );
      await expectLater(
        repo.submitAdoption(1, answers(), 'court'),
        throwsA(isA<CatalogFailure>()),
      );
      expect(await repo.getAdoptions(), isEmpty);
      final a = await repo.submitAdoption(1, answers(), motivation);
      expect(a.status, AdoptionStatus.PENDING);
      expect(a.applicationDate, now);
      expect(a.userId, citizen.id);
      final q = await repo.getQuestionnaire(a.id);
      expect(q.adoptionId, a.id);
      expect(q.housingType, answers().housingType);
      expect((await repo.getAdoption(a.id)).applicant.id, citizen.id);
      expect(
        (await h.animals.getAnimalById(1))!.status,
        AnimalStatus.AVAILABLE,
      );
    },
  );
  test(
    'Score is weighted, bounded, deterministic and never decides acceptance',
    () async {
      final animal = (await h.animals.getAnimalById(1))!;
      final service = AdoptionCompatibilityService();
      expect(service.calculate(animal, answers()).score, 100);
      final novice = answers(
        housing: AdoptionCompatibilityService.housingTypes[2],
        experience: AdoptionCompatibilityService.experiences[0],
        time: AdoptionCompatibilityService.availableTimes[0],
      );
      final result = service.calculate(animal, novice);
      expect(result.score, inInclusiveRange(0, 100));
      expect(result.score, lessThan(100));
      expect(result.explanations.length, 6);
      final a = await repo.submitAdoption(1, novice, motivation);
      expect(a.compatibilityScore, result.score);
      expect(a.status, AdoptionStatus.PENDING);
      expect(
        () => AdoptionCompatibilityService(weights: {'housing': 100}),
        throwsArgumentError,
      );
    },
  );
  test('Duplicate pending and accepted applications are rejected; cancelled may retry', () async {
    final a = await repo.submitAdoption(1, answers(), motivation);
    await expectLater(
      repo.submitAdoption(1, answers(), motivation),
      throwsA(isA<CatalogFailure>()),
    );
    await repo.cancelAdoption(a.id);
    expect(
      (await repo.getAdoption(a.id)).adoption.status,
      AdoptionStatus.CANCELLED,
    );
    final b = await repo.submitAdoption(1, answers(), motivation);
    h.admin();
    await repo.decideAdoption(b.id, accept: true);
    h.actor = citizen;
    await expectLater(
      repo.submitAdoption(1, answers(), motivation),
      throwsA(isA<CatalogFailure>()),
    );
    await expectLater(
      repo.cancelAdoption(b.id),
      throwsA(isA<CatalogFailure>()),
    );
  });
  test('Owners cannot inspect, cancel, read questionnaires or contracts of another user', () async {
    final a = await repo.submitAdoption(1, answers(), motivation);
    h.actor = DemoAccounts.users[1];
    expect(await repo.getAdoptions(), isEmpty);
    await expectLater(repo.getAdoption(a.id), throwsA(isA<CatalogFailure>()));
    await expectLater(
      repo.cancelAdoption(a.id),
      throwsA(isA<CatalogFailure>()),
    );
    await expectLater(
      repo.getQuestionnaire(a.id),
      throwsA(isA<CatalogFailure>()),
    );
    await expectLater(repo.getContract(a.id), throwsA(isA<CatalogFailure>()));
    await expectLater(
      repo.decideAdoption(a.id, accept: true),
      throwsA(isA<CatalogFailure>()),
    );
  });
  test(
    'Rejection records decision date and never creates a contract',
    () async {
      final a = await repo.submitAdoption(1, answers(), motivation);
      h.admin();
      await repo.decideAdoption(a.id, accept: false);
      final detail = await repo.getAdoption(a.id);
      expect(detail.adoption.status, AdoptionStatus.REJECTED);
      expect(detail.adoption.decisionDate, now);
      expect(detail.contract, isNull);
      await expectLater(repo.getContract(a.id), throwsA(isA<CatalogFailure>()));
      expect(
        (await h.animals.getAnimalById(1))!.status,
        AnimalStatus.AVAILABLE,
      );
    },
  );
  test('Acceptance reserves the animal, prepares an unsigned contract and rejects competitors', () async {
    final a = await repo.submitAdoption(1, answers(), motivation);
    h.actor = DemoAccounts.users[1];
    final b = await repo.submitAdoption(1, answers(), motivation);
    h.admin();
    await repo.decideAdoption(a.id, accept: true);
    final details = await repo.getAdoption(a.id);
    expect(details.adoption.status, AdoptionStatus.ACCEPTED);
    expect(details.adoption.decisionDate, now);
    expect(details.contract!.signed, isFalse);
    expect(details.adoption.adoptionDate, isNull);
    expect(
      (await repo.getAdoption(b.id)).adoption.status,
      AdoptionStatus.REJECTED,
    );
    expect((await repo.getAdoption(b.id)).contract, isNull);
    expect(
      (await h.animals.getAnimalById(1))!.status,
      AnimalStatus.PENDING_ADOPTION,
    );
    await expectLater(
      repo.decideAdoption(b.id, accept: true),
      throwsA(isA<CatalogFailure>()),
    );
  });
  test(
    'Concurrent decisions cannot accept two requests for the same animal',
    () async {
      final a = await repo.submitAdoption(1, answers(), motivation);
      h.actor = DemoAccounts.users[1];
      final b = await repo.submitAdoption(1, answers(), motivation);
      h.admin();
      final results = await Future.wait(
        [
          repo.decideAdoption(a.id, accept: true),
          repo.decideAdoption(b.id, accept: true),
        ].map((task) async {
          try {
            await task;
            return true;
          } on CatalogFailure {
            return false;
          }
        }),
      );
      expect(results.where((v) => v).length, 1);
      expect(
        (await repo.getAdoptions())
            .where((a) => a.status == AdoptionStatus.ACCEPTED)
            .length,
        1,
      );
    },
  );
  test('Only the owner can sign explicitly and signature atomically adopts the animal', () async {
    final a = await repo.submitAdoption(1, answers(), motivation);
    h.admin();
    await repo.decideAdoption(a.id, accept: true);
    await expectLater(
      repo.signContract(a.id, confirmed: true),
      throwsA(isA<CatalogFailure>()),
    );
    h.actor = citizen;
    await expectLater(
      repo.signContract(a.id, confirmed: false),
      throwsA(isA<CatalogFailure>()),
    );
    await repo.signContract(a.id, confirmed: true);
    final details = await repo.getAdoption(a.id);
    expect(details.contract!.signed, isTrue);
    expect(details.contract!.signatureDate, now);
    expect(details.adoption.adoptionDate, now);
    expect(details.animal.status, AnimalStatus.ADOPTED);
    await expectLater(
      repo.signContract(a.id, confirmed: true),
      throwsA(isA<CatalogFailure>()),
    );
  });
  test('Follow-ups require an effective adoption and are private, with admin read-only access', () async {
    final a = await repo.submitAdoption(1, answers(), motivation);
    await expectLater(repo.getFollowUps(a.id), throwsA(isA<CatalogFailure>()));
    h.admin();
    await repo.decideAdoption(a.id, accept: true);
    h.actor = citizen;
    await expectLater(
      repo.addFollowUp(
        a.id,
        news: 'Tout va bien à la maison.',
        visitType: 'Nouvelles à domicile',
      ),
      throwsA(isA<CatalogFailure>()),
    );
    await repo.signContract(a.id, confirmed: true);
    await repo.addFollowUp(
      a.id,
      news: 'Tout va bien à la maison.',
      visitType: 'Nouvelles à domicile',
      photo: 'data:image/png;base64,aGVsbG8=',
    );
    expect(
      (await repo.getFollowUps(a.id)).single.news,
      'Tout va bien à la maison.',
    );
    h.actor = DemoAccounts.users[1];
    await expectLater(repo.getFollowUps(a.id), throwsA(isA<CatalogFailure>()));
    h.admin();
    expect((await repo.getFollowUps(a.id)).length, 1);
    await expectLater(
      repo.addFollowUp(
        a.id,
        news: 'Une visite de contrôle.',
        visitType: 'Visite vétérinaire',
      ),
      throwsA(isA<CatalogFailure>()),
    );
  });
  test(
    'Acceptance and signature roll back completely if persistence fails',
    () async {
      final a = await repo.submitAdoption(1, answers(), motivation);
      h.admin();
      final before = h.storage.value;
      h.storage.failWrites = true;
      await expectLater(
        repo.decideAdoption(a.id, accept: true),
        throwsA(isA<CatalogFailure>()),
      );
      expect(h.storage.value, before);
      expect(
        (await repo.getAdoption(a.id)).adoption.status,
        AdoptionStatus.PENDING,
      );
      expect((await repo.getAdoption(a.id)).contract, isNull);
      expect(
        (await h.animals.getAnimalById(1))!.status,
        AnimalStatus.AVAILABLE,
      );
      h.storage.failWrites = false;
      await repo.decideAdoption(a.id, accept: true);
      h.actor = citizen;
      h.storage.failWrites = true;
      await expectLater(
        repo.signContract(a.id, confirmed: true),
        throwsA(isA<CatalogFailure>()),
      );
      expect((await repo.getContract(a.id)).signed, isFalse);
      expect(
        (await h.animals.getAnimalById(1))!.status,
        AnimalStatus.PENDING_ADOPTION,
      );
    },
  );
  test('Admin assigns only available animals to active foster families, without overlaps', () async {
    await expectLater(
      repo.assignPlacement(1, foster.id, now),
      throwsA(isA<CatalogFailure>()),
    );
    h.admin();
    await expectLater(
      repo.assignPlacement(1, citizen.id, now),
      throwsA(isA<CatalogFailure>()),
    );
    await expectLater(
      repo.assignPlacement(1, foster.id, now.add(const Duration(days: 1))),
      throwsA(isA<CatalogFailure>()),
    );
    final p = await repo.assignPlacement(
      1,
      foster.id,
      now,
      remarks: 'Accueil temporaire.',
    );
    expect(p.status, HebergementStatus.ACTIVE);
    expect((await h.animals.getAnimalById(1))!.status, AnimalStatus.FOSTERED);
    await expectLater(
      repo.assignPlacement(1, foster.id, now),
      throwsA(isA<CatalogFailure>()),
    );
    h.actor = foster;
    expect((await repo.getPlacements()).single.id, p.id);
    await repo.addPlacementRemark(p.id, 'Il mange bien.');
    expect((await repo.getPlacement(p.id)).remarks, contains('Il mange bien.'));
    await repo.finishPlacement(p.id);
    expect((await repo.getPlacement(p.id)).endDate, now);
    expect((await repo.getPlacement(p.id)).status, HebergementStatus.COMPLETED);
    expect((await h.animals.getAnimalById(1))!.status, AnimalStatus.AVAILABLE);
  });
  test(
    'Placement records and mutations are isolated by family identity',
    () async {
      h.admin();
      final p = await repo.assignPlacement(1, foster.id, now);
      h.actor = citizen;
      await expectLater(repo.getPlacements(), throwsA(isA<CatalogFailure>()));
      await expectLater(
        repo.getPlacement(p.id),
        throwsA(isA<CatalogFailure>()),
      );
      await expectLater(
        repo.addPlacementRemark(p.id, 'Privé'),
        throwsA(isA<CatalogFailure>()),
      );
      await expectLater(
        repo.finishPlacement(p.id),
        throwsA(isA<CatalogFailure>()),
      );
      h.actor = foster;
      await expectLater(
        repo.finishPlacement(p.id, cancel: true),
        throwsA(isA<CatalogFailure>()),
      );
      await expectLater(
        repo.getActiveFamilies(),
        throwsA(isA<CatalogFailure>()),
      );
    },
  );
  test('Admin cancellation records the actual release situation', () async {
    h.admin();
    final p = await repo.assignPlacement(1, foster.id, now);
    await repo.finishPlacement(
      p.id,
      cancel: true,
      releaseStatus: AnimalStatus.LOST,
    );
    expect((await repo.getPlacement(p.id)).status, HebergementStatus.CANCELLED);
    expect((await h.animals.getAnimalById(1))!.status, AnimalStatus.LOST);
  });
  test('Foster conversion creates a pending request and preserves the full adoption workflow', () async {
    h.admin();
    final p = await repo.assignPlacement(1, foster.id, now);
    h.actor = foster;
    await expectLater(
      repo.submitAdoption(1, answers(), motivation),
      throwsA(isA<CatalogFailure>()),
    );
    final a = await repo.convertToAdoption(p.id, answers(), motivation);
    expect(a.status, AdoptionStatus.PENDING);
    expect((await h.animals.getAnimalById(1))!.status, AnimalStatus.FOSTERED);
    await expectLater(
      repo.convertToAdoption(p.id, answers(), motivation),
      throwsA(isA<CatalogFailure>()),
    );
    h.admin();
    await repo.decideAdoption(a.id, accept: true);
    h.actor = foster;
    await repo.signContract(a.id, confirmed: true);
    expect((await h.animals.getAnimalById(1))!.status, AnimalStatus.ADOPTED);
    expect((await repo.getPlacement(p.id)).status, HebergementStatus.COMPLETED);
    expect((await repo.getPlacement(p.id)).endDate, now);
  });
  test(
    'Ending foster care preserves an already accepted adoption reservation',
    () async {
      final a = await repo.submitAdoption(1, answers(), motivation);
      h.admin();
      final p = await repo.assignPlacement(1, foster.id, now);
      await repo.decideAdoption(a.id, accept: true);
      await repo.finishPlacement(p.id, releaseStatus: AnimalStatus.LOST);
      expect(
        (await h.animals.getAnimalById(1))!.status,
        AnimalStatus.PENDING_ADOPTION,
      );
    },
  );
  test(
    'Animal CRUD cannot bypass workflow statuses or delete history',
    () async {
      final a = await repo.submitAdoption(1, answers(), motivation);
      h.admin();
      await repo.decideAdoption(a.id, accept: true);
      final animal = (await h.animals.getAnimalById(1))!;
      await expectLater(
        h.animals.updateAnimal(animal.copyWith(status: AnimalStatus.AVAILABLE)),
        throwsA(isA<CatalogFailure>()),
      );
      await expectLater(
        h.animals.deleteAnimal(1),
        throwsA(isA<CatalogFailure>()),
      );
      await h.animals.updateAnimal(animal.copyWith(name: 'Luna actualisée'));
      expect((await repo.getAdoption(a.id)).animal.name, 'Luna actualisée');
    },
  );
  test(
    'Workflow, contracts, questionnaires and follow-ups survive a reload',
    () async {
      final a = await repo.submitAdoption(1, answers(), motivation);
      h.admin();
      await repo.decideAdoption(a.id, accept: true);
      h.actor = citizen;
      await repo.signContract(a.id, confirmed: true);
      await repo.addFollowUp(
        a.id,
        news: 'Une semaine très heureuse.',
        visitType: 'Nouvelles à domicile',
      );
      final restored = Harness(storage: h.storage);
      final r = LocalAdoptionWorkflowRepository(
        restored.db,
        () => restored.actor,
      );
      addTearDown(() {
        r.dispose();
        restored.dispose();
      });
      final d = await r.getAdoption(a.id);
      expect(d.contract!.signed, isTrue);
      expect(d.adoption.adoptionDate, now);
      expect(d.questionnaire.availableTime, answers().availableTime);
      expect(
        (await r.getFollowUps(a.id)).single.news,
        'Une semaine très heureuse.',
      );
    },
  );
  test(
    'Existing 3A snapshots migrate without resetting animals or favorites',
    () async {
      await h.favorites.addFavorite(1);
      final json = jsonDecode(h.storage.value!) as Map<String, dynamic>;
      json.remove('workflow');
      final restored = Harness(storage: MemoryCatalogStorage(jsonEncode(json)));
      final r = LocalAdoptionWorkflowRepository(
        restored.db,
        () => restored.actor,
      );
      addTearDown(() {
        r.dispose();
        restored.dispose();
      });
      expect((await restored.animals.getAllAnimals()).length, 8);
      expect((await restored.favorites.getFavorites()).single.animalId, 1);
      expect(await r.getAdoptions(), isEmpty);
    },
  );
  test('Queued workflow operations cannot follow a changed session', () async {
    await h.animals.getAllAnimals();
    final pending = repo.submitAdoption(1, answers(), motivation);
    h.actor = DemoAccounts.users[1];
    await expectLater(pending, throwsA(isA<CatalogFailure>()));
    expect(await repo.getAdoptions(), isEmpty);
  });
}
