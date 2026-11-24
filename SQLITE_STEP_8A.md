# Animora — Étape 8A : SQFlite, animaux et adoptions

## Périmètre

La fondation SQFlite est limitée au catalogue Animaux et au workflow Adoptions / familles d’accueil. Le design, les routes et le logo officiel sont conservés. Les autres gestions ne sont pas migrées.

| Plateforme | Catalogue et workflow | Authentification | Autres gestions |
|---|---|---|---|
| Android / iOS | SQLite via le plugin sqflite, fichier animora.db | SharedPreferences inchangé | Sembast inchangé |
| Flutter Web | SharedPreferences, adaptateur existant | SharedPreferences | Sembast Web |
| Autres plateformes natives, si configurées | Adaptateur existant SharedPreferences | SharedPreferences | Sembast |
| Tests SQLite sur l’hôte | Moteur SQLite réel via sqflite_common_ffi | Doubles de stockage pour isoler les tests | Tests existants conservés |

La sélection est faite dans AdoptionScope. Le fichier database_platform.dart utilise un import/export conditionnel ; le chemin Web ne charge pas l’implémentation native. L’API de types partagée est sqflite/sqlite_api.dart. Aucun écran n’accède à DatabaseHelper.

## Infrastructure et schéma

DatabaseHelper ouvre animora.db avec la version explicite 2. onConfigure active PRAGMA foreign_keys = ON et vérifie sa valeur sur chaque connexion. onCreate crée le schéma ; onUpgrade applique les versions manquantes ; un downgrade est refusé sans destruction des données.

- Version 1 : huit tables métier et la table technique database_metadata.
- Version 2 : index de recherche et index uniques partiels correspondant aux règles métier existantes.

Les dates sont conservées en texte ISO 8601 et les booléens en entiers 0/1. Les identifiants d’entités sont des INTEGER. Les identifiants User restent des TEXT pour respecter le modèle existant ; aucune nouvelle classe utilisateur n’est créée.

| Table | Identifiant et relations |
|---|---|
| users | id TEXT PRIMARY KEY ; email UNIQUE COLLATE NOCASE ; profils métier uniquement |
| animals | id INTEGER PRIMARY KEY ; colonnes correspondant à tous les attributs Animal |
| favorites | PRIMARY KEY(userId, animalId) ; FK users et animals, suppression en cascade |
| adoptions | id PRIMARY KEY ; FK userId → users, animalId → animals, suppression des parents restreinte |
| adoption_questionnaires | id PRIMARY KEY ; adoptionId UNIQUE, FK adoptions, cascade |
| adoption_contracts | id PRIMARY KEY ; adoptionId UNIQUE, FK adoptions, cascade |
| adoption_followups | id PRIMARY KEY ; adoptionId FK adoptions, cascade |
| foster_placements | id PRIMARY KEY ; FK animalId → animals, fosterFamilyUserId → users, suppression des parents restreinte |
| database_metadata | clé/valeur technique : compteurs d’identifiants et marqueur d’import |

Les contraintes CHECK protègent les identifiants positifs, l’âge entier 0–200, le poids positif plafonné, les booléens, les statuts et la cohérence signature/date. Les index couvrent notamment les favoris par animal, les adoptions par utilisateur/date et animal/statut, les suivis par adoption/date et les hébergements par famille/statut.

Les index uniques partiels interdisent deux demandes PENDING du même utilisateur pour le même animal, deux adoptions ACCEPTED pour un même animal et deux accueils ACTIVE pour un même animal.

Le champ technique adoptions.applicantSnapshot conserve le profil historique déjà présent dans WorkflowData.applicants. Il évite qu’une modification du profil courant réécrive les informations d’une ancienne demande. Ce n’est pas une nouvelle entité métier ni un stockage d’authentification.

## CRUD et règles métier

SqliteAnimalRepository, SqliteFavoriteRepository et SqliteAdoptionWorkflowRepository réutilisent les interfaces existantes et les validations des repositories locaux. Les mutations existantes passent par SqliteCatalogDatabase : lecture relationnelle, application des règles puis écriture des seules lignes modifiées dans une transaction SQLite. Il n’existe pas de catalogue JSON global sauvegardé en SQL.

SqliteCatalogDao réalise des requêtes paramétrées INSERT, SELECT, UPDATE et DELETE. Le workflow est hydraté en mémoire pour réutiliser les règles existantes ; ce choix évite deux implémentations divergentes des décisions, signatures et conversions. Il reste adapté à la taille de démonstration et pourra être optimisé sans changer les écrans.

- Animal : création, lecture par id, liste, modification, suppression. Favoris nettoyés atomiquement ; suppression d’un animal avec historique refusée.
- Favori : ajout idempotent, suppression, lecture par utilisateur connecté, unicité SQL.
- Adoption : création avec questionnaire et profil historique dans une seule transaction ; lecture par id, utilisateur et animal ; changement de statut via les décisions et annulations autorisées. La lecture par animal est réservée à ADMIN ; les demandes personnelles restent privées.
- Questionnaire : création atomique pendant le dépôt de la demande, lecture par adoption, modification par son propriétaire uniquement avant décision. La modification conserve les identifiants et recalcule le score par le service existant.
- Contrat, suivi et accueil : décisions, signature simulée, nouvelles, affectation, remarques et conversion continuent à fonctionner avec les lignes SQL correspondantes.

Accepter une demande, refuser ses concurrentes, réserver l’animal et créer le contrat forme une seule transaction. La signature et la clôture d’un accueil sont également atomiques avec leurs changements sur l’animal. Les notifications des stores surviennent après commit ; une erreur laisse l’état précédent et les compteurs inchangés.

## Import contrôlé des anciennes données

