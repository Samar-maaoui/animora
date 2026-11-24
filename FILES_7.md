# Animora — Fichiers de l’étape 7

Comparaison avec la sauvegarde de l’état final de l’étape 6. Aucun fichier existant supprimé.

## Créés

- `lib/core/enums/event_status.dart`
- `lib/core/enums/event_type.dart`
- `lib/core/enums/registration_status.dart`
- `lib/core/enums/registration_type.dart`
- `lib/core/enums/volunteer_task_status.dart`
- `lib/features/events/models/event.dart`
- `lib/features/events/models/event_activity.dart`
- `lib/features/events/models/event_registration.dart`
- `lib/features/events/models/event_report.dart`
- `lib/features/events/models/event_ticket.dart`
- `lib/features/events/models/volunteer_task.dart`
- `lib/features/events/repositories/events_database.dart`
- `lib/features/events/repositories/event_activity_repository.dart`
- `lib/features/events/repositories/event_registration_repository.dart`
- `lib/features/events/repositories/event_report_repository.dart`
- `lib/features/events/repositories/event_repository.dart`
- `lib/features/events/repositories/event_ticket_repository.dart`
- `lib/features/events/repositories/local_event_repository.dart`
- `lib/features/events/repositories/volunteer_task_repository.dart`
- `lib/features/events/screens/admin_event_screens.dart`
- `lib/features/events/services/event_rules.dart`
- `lib/features/events/widgets/events_scope.dart`
- `lib/features/events/widgets/event_widgets.dart`
- `test/events_repository_test.dart`
- `test/events_widget_test.dart`

## Modifiés

- `lib/app/app.dart`
- `lib/app/routes/app_router.dart`
- `lib/features/admin/screens/admin_screen.dart`
- `lib/features/auth/repositories/auth_repository.dart`
- `lib/features/auth/repositories/local_auth_repository.dart`
- `lib/features/auth/state/auth_session.dart`
- `lib/features/events/screens/events_screen.dart`
- `test/widget_test.dart`
- `pubspec.yaml`
- `pubspec.lock`
- `README.md`

## Documentation et preuve

- `EVENTS_STEP_7.md` : fonctionnalités, règles, contrats, routes et scénario manuel.
- `FILES_7.md` : inventaire de cette étape.
- `VALIDATION_7.md` : résultats et limites de validation.
- `docs/screenshots/step7-events.jpg` : capture de la vérification Web.

Les trois fichiers d’authentification reçoivent uniquement la lecture booléenne d’éligibilité `isUserActive`, nécessaire pour éviter de promouvoir ou pointer un compte devenu inactif sans exposer ses informations privées. Le modèle User, les règles de connexion et les transitions de compte restent identiques. Les autres modifications hors événements concernent l’intégration, le montage des tests et la déclaration directe de qr.
