import 'package:flutter_test/flutter_test.dart';
import 'package:animora/core/constants/demo_data.dart';
import 'package:animora/core/enums/animal_status.dart';
import 'package:animora/features/adoption/models/animal.dart';
import 'package:animora/features/adoption/models/animal_filter.dart';
import 'package:animora/features/adoption/repositories/animal_repository.dart';
import 'package:animora/features/adoption/repositories/local_catalog_database.dart';
import 'package:animora/features/adoption/repositories/local_animal_repository.dart';
import 'package:animora/features/adoption/repositories/local_favorite_repository.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/users/models/user.dart';

import 'support/catalog_test_support.dart';

class Harness {
  Harness({MemoryCatalogStorage? storage})
    : storage = storage ?? MemoryCatalogStorage() {
    db = LocalCatalogDatabase(this.storage);
    animals = LocalAnimalRepository(db, () => actor);
    favorites = LocalFavoriteRepository(db, () => actor);
  }
  final MemoryCatalogStorage storage;
  User? actor = DemoAccounts.users.first;
  late final LocalCatalogDatabase db;
  late final LocalAnimalRepository animals;
  late final LocalFavoriteRepository favorites;
  void admin() =>
      actor = DemoAccounts.users.firstWhere((u) => u.id == 'demo-admin');
  void dispose() {
    animals.dispose();
    favorites.dispose();
    db.dispose();
  }
}

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.dispose());
  test(
    'Animal roundtrip preserves numeric IDs, integer age and all attributes',
    () {
      final a = DemoData.animals.first;
      final copy = Animal.fromJson(a.toJson());
      expect(copy.toJson(), a.toJson());
      expect(copy.id, isA<int>());
      expect(copy.age, isA<int>());
    },
  );
  test(
    'Seed loads once and name search is trimmed and case-insensitive',
    () async {
      expect((await h.animals.getAllAnimals()).length, 8);
      expect(
        (await h.animals.searchAnimals(const AnimalFilter(name: ' LUN ')))
            .single
            .name,
        'Luna',
      );
      expect(
        await h.animals.searchAnimals(const AnimalFilter(name: 'absent')),
        isEmpty,
      );
      final before = h.storage.value;
      await h.animals.getAllAnimals();
      expect(h.storage.value, before);
    },
  );
  test(
    'All filters combine and other species and age boundaries work',
    () async {
      final exact = await h.animals.searchAnimals(
        const AnimalFilter(
          name: 'luna',
          species: 'Chat',
          breed: 'Européen',
          age: AnimalAgeGroup.adult,
          city: 'Tunis',
          status: AnimalStatus.AVAILABLE,
        ),
      );
      expect(exact.single.id, 1);
      expect(
        await h.animals.searchAnimals(
          const AnimalFilter(species: 'Chien', city: 'Tunis'),
        ),
        isEmpty,
      );
      expect(
        (await h.animals.searchAnimals(const AnimalFilter(species: 'Autre')))
            .single
            .name,
        'Noisette',
      );
      final base = DemoData.animals.first;
      for (final age in [0, 1, 2, 7, 8, 15]) {
        expect(
          const AnimalFilter(age: AnimalAgeGroup.young)
              .matches(base.copyWith(age: age)),
          age <= 1,
        );
        expect(
          const AnimalFilter(age: AnimalAgeGroup.adult)
              .matches(base.copyWith(age: age)),
          age >= 2 && age <= 7,
        );
        expect(
          const AnimalFilter(age: AnimalAgeGroup.senior)
              .matches(base.copyWith(age: age)),
          age >= 8,
        );
      }
    },
  );
  test(
    'Favorites retain addition date, avoid duplicates and can be removed',
    () async {
      await h.favorites.addFavorite(1);
      final first = (await h.favorites.getFavorites()).single;
      await h.favorites.addFavorite(1);
      expect((await h.favorites.getFavorites()).single.addedAt, first.addedAt);
      expect(first.userId, h.actor!.id);
      expect(first.animalId, 1);
      await h.favorites.removeFavorite(1);
      expect(await h.favorites.getFavorites(), isEmpty);
      await expectLater(
        h.favorites.addFavorite(999),
        throwsA(isA<CatalogFailure>()),
      );
    },
  );
  test(
    'Favorites are private to the authenticated identity and survive reload',
    () async {
      final citizen = h.actor;
      await h.favorites.addFavorite(1);
      h.actor = DemoAccounts.users[1];
      expect(await h.favorites.getFavorites(), isEmpty);
      await h.favorites.addFavorite(2);
      h.actor = citizen;
      expect((await h.favorites.getFavorites()).single.animalId, 1);
      final restored = Harness(storage: h.storage);
      addTearDown(restored.dispose);
      expect((await restored.favorites.getFavorites()).single.animalId, 1);
      restored.actor = DemoAccounts.users[1];
      expect((await restored.favorites.getFavorites()).single.animalId, 2);
    },
  );
  test(
    'A queued favorite cannot be applied to a newly connected user',
    () async {
      await h.animals.getAllAnimals();
      final pending = h.favorites.addFavorite(1);
      h.actor = DemoAccounts.users[1];
      await expectLater(pending, throwsA(isA<CatalogFailure>()));
      expect(await h.favorites.getFavorites(), isEmpty);
    },
  );
  test('Only an active admin can mutate animals, including direct repository calls', () async {
    await expectLater(
      h.animals.addAnimal(DemoData.animals.first),
      throwsA(isA<CatalogFailure>()),
    );
    await expectLater(
      h.animals.updateAnimal(DemoData.animals.first),
      throwsA(isA<CatalogFailure>()),
    );
    await expectLater(
      h.animals.deleteAnimal(1),
      throwsA(isA<CatalogFailure>()),
    );
    h.actor = DemoAccounts.users.firstWhere((u) => u.id == 'demo-pending');
    await expectLater(
      h.favorites.addFavorite(1),
      throwsA(isA<CatalogFailure>()),
    );
    h.actor = null;
    await expectLater(
      h.animals.getAllAnimals(),
      throwsA(isA<CatalogFailure>()),
    );
  });
  test('Admin creates monotonic IDs, edits status and fields, preserving arrival date', () async {
    h.admin();
    final created = await h.animals.addAnimal(
      DemoData.animals.first.copyWith(name: 'Tara'),
    );
    expect(created.id, 9);
    await h.animals.updateAnimal(
      created.copyWith(
        name: 'Tara II',
        status: AnimalStatus.ADOPTED,
        arrivalDate: DateTime(2040),
      ),
    );
    final updated = (await h.animals.getAnimalById(created.id))!;
    expect(updated.name, 'Tara II');
    expect(updated.status, AnimalStatus.ADOPTED);
    expect(updated.arrivalDate, created.arrivalDate);
    await h.animals.deleteAnimal(created.id);
    expect(await h.animals.getAnimalById(created.id), isNull);
    final next = await h.animals.addAnimal(DemoData.animals.first);
    expect(next.id, 10);
    final restored = Harness(storage: h.storage);
    addTearDown(restored.dispose);
    expect((await restored.animals.getAnimalById(10))?.name, 'Luna');
  });
  test(
    'Deleting an animal atomically removes favorites for every user',
    () async {
      await h.favorites.addFavorite(1);
      h.actor = DemoAccounts.users[1];
      await h.favorites.addFavorite(1);
      h.admin();
      await h.animals.deleteAnimal(1);
      h.actor = DemoAccounts.users.first;
      expect(await h.favorites.getFavorites(), isEmpty);
      h.actor = DemoAccounts.users[1];
      expect(await h.favorites.getFavorites(), isEmpty);
      final restored = Harness(storage: h.storage);
      addTearDown(restored.dispose);
      expect(await restored.animals.getAnimalById(1), isNull);
    },
  );
  test('Malformed fields and nonportable image paths are rejected', () async {
    h.admin();
    final base = DemoData.animals.first;
    for (final a in [
      base.copyWith(name: ' '),
      base.copyWith(age: -1),
      base.copyWith(weight: double.nan),
      base.copyWith(animalPhoto: 'C:/photo.jpg'),
    ]) {
      await expectLater(h.animals.addAnimal(a), throwsA(isA<CatalogFailure>()));
    }
    expect((await h.animals.getAllAnimals()).length, 8);
  });
  test(
    'Storage failure rolls back animal deletion and favorite cleanup together',
    () async {
      await h.favorites.addFavorite(1);
      h.admin();
      final before = h.storage.value;
      h.storage.failWrites = true;
      await expectLater(
        h.animals.deleteAnimal(1),
        throwsA(isA<CatalogFailure>()),
      );
      expect(await h.animals.getAnimalById(1), isNotNull);
      expect(h.storage.value, before);
      h.actor = DemoAccounts.users.first;
      expect((await h.favorites.getFavorites()).length, 1);
    },
  );
  test('Corrupt stored data is never silently reset', () async {
    final broken = Harness(storage: MemoryCatalogStorage('{broken'));
    addTearDown(broken.dispose);
    await expectLater(
      broken.animals.getAllAnimals(),
      throwsA(isA<CatalogFailure>()),
    );
    expect(broken.storage.value, '{broken');
  });
}
