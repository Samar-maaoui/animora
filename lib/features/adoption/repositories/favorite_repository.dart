import 'package:flutter/foundation.dart';

import '../models/favorite.dart';

/// Every operation is scoped to the current active user, never an ID supplied by UI.
abstract class FavoriteRepository extends ChangeNotifier {
  Future<List<Favorite>> getFavorites();
  Future<void> addFavorite(int animalId);
  Future<void> removeFavorite(int animalId);
}
