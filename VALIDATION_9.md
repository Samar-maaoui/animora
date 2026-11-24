# Validation — Animora, étape 9

## Résultats

| Vérification | Résultat |
| --- | --- |
| État initial | 310 tests réussis avant modification |
| flutter pub get | Réussi ; http 1.6.0 devient dépendance directe ; aucune mise à niveau de version dans pubspec.lock |
| dart format . | Réussi ; 288 fichiers Dart parcourus |
| flutter analyze | No issues found! |
| flutter test | 339 tests réussis en 79 secondes, dont les 310 préexistants ; aucun ancien test modifié, supprimé ou désactivé |
| flutter build web | Réussi : Built build/web ; compilation finale 100,7 secondes |
| Android | SDK absent selon flutter doctor -v ; compilation / exécution non réalisées |
| iOS | Info.plist analysé avec plistlib ; aucune compilation / exécution Xcode depuis Windows |
| SQLite / logo | Aucun fichier de l’infrastructure SQLite modifié ; logo identique octet pour octet |

Les 29 nouveaux tests se répartissent ainsi : pays 3, races 4, géocodage 3, cliniques 3, taux 3, météo 3, transport/cache 4, interactions widget 6.

Les fichiers de preuves réseau sont indépendants de la réussite des tests avec mocks.

## Suites ciblées et couverture

- countries_api_test.dart : v5, parsing, indicatifs, cache, clé absente et hors ligne.
- breeds_api_test.dart : chiens et chats, headers, caractéristiques, format invalide et absence de clé.
- geocoding_api_test.dart : coordonnées arrondies, consentement, données privées exclues, cache et indisponibilité.
- clinics_api_test.dart : requête limitée, node/way/relation, coordonnées absentes, liste vide, timeout.
- exchange_rates_api_test.dart : EUR, USD, zéro, date, cache quotidien, taux absent et erreur réseau.
- weather_api_test.dart : jour exact, champs, conseils, cache, date passée/hors horizon, absence de coordonnées, erreur HTTP et format incomplet.
- api_transport_test.dart : cache persistant après création d’un nouveau client, expiration, résultat hors ligne daté, requêtes mutualisées, codes HTTP et JSON invalide.
- api_widgets_test.dart : recherche/sélection de pays et indicatif, race et caractéristiques, GPS/géocodage, conversion réactive sans modification du montant, annuaire externe/carte, météo hors période sans requête.

Les anciens tests SQFlite/FFI, migrations, contraintes, accès privés, navigation, inscriptions, adoptions, dons et événements restent exécutés.

## Appels réels, distincts des mocks

[Résultats Flutter réels](output/api/live-results.json) :
- REST Countries : configuration requise, clé absente ; aucun succès simulé.
- The Dog API / The Cat API : configuration requise, clés absentes.
- Nominatim : succès ; Tunis et zone approximative.
- Overpass : échec HTTP 502 dans le dernier appel Flutter de référence.
- ExchangeRate-API : succès ; EUR/USD et date de mise à jour.
- Open-Meteo : succès ; date demandée et fuseau Africa/Tunis.

[Instance Overpass alternative](output/api/live-results-alternative.json) : timeout depuis Flutter.
[Diagnostic indépendant Overpass](output/api/overpass-independent.json) : GET Python, HTTP 200, quatre établissements. Ce diagnostic ne certifie pas un appel Flutter ou une démonstration UI réussie.

Le script tool/api_smoke_test.dart produit un rapport même quand une API échoue : son statut test réussi ne signifie pas que toutes les API sont joignables. Les tests normaux dans test/ ne lancent pas ces appels réels.

## Corrections et limites matérielles

Le nettoyage des requêtes mutualisées ne retourne pas le Future en cours, ce qui évite une attente sur lui-même. Les tests vérifient la fin de deux requêtes concurrentes identiques et l’appel HTTP unique.

Le répertoire externe est dépliable pour conserver la recherche métier des vétérinaires et éviter la confusion entre les champs de recherche et ceux de la position. Les 310 tests d’origine restent inchangés.

Les permissions iOS préexistantes étaient imbriquées dans les dictionnaires de scènes. Elles sont placées à la racine et leur structure est validée par plistlib. Aucune validation native revendiquée.

Les appels réels ont été testés depuis Flutter VM, pas dans un navigateur déployé. La compilation Web et les tests de widgets ne prouvent pas CORS ou les permissions GPS d’un appareil réel. REST Countries exige aussi une origine autorisée pour la clé Web. Ces points restent à confirmer sur le contexte de démonstration.

Le limiteur Nominatim fonctionne dans une instance ; il ne coordonne pas plusieurs installations. Une diffusion large nécessite un fournisseur dédié ou un quota global coordonné. Le changement de géocodeur est disponible à l’exécution.

## Conservation

- Même base animora.db et version 6 ; aucune migration SQL nouvelle.
- Authentification, règles de compte et repositories métier préservés ; le formulaire applique seulement l’indicatif au numéro saisi.
- Don principal en TND ; paiements simulés.
- Photos officielles des animaux et score de compatibilité inchangés.
- Logo SHA-256 : B5F45FACFFCC664D7BAD0A1552040ADB48C485F78F789D2A494528860A7D4A86.
- Aucun backend ni étape 10.

## Traces

Les commandes et diagnostics sont conservés dans ../../work/step9-*.log, notamment step9-baseline-tests.log, step9-pub-get-final.log, step9-format.log, step9-analyze-final.log, step9-tests-final.log, step9-build-web-final.log, step9-doctor.log et step9-live-api-final.log.

Voir [API_INTEGRATIONS_REPORT.md](API_INTEGRATIONS_REPORT.md) pour les endpoints, conditions, exemples JSON, configurations, écrans, procédures de démonstration et limitations, et [FILES_9.md](FILES_9.md) pour l’inventaire des changements.
