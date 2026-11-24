import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants/demo_data.dart';
import '../models/animal.dart';
import '../models/favorite.dart';
import '../models/workflow_data.dart';
import '../services/catalog_storage.dart';
import 'animal_repository.dart';

class CatalogData {
  CatalogData({
    required this.animals,
    required this.favorites,
    required this.nextId,
    WorkflowData? workflow,
  }) : workflow = workflow ?? WorkflowData();
  final WorkflowData workflow;
  final Map<int, Animal> animals;
  final List<Favorite> favorites;
  int nextId;
  CatalogData clone() => CatalogData(
    animals: Map.of(animals),
    favorites: List.of(favorites),
    nextId: nextId,
    workflow: workflow.clone(),
  );
}

/// One snapshot makes deletion + favorite cleanup an atomic local write.
class LocalCatalogDatabase extends ChangeNotifier {
  LocalCatalogDatabase(this.storage);
  final CatalogStorage storage;
  CatalogData? _data;
  bool _disposed = false;
  Future<void> _tail = Future.value();
  Future<T> _run<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<void> _load() async {
    if (_data != null) return;
    try {
      final raw = await storage.read();
      if (raw == null) {
        final seed = CatalogData(
          animals: {for (final animal in DemoData.animals) animal.id: animal},
          favorites: [],
          nextId: 9,
        );
        await _persist(seed);
        _data = seed;
      } else {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        if (json['version'] != 1) {
          throw const FormatException('Unsupported catalog version');
        }
        final animals = [
          for (final entry in json['animals'] as List)
            Animal.fromJson(entry as Map<String, dynamic>),
        ];
        final favorites = [
          for (final entry in json['favorites'] as List)
            Favorite.fromJson(entry as Map<String, dynamic>),
        ];
        final nextId = json['nextId'] as int;
        if (animals.any((a) => a.id < 1 || a.id >= nextId)) {
          throw const FormatException('Invalid catalog IDs');
        }
        _data = CatalogData(
          animals: {for (final animal in animals) animal.id: animal},
          favorites: favorites
              .where((f) => animals.any((a) => a.id == f.animalId))
              .toList(),
          nextId: nextId,
          workflow: json['workflow'] == null
              ? WorkflowData()
              : WorkflowData.fromJson(json['workflow'] as Map<String, dynamic>),
        );
      }
    } catch (error) {
      if (error is CatalogFailure) rethrow;
      throw const CatalogFailure(
        'Impossible de charger le catalogue local. Vos données n’ont pas été réinitialisées.',
      );
    }
  }

  Future<void> _persist(CatalogData data) async {
    final raw = jsonEncode({
      'version': 1,
      'nextId': data.nextId,
      'animals': data.animals.values.map((a) => a.toJson()).toList(),
      'favorites': data.favorites.map((f) => f.toJson()).toList(),
      'workflow': data.workflow.toJson(),
    });
    if (utf8.encode(raw).length > 3500000) {
      throw const CatalogFailure(
        'Stockage de démonstration plein (3,5 Mo). Choisissez des photos plus petites ou supprimez un animal.',
      );
    }
    try {
      await storage.write(raw);
    } catch (_) {
      throw const CatalogFailure(
        'Enregistrement local impossible. Aucune modification n’a été appliquée.',
      );
    }
  }

  Future<T> read<T>(T Function(CatalogData data) action) => _run(() async {
    await _load();
    return action(_data!);
  });
  Future<T> mutate<T>(T Function(CatalogData data) action) => _run(() async {
    await _load();
    final draft = _data!.clone();
    final result = action(draft);
    await _persist(draft);
    _data = draft;
    if (!_disposed) notifyListeners();
    return result;
  });
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
