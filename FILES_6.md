# Animora — Fichiers de l’étape 6

Comparaison avec la sauvegarde réalisée avant cette étape. Aucune suppression de fichier existant.

## Créés

- `lib/core/enums/campaign_status.dart`
- `lib/core/enums/donation_frequency.dart`
- `lib/core/enums/donation_status.dart`
- `lib/core/enums/donation_type.dart`
- `lib/core/enums/material_donation_status.dart`
- `lib/core/enums/material_need_status.dart`
- `lib/core/enums/material_type.dart`
- `lib/core/enums/recurring_donation_status.dart`
- `lib/features/donations/models/donation.dart`
- `lib/features/donations/models/donation_campaign.dart`
- `lib/features/donations/models/donation_receipt.dart`
- `lib/features/donations/models/material_donation.dart`
- `lib/features/donations/models/material_need.dart`
- `lib/features/donations/models/recurring_donation.dart`
- `lib/features/donations/models/transparency_report.dart`
- `lib/features/donations/repositories/donations_database.dart`
- `lib/features/donations/repositories/donation_campaign_repository.dart`
- `lib/features/donations/repositories/donation_receipt_repository.dart`
- `lib/features/donations/repositories/donation_repository.dart`
- `lib/features/donations/repositories/local_donation_repository.dart`
- `lib/features/donations/repositories/material_donation_repository.dart`
- `lib/features/donations/repositories/material_need_repository.dart`
- `lib/features/donations/repositories/recurring_donation_repository.dart`
- `lib/features/donations/repositories/transparency_report_repository.dart`
- `lib/features/donations/screens/admin_donation_screens.dart`
- `lib/features/donations/screens/donation_screens.dart`
- `lib/features/donations/services/donation_receipt_pdf.dart`
- `lib/features/donations/services/donation_rules.dart`
- `lib/features/donations/widgets/donations_scope.dart`
- `lib/features/donations/widgets/donation_widgets.dart`
- `test/donations_repository_test.dart`
- `test/donations_widget_test.dart`
- `test/donation_pdf_test.dart`

## Modifiés

- `lib/app/app.dart`
- `lib/app/routes/app_router.dart`
- `lib/features/admin/screens/admin_screen.dart`
- `lib/features/donations/screens/donations_screen.dart`
- `test/widget_test.dart`
- `pubspec.yaml`
- `pubspec.lock`
- `README.md`

## Documentation et preuves ajoutées

- `DONATIONS_STEP_6.md` : règles, architecture, routes et scénario manuel.
- `FILES_6.md` : inventaire.
- `VALIDATION_6.md` : résultats et limites.
- `docs/screenshots/step6-donations.jpg` : parcours Web avec données fictives.
- `output/pdf/animora-recu-demo.pdf` : exemple fictif de reçu PDF non fiscal.

Les modifications hors du nouveau module concernent son intégration dans les scopes, les routes, le tableau de bord ADMIN, le montage des tests et les dépendances PDF.
