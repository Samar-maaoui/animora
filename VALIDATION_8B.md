# Validation — Étape 8B

État initial conservé : analyse sans problème, **291 tests réussis** avant 8B.

## Résultats finaux

| Commande | Résultat |
| --- | --- |
| flutter pub get | Réussi, Got dependencies! ; contraintes de dépendances inchangées pendant 8B |
| dart format . | Réussi, 265 fichiers parcourus |
| flutter analyze | **No issues found!**, aucune erreur, aucun avertissement ni info |
| flutter test | **310 tests réussis**, aucun test supprimé ou désactivé ; dernière suite complète : 61 secondes |
| flutter build web | **Réussi : Built build/web**, compilation finale : 90,2 secondes |
| flutter doctor -v | **Android SDK introuvable** ; compilation APK non exécutée ; iOS non compilé depuis Windows |

Logs bruts : ../../work/step8b-pub-get.log, step8b-format.log, step8b-analyze.log, step8b-final-tests.log, step8b-build-web.log et step8b-doctor.log.

Les avertissements de versions de dépendances plus récentes ne sont pas des erreurs ; aucune mise à niveau générale des dépendances n’a été effectuée.

## Validation progressive avant chaque module suivant

| Palier | Suite ciblée | Résultat |
| --- | --- | --- |
| Signalements | sqlite_reports_test + reports_repository_test + sqlite_catalog_test | 60 réussis |
| Services | sqlite_services_test + services_repository_test + sqlite_reports_test | 39 réussis |
| Dons | sqlite_donations_test + donations_repository_test + sqlite_services_test | 33 réussis |
| Événements | sqlite_events_test + events_repository_test + sqlite_donations_test | 38 réussis |

Les vérifications complémentaires ont été ajoutées ensuite et sont incluses dans les 310 tests finaux.

## Nouveaux tests SQLite (19)

| Fichier | Nombre | Preuves principales |
| --- | --- | --- |
| test/sqlite_reports_test.dart | 7 | CRUD métier, confirmations, accès, LOST/FOUND, réclamations, histoire, photos, unicité, FK, rollback/reprise, doublons de source et texte non média |
| test/sqlite_services_test.dart | 3 | Rendez-vous et suppression légale de créneau, FK/unique ; carnet médical privé, vaccination+rappel atomiques, rollback ; garde jusqu’à l’avis unique |
| test/sqlite_donations_test.dart | 2 | Millimes exacts, confirmation unique, reçu, idempotence, rollback et reprise ; source/image/identifiants conservés |
| test/sqlite_events_test.dart | 2 | Capacité, attente, promotion, billet, pointage unique, bilan ; transfert source/photos/billets |
| test/sqlite_migration_8b_test.dart | 4 | Toutes collections des quatre modules, sources réelles Sembast, comparaison des valeurs et réouverture ; médias identiques ; FK invalide → rollback → correction → reprise ; upgrade v2 → v6 sans perte |
| test/sqlite_modules_widget_test.dart | 1 | Quatre scopes et catalogue sur le même runtime FFI, signalement SQL réellement affiché, navigation des quatre modules, marqueurs d’import |

Les 291 tests précédents restent exécutés. Les règles d’accès et de rôle sont réutilisées, avec les mêmes anciens tests métier et d’interface, et des assertions supplémentaires sur le stockage SQL.

## Diagnostic des attentes asynchrones

Le temps simulé de testWidgets ne suffit pas à terminer les appels natifs FFI. Attendre uniquement un Future réel peut également bloquer les callbacks Flutter déjà programmés dans FakeAsync. Le montage conservé de 8A lance l’action dans runAsync tout en faisant avancer les frames et les callbacks en attente ; il impose une échéance et propage les erreurs. Le nouveau test réutilise ce mécanisme, y compris lors de la fermeture. Aucun SQL, contrôle d’accès ou assertion n’est désactivé.

Les services lisent le catalogue dans leur transaction. Deux transactions imbriquées sur la même connexion auraient constitué un vrai interblocage applicatif. DatabaseHelper réutilise désormais la transaction courante dans sa zone, et SqliteCatalogDatabase utilise directement cet exécuteur pour la lecture imbriquée. Les tests de réservation, consultation médicale et garde passent sur le moteur réel.

## Vérification indépendante

[verification-8b.json](output/database/verification-8b.json) est produit par Python sqlite3 en ouvrant la base fictive en lecture seule :

- user_version = 6 ;
- 39 tables non vides, dont 38 métier ;
- integrity_check = ok ;
- foreign_key_check = [] ;
- exemple monétaire : 12,345 TND stocké comme INTEGER 12345, sans perte de précision.

La fixture contient des données fictives pour les quatre modules et les relations 8A. Le schéma complet est exporté dans [schema-8b.sql](output/database/schema-8b.sql). Les tests vérifient que les sources Sembast restent identiques et que leur contenu n’est pas relu après validation des marqueurs.

## Limites de validation

- Le code natif utilise réellement la factory sqflite Android/iOS ; les tests utilisent SQLite FFI. Aucun appareil Android/iOS n’est disponible pour confirmer l’exécution du plugin sur appareil.
- Build Web validé ; le navigateur garde Sembast/IndexedDB et SharedPreferences. Cette étape ne prétend pas exécuter SQFlite dans Chrome ni avoir testé un appareil mobile.
- Aucune donnée d’un téléphone utilisateur n’a été accessible. L’import réel se déclenche au premier accès natif au module ; les preuves ici proviennent de fixtures Sembast et de fichiers SQLite isolés.
- Les fichiers médias copiés avant un échec SQL peuvent rester non référencés, sans nettoyage destructif. Les anciennes sources sont conservées.
- Anciennes limites métier préservées : paiements simulés, récurrences manuelles, rappels internes, pas de backend ni nouvelle API externe.

Le logo officiel est inchangé (SHA-256 documenté dans SQLITE_STEP_8B.md). Aucune étape 9 commencée.
