# Animora — Fichiers de l’étape 8A

Comparaison avec la sauvegarde réalisée avant l’intégration SQFlite, conservée dans work/step8a-before. Aucun fichier source existant n’est supprimé.

## Créés

- `lib/core/database/database_constants.dart`
- `lib/core/database/database_helper.dart`
- `lib/core/database/database_migrations.dart`
- `lib/core/database/database_platform.dart`
- `lib/core/database/database_platform_native.dart`
- `lib/core/database/database_platform_web.dart`
- `lib/features/adoption/database/business_user_source.dart`
- `lib/features/adoption/database/legacy_catalog_codec.dart`
- `lib/features/adoption/database/sqlite_catalog_dao.dart`
- `lib/features/adoption/database/sqlite_catalog_database.dart`
- `lib/features/adoption/repositories/sqlite_catalog_repositories.dart`
- `test/sqlite_catalog_test.dart`
- `test/sqlite_foundation_test.dart`
- `test/sqlite_widget_test.dart`

## Modifiés

- `lib/features/adoption/repositories/local_adoption_workflow_repository.dart`
- `lib/features/adoption/repositories/questionnaire_repository.dart`
- `lib/features/adoption/widgets/adoption_scope.dart`
- `test/widget_test.dart`
- `pubspec.yaml`
- `pubspec.lock`
- `README.md`

## Documentation et preuves

- `SQLITE_STEP_8A.md` : architecture, tables, relations, CRUD, migration et scénario manuel.
- `FILES_8A.md` : inventaire.
- `VALIDATION_8A.md` : résultats exacts des vérifications et limites.
- `output/database/animora-demo.db` : base SQLite fictive produite et rouverte par les tests.
- `output/database/schema.sql` : schéma SQL extrait de cette base.
- `output/database/verification.json` : nombres de lignes et contrôles d’intégrité de la base fictive.

Les fichiers générés par Flutter incluent désormais l’enregistrement de SQFlite :

- `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`
- `ios/Runner/GeneratedPluginRegistrant.m`
- `.flutter-plugins-dependencies`

Ils sont gérés par flutter pub get et ne constituent pas une modification manuelle de logique métier. Les répertoires build et .dart_tool sont des sorties des outils.

Les changements du workflow ajoutent la modification sécurisée d’un questionnaire encore en attente, avec recalcul du score par le service existant. Les tests existants restent présents. Le modèle User, l’authentification, le design, le logo et les repositories métier des autres gestions ne sont pas modifiés.
