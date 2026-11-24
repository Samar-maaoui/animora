# Fichiers — Étape 8B

Comparaison avec la copie prise avant cette étape (../../work/step8b-before), et non avec le commit Git qui précédait déjà l’étape 8A. Les fichiers 8A préexistants sont conservés. Aucun fichier source supprimé.

## Créés (25 fichiers de code/test)

- [lib/core/database/file_media_storage.dart](lib/core/database/file_media_storage.dart)
- [lib/core/database/media_platform.dart](lib/core/database/media_platform.dart)
- [lib/core/database/media_platform_native.dart](lib/core/database/media_platform_native.dart)
- [lib/core/database/media_platform_web.dart](lib/core/database/media_platform_web.dart)
- [lib/core/database/sql_module.dart](lib/core/database/sql_module.dart)
- [lib/core/database/sqlite_runtime_scope.dart](lib/core/database/sqlite_runtime_scope.dart)
- [lib/features/animal_services/database/animal_services_sql_schema.dart](lib/features/animal_services/database/animal_services_sql_schema.dart)
- [lib/features/animal_services/database/sqlite_animal_services_database.dart](lib/features/animal_services/database/sqlite_animal_services_database.dart)
- [lib/features/animal_services/repositories/sqlite_services_repository.dart](lib/features/animal_services/repositories/sqlite_services_repository.dart)
- [lib/features/donations/database/donations_sql_schema.dart](lib/features/donations/database/donations_sql_schema.dart)
- [lib/features/donations/database/sqlite_donations_database.dart](lib/features/donations/database/sqlite_donations_database.dart)
- [lib/features/donations/repositories/sqlite_donation_repository.dart](lib/features/donations/repositories/sqlite_donation_repository.dart)
- [lib/features/events/database/events_sql_schema.dart](lib/features/events/database/events_sql_schema.dart)
- [lib/features/events/database/sqlite_events_database.dart](lib/features/events/database/sqlite_events_database.dart)
- [lib/features/events/repositories/sqlite_event_repository.dart](lib/features/events/repositories/sqlite_event_repository.dart)
- [lib/features/reports/database/reports_sql_schema.dart](lib/features/reports/database/reports_sql_schema.dart)
- [lib/features/reports/database/sqlite_reports_database.dart](lib/features/reports/database/sqlite_reports_database.dart)
- [lib/features/reports/repositories/sqlite_reports_repository.dart](lib/features/reports/repositories/sqlite_reports_repository.dart)
- [test/sqlite_donations_test.dart](test/sqlite_donations_test.dart)
- [test/sqlite_events_test.dart](test/sqlite_events_test.dart)
- [test/sqlite_migration_8b_test.dart](test/sqlite_migration_8b_test.dart)
- [test/sqlite_modules_widget_test.dart](test/sqlite_modules_widget_test.dart)
- [test/sqlite_reports_test.dart](test/sqlite_reports_test.dart)
- [test/sqlite_services_test.dart](test/sqlite_services_test.dart)
- [test/support/sql_module_test_support.dart](test/support/sql_module_test_support.dart)

## Modifiés (13)

- [README.md](README.md)
- [lib/app/app.dart](lib/app/app.dart)
- [lib/core/database/database_constants.dart](lib/core/database/database_constants.dart)
- [lib/core/database/database_helper.dart](lib/core/database/database_helper.dart)
- [lib/core/database/database_migrations.dart](lib/core/database/database_migrations.dart)
- [lib/features/adoption/database/sqlite_catalog_database.dart](lib/features/adoption/database/sqlite_catalog_database.dart)
- [lib/features/adoption/widgets/adoption_scope.dart](lib/features/adoption/widgets/adoption_scope.dart)
- [lib/features/animal_services/widgets/services_scope.dart](lib/features/animal_services/widgets/services_scope.dart)
- [lib/features/donations/widgets/donations_scope.dart](lib/features/donations/widgets/donations_scope.dart)
- [lib/features/events/widgets/events_scope.dart](lib/features/events/widgets/events_scope.dart)
- [lib/features/reports/widgets/reports_scope.dart](lib/features/reports/widgets/reports_scope.dart)
- [test/sqlite_catalog_test.dart](test/sqlite_catalog_test.dart)
- [test/widget_test.dart](test/widget_test.dart)

## Rapports et preuves ajoutés

- [SQLITE_STEP_8B.md](SQLITE_STEP_8B.md)
- [FILES_8B.md](FILES_8B.md)
- [VALIDATION_8B.md](VALIDATION_8B.md)
- [output/database/animora-8b-demo.db](output/database/animora-8b-demo.db)
- [output/database/schema-8b.sql](output/database/schema-8b.sql)
- [output/database/verification-8b.json](output/database/verification-8b.json)

Les logs des commandes sont conservés dans ../../work/step8b-*.log. La base de démonstration et son export sont générés exclusivement à partir de fixtures fictives.

Les anciens repositories métier, modèles, routes, écrans, algorithmes et le logo sont préservés. Les scopes choisissent maintenant l’implémentation SQLite native partagée ; les tests peuvent injecter explicitement ce même runtime.
