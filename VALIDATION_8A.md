# Animora — Validation de l’étape 8A

## État repris après interruption

Avant l’interruption, les dépendances, le schéma relationnel, les adaptateurs de plateformes, les DAO, les repositories SQL et l’import contrôlé étaient déjà présents. Le test de fondation et les 29 tests métier SQLite avaient réussi. Le transfert complet, les contraintes, le rollback et la reprise après échec de migration étaient donc conservés ; ils n’ont pas été réécrits depuis zéro.

Le blocage restant concernait les nouveaux tests d’interface SQLite/FFI, pas une opération métier bloquée dans l’application.

## Correction du blocage

Les traces temporaires ont établi que le parcours favori terminait ses opérations, y compris les vérifications SQL, avant de rester en attente pendant le nettoyage. La fermeture FFI et certains callbacks de store dépendaient de deux contextes asynchrones : l’événement réel et FakeAsync utilisé par Flutter pour les widgets.

Le montage SQL ouvre la connexion et démarre le chargement dans tester.runAsync, puis attend la fin effective du chargement initial. Les vérifications asynchrones SQL font progresser les frames jusqu’à la complétion, avec une limite explicite de dix secondes qui provoque un échec si l’opération ne termine pas. Le nettoyage démonte l’arbre de widgets, draine les callbacks restants et attend la fermeture de la base. Le pilote sans isolate est limité aux tests d’interface ; les tests métier utilisent également SQLite FFI avec son isolate.

Le test de signature attend aussi la disparition du message de confirmation précédent, qui masquait le bouton. Aucun contrôle d’accès, contrainte SQL, assertion, test ou avertissement de hit-test n’a été désactivé. Les traces temporaires ont été retirées.

## Vérifications finales

- flutter pub get : réussi.
- dart format . : 240 fichiers examinés, aucun changement restant lors du passage final.
- flutter analyze : No issues found (2,3 s).
- flutter test : 291 tests réussis, aucun échec (58 s).
- flutter build web --no-web-resources-cdn : réussi (93,2 s).
- Les 256 tests existants restent réussis.
- Nouveaux tests : 1 test de fondation, 30 tests métier/stockage/migration et 4 tests d’interface, soit 35 tests SQLite.

Les durées ci-dessus sont celles du dernier passage local, et non des garanties de performance.

Les tests vérifient les CRUD animaux/favoris/adoptions/questionnaires, l’isolation par utilisateur, les droits ADMIN, la signature et l’intégration avec le carnet de santé existant. Ils couvrent aussi les FK, UNIQUE et CHECK, les doublons concurrents, le rollback après une erreur SQL au milieu d’une décision, les profils métier sans identifiants d’authentification, la réouverture de fichiers SQLite et la mise à niveau du schéma v1 vers v2.

L’import teste les identifiants et compteurs conservés, les huit tables métier, les photos et profils historiques, l’absence de modification du stockage source, les entrées invalides, les références orphelines et les identifiants dupliqués. Un trigger injecte une erreur au milieu de l’import : toutes les insertions sont annulées et le marqueur reste absent ; après retrait du trigger, une nouvelle tentative réussit. Une migration marquée est ignorée, même si le vieux catalogue est ensuite illisible, afin de ne pas réimporter ou dupliquer les données SQL.

## Preuve SQLite indépendante

output/database/animora-demo.db est une base fictive créée par les tests FFI, fermée, rouverte puis exportée. Une deuxième connexion indépendante via Python sqlite3 l’a lue en mode lecture seule, avec activation des clés étrangères pour cette connexion.

Résultats : version du schéma 2 ; foreign_keys = 1 ; foreign_key_check vide ; integrity_check = ok.

| Table | Lignes fictives |
|---|---:|
| users | 7 |
| animals | 8 |
| favorites | 1 |
| adoptions | 1 |
| adoption_questionnaires | 1 |
| adoption_contracts | 1 |
| adoption_followups | 1 |
| foster_placements | 1 |
| database_metadata | 3 |

Les détails des relations, les colonnes User et le marqueur sont disponibles dans output/database/verification.json. Le schéma extrait est output/database/schema.sql. Cette preuve ne contient ni empreinte de mot de passe, sel ou session, et ne provient pas des données privées de l’utilisateur.

## Flutter Web

Le build final a été servi localement puis ouvert sur http://localhost:8765/#/animals avec le profil navigateur existant. Le catalogue a affiché neuf animaux, dont « Pixel — test 3A », et son état « Retirer des favoris ». Ces données Web antérieures sont donc toujours lisibles, sans réinitialisation du catalogue ni passage au plugin SQLite natif. Cette vérification était en lecture seule ; aucune donnée métier Web n’a été ajoutée ou supprimée. Le serveur temporaire a ensuite été arrêté.

Le Web conserve SharedPreferences pour le catalogue et l’authentification ; les autres gestions conservent Sembast Web. La compilation réussie n’est pas présentée comme une exécution du plugin SQFlite sur Chrome.

## Android / iOS

flutter doctor -v confirme Flutter 3.47.5 et Dart 3.13.4, mais aucun SDK Android local. flutter devices ne liste que Windows, Chrome et Edge. Aucune compilation APK ni exécution Android n’est donc revendiquée. Les enregistreurs de plugins Android et iOS contiennent SQFlite ; la sélection native est branchée sur Android/iOS, mais son exécution sur appareil reste à valider. iOS n’a pas été compilé dans cet environnement Windows.

Les tests FFI utilisent un véritable moteur SQLite sur l’hôte ; ils ne remplacent pas le test du transport du plugin mobile et du cycle de vie d’une application sur téléphone.

## Préservation et périmètre

Aucun fichier source existant n’est supprimé et aucune donnée historique n’est effacée. Le logo officiel conserve son SHA-256 B5F45FACFFCC664D7BAD0A1552040ADB48C485F78F789D2A494528860A7D4A86. Le modèle User et les fichiers d’authentification restent identiques à la sauvegarde de l’étape 8A. Les écrans et la charte graphique ne sont pas modifiés.

Les gestions Signalements, Vétérinaire/pet-sitting, Dons et Événements ne sont pas migrées : leurs repositories et bases Sembast sont conservés. Le carnet de santé lit le catalogue SQL via l’abstraction existante lorsqu’elle est sélectionnée, sans déplacer ses propres données.

L’ancien catalogue SharedPreferences est conservé comme source d’origine, pas comme miroir des nouvelles écritures SQL. Pas de synchronisation Android/Web, pas de chiffrement ajouté, et hydratation du workflow en mémoire avant calcul des différences relationnelles : ces limites restent documentées dans SQLITE_STEP_8A.md.

L’étape 8B n’est pas commencée. L’inventaire complet est FILES_8A.md et le scénario manuel Android est dans SQLITE_STEP_8A.md.
