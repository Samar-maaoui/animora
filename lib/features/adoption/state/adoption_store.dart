import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/enums/account_status.dart';
import '../models/animal.dart';
import '../models/favorite.dart';
import '../repositories/animal_repository.dart';
import '../repositories/favorite_repository.dart';
import '../../auth/state/auth_session.dart';

class AdoptionStore extends ChangeNotifier {
  AdoptionStore({
    required this.animalsRepository,
    required this.favoriteRepository,
    required this.session,
  }) {
    animalsRepository.addListener(_repositoryChanged);
    favoriteRepository.addListener(_repositoryChanged);
    session.addListener(_sessionChanged);
  }
  final AnimalRepository animalsRepository;
  final FavoriteRepository favoriteRepository;
  final AuthSession session;
  List<Animal> _animals = [];
  List<Favorite> _favorites = [];
  String? _loadedUserId;
  bool loading = false, busy = false, _disposed = false;
  String? error;
  int _generation = 0;
  List<Animal> get animals => List.unmodifiable(_animals);
  List<Favorite> get favorites => _loadedUserId == session.currentUser?.id
      ? List.unmodifiable(_favorites)
      : const [];
  bool isFavorite(int id) => favorites.any((f) => f.animalId == id);
  Animal? byId(int id) => _animals.where((a) => a.id == id).firstOrNull;
  void _repositoryChanged() {
    unawaited(load());
  }

  void _sessionChanged() {
    final activeId = session.currentUser?.status == AccountStatus.active
        ? session.currentUser?.id
        : null;
    if (activeId != _loadedUserId) {
      _loadedUserId = activeId;
      _favorites = [];
      unawaited(load());
    }
  }

  Future<void> load() async {
    final generation = ++_generation;
    final user = session.currentUser;
    if (user == null || user.status != AccountStatus.active) {
      _animals = [];
      _favorites = [];
      _loadedUserId = null;
      loading = false;
      error = null;
      _notify();
      return;
    }
    loading = true;
    error = null;
    _notify();
    try {
      final animals = await animalsRepository.getAllAnimals();
      final favorites = await favoriteRepository.getFavorites();
      if (!_disposed &&
          generation == _generation &&
          session.currentUser?.id == user.id) {
        _animals = animals;
        _favorites = favorites;
        _loadedUserId = user.id;
      }
    } catch (failure) {
      if (generation == _generation) error = catalogErrorMessage(failure);
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> _change(Future<void> Function() action) async {
    if (busy) throw const CatalogFailure('Une opération est déjà en cours.');
    busy = true;
    _notify();
    try {
      await action();
      await load();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> toggleFavorite(int id) => _change(
    () => isFavorite(id)
        ? favoriteRepository.removeFavorite(id)
        : favoriteRepository.addFavorite(id),
  );
  Future<void> save(Animal animal, {required bool creating}) =>
      _change(() async {
        if (creating) {
          await animalsRepository.addAnimal(animal);
        } else {
          await animalsRepository.updateAnimal(animal);
        }
      });
  Future<void> delete(int id) =>
      _change(() => animalsRepository.deleteAnimal(id));
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    animalsRepository.removeListener(_repositoryChanged);
    favoriteRepository.removeListener(_repositoryChanged);
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}