L’import concerne uniquement la clé SharedPreferences animora.adoption.v1. Les bases Sembast des autres modules ne sont ni transférées ni effacées.

1. Ouvrir le schéma SQLite et consulter le marqueur catalog_preferences_v1.
2. Si le marqueur existe, utiliser SQLite comme source de référence, sans réimporter les anciennes préférences.
3. Sinon, lire les données historiques sans les modifier. Si la clé est absente, utiliser le même jeu initial de huit animaux que l’ancienne version.
4. Refuser les identifiants dupliqués, schémas inconnus, données invalides et références orphelines. Les favoris invalides ne sont pas silencieusement filtrés.
5. Lire les profils User nécessaires, sans transférer credential, salt, hash, password ou sessionId. La table users représente uniquement les profils métier. Les snapshots historiques des demandes sont conservés.
6. Vérifier que les tables de destination sont vides en l’absence de marqueur ; aucune fusion ou écrasement automatique d’une base déjà remplie.
7. Dans une transaction : importer les utilisateurs puis les entités dans l’ordre des clés étrangères, préserver les identifiants, dates, photos et compteurs.
8. Comparer les nombres de lignes, exécuter PRAGMA foreign_key_check et PRAGMA integrity_check, puis relire et valider les données importées.
9. Écrire le marqueur uniquement à la fin de cette même transaction.

Une erreur SQL au milieu de l’import annule toutes les insertions et laisse le marqueur absent. Le stockage d’origine reste intact et une nouvelle tentative est possible après correction. Les tests injectent une erreur par trigger SQL pour vérifier ce comportement.

Les profils métier sont ensuite synchronisés depuis le stockage d’authentification existant avant les opérations SQL, afin de permettre les favoris et demandes des nouveaux comptes. Les mots de passe et la session ne sont jamais déplacés vers SQLite. Les profils historiques des demandes ne sont pas remplacés par cette synchronisation.

L’ancien catalogue est conservé comme sauvegarde d’origine, sans double écriture après migration. Il ne représente donc pas les modifications SQL ultérieures. Le Web conserve sa propre version des données ; aucune synchronisation mobile/Web n’est revendiquée.

## Tests et diagnostic asynchrone

Les tests métier utilisent une vraie base SQLite FFI, et non un mock SQL. Ils vérifient les CRUD, contraintes, droits, rollback, import, réouverture sur disque et migration du schéma v1 vers v2. Les bases en mémoire utilisent des connexions indépendantes pour éviter qu’un test partage le marqueur d’une autre base.

Les tests d’interface emploient SQLite FFI sans isolate. Flutter utilise une zone FakeAsync pour ces tests, alors que la fermeture FFI et certaines opérations sont asynchrones réelles. Les opérations de favoris terminaient correctement ; l’attente pouvait rester bloquée dans le nettoyage, avec des callbacks de store encore planifiés dans la zone simulée. Le montage doit démarrer les opérations natives dans runAsync ; le nettoyage démonte les widgets, fait progresser les callbacks et attend explicitement la fermeture. Les assertions SQL et contrôles d’accès restent actifs.

Les résultats exacts sont consignés dans VALIDATION_8A.md.

## Vérification manuelle sur Android

Le SDK Android est nécessaire. Une fois installé et un appareil disponible :

1. Exécuter flutter pub get puis flutter run -d IDENTIFIANT_APPAREIL.
2. Se connecter avec un compte de démonstration existant et ouvrir le catalogue : l’import est déclenché lors de son premier chargement actif.
3. Comme ADMIN, créer/modifier un animal sans historique ; comme citoyen, ajouter puis retirer un favori.
4. Déposer une demande avec questionnaire ; comme ADMIN, accepter ; comme demandeur, signer le contrat de démonstration et ajouter un suivi.
5. Vérifier aussi une affectation en accueil et son historique.
6. Arrêter réellement l’application, la rouvrir et vérifier les données et l’absence de doublons.
7. Dans Database Inspector d’Android Studio, ouvrir animora.db et vérifier les tables, les relations et le marqueur. Ne pas confondre les anciennes bases animora_reports.db et similaires avec cette base SQLite.

Requêtes utiles, sur une connexion ayant activé ses clés étrangères :

~~~sql
PRAGMA foreign_keys = ON;
PRAGMA foreign_keys;
PRAGMA user_version;
PRAGMA foreign_key_check;
PRAGMA integrity_check;
SELECT name, sql FROM sqlite_master WHERE type IN ('table','index');
SELECT id, name, species, status FROM animals;
SELECT userId, animalId, addedAt FROM favorites;
SELECT a.id, u.firstName, u.lastName, an.name, a.status
FROM adoptions a JOIN users u ON u.id=a.userId
JOIN animals an ON an.id=a.animalId;
SELECT key, value FROM database_metadata;
~~~

## Vérification Web et limites

flutter build web doit réussir sans adaptateur SQLite natif Web. Le catalogue Web reste celui de SharedPreferences, tandis que Signalements, Vétérinaire/pet-sitting, Dons et Événements continuent à utiliser Sembast Web. Leur état n’est pas importé dans SQLite à cette étape.

Le fichier de démonstration output/database/animora-demo.db est généré par les tests avec des données fictives, pour inspection des tables et relations. Il ne constitue ni une base extraite d’Android ni un transfert des données privées de l’utilisateur.

Les données restent locales et non chiffrées. Il n’y a pas de backend, de synchronisation multiappareil, de migration des identifiants User ni de paiement réel. Le plugin mobile et le cycle de vie Android/iOS doivent être validés sur appareil si le SDK et les appareils ne sont pas disponibles dans l’environnement de développement.

L’étape 8B n’est pas commencée. Voir FILES_8A.md pour l’inventaire et VALIDATION_8A.md pour les vérifications.
