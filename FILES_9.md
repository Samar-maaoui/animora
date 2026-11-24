# Fichiers — Étape 9

Comparaison avec ../../work/step9-before. Aucun fichier source ou ancien test supprimé. Les 310 anciens tests et les fichiers SQLite sont inchangés.

## Nouveaux fichiers de code et tests

- [lib/core/network/api_client.dart](lib/core/network/api_client.dart)
- [lib/core/network/api_panel.dart](lib/core/network/api_panel.dart)
- [lib/core/network/api_scope.dart](lib/core/network/api_scope.dart)
- [lib/features/adoption/services/breeds_api.dart](lib/features/adoption/services/breeds_api.dart)
- [lib/features/adoption/widgets/breed_information.dart](lib/features/adoption/widgets/breed_information.dart)
- [lib/features/donations/services/exchange_rates_api.dart](lib/features/donations/services/exchange_rates_api.dart)
- [lib/features/donations/widgets/currency_conversion.dart](lib/features/donations/widgets/currency_conversion.dart)
- [lib/features/events/services/weather_api.dart](lib/features/events/services/weather_api.dart)
- [lib/features/events/widgets/event_weather.dart](lib/features/events/widgets/event_weather.dart)
- [lib/features/reports/services/geocoding_api.dart](lib/features/reports/services/geocoding_api.dart)
- [lib/features/users/services/countries_api.dart](lib/features/users/services/countries_api.dart)
- [lib/features/users/widgets/country_picker.dart](lib/features/users/widgets/country_picker.dart)
- [lib/features/veterinary/services/clinics_api.dart](lib/features/veterinary/services/clinics_api.dart)
- [lib/features/veterinary/widgets/nearby_clinics.dart](lib/features/veterinary/widgets/nearby_clinics.dart)
- [test/api_transport_test.dart](test/api_transport_test.dart)
- [test/api_widgets_test.dart](test/api_widgets_test.dart)
- [test/breeds_api_test.dart](test/breeds_api_test.dart)
- [test/clinics_api_test.dart](test/clinics_api_test.dart)
- [test/countries_api_test.dart](test/countries_api_test.dart)
- [test/exchange_rates_api_test.dart](test/exchange_rates_api_test.dart)
- [test/geocoding_api_test.dart](test/geocoding_api_test.dart)
- [test/weather_api_test.dart](test/weather_api_test.dart)

## Fichiers applicatifs modifiés

- [.gitignore](.gitignore)
- [README.md](README.md)
- [ios/Runner/Info.plist](ios/Runner/Info.plist)
- [lib/app/app.dart](lib/app/app.dart)
- [lib/features/admin/screens/animal_form_screen.dart](lib/features/admin/screens/animal_form_screen.dart)
- [lib/features/adoption/screens/animal_details_screen.dart](lib/features/adoption/screens/animal_details_screen.dart)
- [lib/features/auth/widgets/auth_form.dart](lib/features/auth/widgets/auth_form.dart)
- [lib/features/donations/screens/donation_screens.dart](lib/features/donations/screens/donation_screens.dart)
- [lib/features/events/screens/events_screen.dart](lib/features/events/screens/events_screen.dart)
- [lib/features/reports/widgets/reports_widgets.dart](lib/features/reports/widgets/reports_widgets.dart)
- [lib/features/veterinary/screens/veterinary_screens.dart](lib/features/veterinary/screens/veterinary_screens.dart)
- [pubspec.lock](pubspec.lock)
- [pubspec.yaml](pubspec.yaml)

## Configuration, outil et rapports ajoutés

- [config/api-keys.example.json](config/api-keys.example.json)
- [tool/api_smoke_test.dart](tool/api_smoke_test.dart)
- [API_INTEGRATIONS_REPORT.md](API_INTEGRATIONS_REPORT.md)
- [FILES_9.md](FILES_9.md)
- [VALIDATION_9.md](VALIDATION_9.md)
- [output/api/live-results.json](output/api/live-results.json)
- [output/api/live-results-alternative.json](output/api/live-results-alternative.json)
- [output/api/overpass-independent.json](output/api/overpass-independent.json)

config/api-keys.json est ignoré par Git et n’a pas été créé avec des clés. Aucune clé privée n’a été ajoutée. Les traces de commande sont dans ../../work/step9-*.log.
