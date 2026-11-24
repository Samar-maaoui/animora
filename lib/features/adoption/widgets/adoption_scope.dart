import '../../../core/database/sqlite_runtime_scope.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/database_platform.dart' as platform;
import '../../auth/services/local_auth_storage.dart';
import '../database/business_user_source.dart';
import '../database/sqlite_catalog_database.dart';
import '../repositories/sqlite_catalog_repositories.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_session.dart';
import '../repositories/local_animal_repository.dart';
import '../repositories/local_catalog_database.dart';
import '../repositories/local_favorite_repository.dart';
import '../services/catalog_storage.dart';
import '../state/adoption_store.dart';
import '../repositories/local_adoption_workflow_repository.dart';
import '../state/adoption_workflow_store.dart';

/// Owns the local catalog once for the lifetime of the app, not per route.
class AdoptionScope extends StatefulWidget {
  const AdoptionScope({
    super.key,
    required this.child,
    this.storage,
    this.databaseHelper,
    this.businessUsers,
  });
  final Widget child;
  final CatalogStorage? storage;
  final DatabaseHelper? databaseHelper;
  final BusinessUserSource? businessUsers;
  @override
  State<AdoptionScope> createState() => _AdoptionScopeState();
}

class _AdoptionScopeState extends State<AdoptionScope> {
  late final LocalCatalogDatabase _database;
  bool _ownsDatabase = true;
  late final LocalAnimalRepository _animals;
  late final LocalFavoriteRepository _favorites;
  late final AdoptionStore _store;
  late final LocalAdoptionWorkflowRepository _workflowRepository;
  late final AdoptionWorkflowStore _workflow;
  @override
  void initState() {
    super.initState();
    final session = context.read<AuthSession>();
    final shared = context.read<SqliteRuntime?>()?.context;
    final legacy =
        widget.storage ??
        shared?.catalog.storage ??
        PreferencesCatalogStorage();
    _ownsDatabase = shared == null;
    final useSqlite =
        widget.databaseHelper != null ||
        shared != null ||
        (widget.storage == null && platform.supportsNativeSqlite);
    if (useSqlite) {
      final sql =
          shared?.catalog ??
          SqliteCatalogDatabase(
            legacy,
            helper: widget.databaseHelper ?? platform.createPlatformDatabase(),
            loadBusinessUsers:
                (widget.businessUsers ??
                        BusinessUserSource(PreferencesAuthStorage()))
                    .read,
          );
      _database = sql;
      _animals = SqliteAnimalRepository(sql, () => session.currentUser);
      _favorites = SqliteFavoriteRepository(sql, () => session.currentUser);
      _workflowRepository = SqliteAdoptionWorkflowRepository(
        sql,
        () => session.currentUser,
        listUsers: session.listUsers,
      );
    } else {
      _database = LocalCatalogDatabase(legacy);
      _animals = LocalAnimalRepository(_database, () => session.currentUser);
      _favorites = LocalFavoriteRepository(
        _database,
        () => session.currentUser,
      );
      _workflowRepository = LocalAdoptionWorkflowRepository(
        _database,
        () => session.currentUser,
        listUsers: session.listUsers,
      );
    }
    _workflow = AdoptionWorkflowStore(
      adoptions: _workflowRepository,
      questionnaires: _workflowRepository,
      contracts: _workflowRepository,
      followUps: _workflowRepository,
      placements: _workflowRepository,
      changes: _workflowRepository,
      session: session,
    );
    _store = AdoptionStore(
      animalsRepository: _animals,
      favoriteRepository: _favorites,
      session: session,
    );
    unawaited(_store.load());
  }

  @override
  void dispose() {
    _workflow.dispose();
    _workflowRepository.dispose();
    _store.dispose();
    _animals.dispose();
    _favorites.dispose();
    if (_ownsDatabase) _database.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider<LocalCatalogDatabase>.value(value: _database),
      ChangeNotifierProvider.value(value: _store),
      ChangeNotifierProvider.value(value: _workflow),
    ],
    child: widget.child,
  );
}
