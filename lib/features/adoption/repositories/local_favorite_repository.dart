import '../../../core/enums/account_status.dart';
import '../../users/models/user.dart';
import '../models/favorite.dart';
import 'animal_repository.dart';
import 'favorite_repository.dart';
import 'local_catalog_database.dart';

class LocalFavoriteRepository extends FavoriteRepository {
  LocalFavoriteRepository(this.database, this.currentUser) {
    database.addListener(_changed);
  }
  final LocalCatalogDatabase database;
  final User? Function() currentUser;
  String _userId() {
    final user = currentUser();
    if (user == null || user.status != AccountStatus.active) {
      throw const CatalogFailure('Un compte actif est nécessaire.');
    }
    return user.id;
  }

  void _sameSession(String id) {
    if (_userId() != id) {
      throw const CatalogFailure('La session a changé. Veuillez réessayer.');
    }
  }

  void _changed() => notifyListeners();
  @override
  Future<List<Favorite>> getFavorites() async {
    final id = _userId();
    return database.read((data) {
      _sameSession(id);
      final list = data.favorites.where((f) => f.userId == id).toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return List.unmodifiable(list);
    });
  }

  @override
  Future<void> addFavorite(int animalId) async {
    final id = _userId();
    await database.mutate<void>((data) {
      _sameSession(id);
      if (!data.animals.containsKey(animalId)) {
        throw const CatalogFailure('Cet animal n’existe plus.');
      }
      if (!data.favorites.any(
        (f) => f.userId == id && f.animalId == animalId,
      )) {
        data.favorites.add(
          Favorite(
            userId: id,
            animalId: animalId,
            addedAt: DateTime.now().toUtc(),
          ),
        );
      }
    });
  }

  @override
  Future<void> removeFavorite(int animalId) async {
    final id = _userId();
    await database.mutate<void>((data) {
      _sameSession(id);
      data.favorites.removeWhere(
        (f) => f.userId == id && f.animalId == animalId,
      );
    });
  }

  @override
  void dispose() {
    database.removeListener(_changed);
    super.dispose();
  }
}
