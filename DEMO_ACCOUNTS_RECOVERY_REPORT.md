# Animora — récupération des comptes de démonstration

## 1. Diagnostic et portée de la récupération

`AUTH_CREDENTIALS` signifie qu’aucun compte chargé ne correspond à l’e-mail normalisé ou que son mot de passe n’est pas vérifié. Ce code ne démontre ni une suppression ni une corruption.

L’audit identifie les points suivants :

- Depuis 10C, le démarrage normal ne crée plus les comptes de démonstration lorsqu’aucun document de comptes n’existe. Une installation Safari neuve peut donc afficher normalement la connexion sans posséder ces comptes.
- Chrome Windows, Safari iPhone et chaque origine HTTP/HTTPS ont des stockages indépendants. La présence d’un compte dans un navigateur ou dans une base d’exemple n’implique pas sa présence dans un autre.
- Les sept profils historiques sont retrouvés dans `lib/features/auth/data/demo_accounts.dart`, les sauvegardes de code avant 10C et les deux bases d’exemple du dépôt.
- L’audit en lecture seule de `output/database/animora-demo.db` et `animora-8b-demo.db` retrouve leurs sept profils dans `users`, mais **aucune entrée correspondante dans `auth_accounts`**. Ces fichiers ne sont pas les bases installées sur un téléphone. Ils n’ont pas été modifiés pour leur donner de nouveaux secrets.
- La migration conserve les identifiants et les objets PasswordDigest. PBKDF2-HMAC-SHA256 reste à 120 000 itérations par défaut, sel 16 octets, empreinte 32 octets ; aucune conversion des anciens secrets n’a été faite.
- Une incohérence réellement trouvée dans le code de connexion était la normalisation incomplète de l’e-mail stocké : seul l’e-mail saisi était nettoyé des espaces. La comparaison nettoie maintenant les deux côtés, sans réécrire les données originales.
- Un second défaut est **reproduit dans Chrome debug sur IP HTTP**, pendant le seed : `AUTH_KDF`, exception `_TypeError`. La détection WebCrypto de `cryptography` 2.9.0 utilise un getter JS non nullable pour `crypto.subtle`, alors que cette propriété est absente sur ce contexte HTTP. Le contrôle de disponibilité peut donc échouer avant le repli prévu. Ce défaut peut aussi toucher la vérification de mots de passe existants ; il n’indique pas une corruption des comptes.

**Le contenu réel du stockage Safari et son ancien mot de passe ne sont pas accessibles ici.** La cause exacte de l’échec sur cet appareil reste donc à distinguer entre absence locale, mot de passe différent ou autre contexte de stockage. Aucun compte existant n’est réinitialisé sur la base de ce seul diagnostic.

Le correctif reste dans le projet : détection WebCrypto avec getters JS nullables, puis sélection explicite de `DartPbkdf2` avec `DartHmac(DartSha256())` lorsque le contexte n’offre pas SubtleCrypto. Il faut aussi éviter `DartHmac.sha256()` dans ce chemin, car cette factory appelle à nouveau la sélection globale SHA256 de la bibliothèque. Le coût, la longueur, le sel et le format restent identiques. Les implémentations natives et WebCrypto disponibles sont conservées ; aucune bibliothèque ni fichier SDK n’est modifié. Ce défaut est établi sur l’environnement debug HTTP testé, sans prétendre disposer d’une trace Safari de l’iPhone.

## 2. Comptes retrouvés et définition validée

Valeurs utilisées **uniquement si le compte manque**. Un compte déjà présent garde ses propres données, son identifiant, son profil, son statut et ses secrets, même s’ils diffèrent de ce tableau.

| E-mail | ID de référence si nouveau | Profil | Statut initial |
| --- | --- | --- | --- |
| citizen@animora.test | demo-citizen | Citoyen | Actif |
| veterinarian@animora.test | demo-veterinarian | Vétérinaire | Actif |
| pet-sitter@animora.test | demo-pet-sitter | Pet-sitter | Actif |
| foster@animora.test | demo-foster | Famille d’accueil | Actif |
| pending@animora.test | demo-pending | Vétérinaire | En attente |
| blocked@animora.test | demo-blocked | Citoyen | Bloqué |
| admin@animora.test | demo-admin | Administrateur | Actif |
| mohamed@animora.test | demo-mohamed | Citoyen | Actif |

Les sept premiers profils/statuts viennent des anciens fichiers. Mohamed n’a pas été retrouvé dans le code, les sauvegardes textuelles ou les deux bases d’exemple examinées. **Le profil Citoyen puis le statut Actif ont été explicitement confirmés par l’utilisateur dans cette conversation.** Pour une création nouvelle seulement, « Mohamed Démo » et « Non renseignée » sont des valeurs fictives de présentation, pas des données personnelles récupérées. Un profil Mohamed déjà présent est intégralement conservé.

Mot de passe des **nouveaux comptes de démonstration** : `Animora2026!`, réservé aux données fictives de développement. Il est haché avant persistance, jamais écrit en clair dans SQLite/SharedPreferences. Il ne remplace pas un mot de passe existant.

## 3. Mécanisme ajouté

L’activation demande simultanément un **build debug** et l’option explicite `ANIMORA_DEMO_SEED=true`. Sans cette option, aucun changement au démarrage normal. Un build release ou profile refuse le seed, même avec cette option ou une demande directe au repository. L’ancien chemin de fixtures `seedDemoAccounts` est lui aussi limité au debug/test.

Le seed s’exécute dans l’initialisation sérialisée du repository, séparément de l’inscription publique. Il ne modifie pas `AccountPolicy` et ne permet pas une inscription publique administrateur.

Procédure :

1. Charger et valider les comptes existants avec le stockage habituel ; une lecture impossible ou un document corrompu reste une erreur, jamais une liste vide de remplacement.
2. Rechercher chaque e-mail normalisé. S’il existe, conserver l’objet User et l’empreinte exactement. Vérifier le mot de passe de démonstration et signaler seulement un compteur de divergences, sans réinitialisation.
3. En SQLite, rechercher aussi les profils `users` sans compte authentifiable. Si un profil de cet e-mail existe, reprendre son ID et ses attributs ; ajouter les secrets seulement en l’absence d’un compte d’authentification.
4. Si un identifiant est déjà occupé par un autre compte, signaler le conflit et ne rien écraser pour ce compte. Les autres créations sûres peuvent aboutir.
5. Hacher les mots de passe des comptes réellement manquants avec le PasswordHasher existant.
6. Publier une seule écriture du document Web ou une transaction via SqliteAuthStorage. La session courante est conservée. Un échec ne publie pas de seed partiel ; le réessai est possible.
7. Après succès, produire uniquement les compteurs `AUTH_DEMO_RECOVERY created=...; preserved=...; conflicts=...; password_mismatches=...`. Aucun mot de passe, empreinte, sel, jeton ou contenu de compte n’est journalisé.

La réexécution ne change ni les sels ni les empreintes des comptes présents et ne réécrit pas le document lorsque rien n’est ajouté. Le rapprochement SQLite est revérifié dans la transaction avant de rattacher un nouveau compte à un profil existant, pour refuser un écrasement concurrent.

Sur Web, le repository relit le document avant ses opérations. L’adaptateur refuse également un document modifié depuis son chargement (`AUTH_PREFERENCES_CONCURRENT`), puis compare à nouveau la valeur ciblée juste avant l’écriture synchrone d’une seule clé. L’encodage reste celui de SharedPreferences Web (`jsonEncode` de la chaîne JSON), y compris pour l’ancienne clé préfixée. Il s’agit d’un contrôle optimiste de concurrence, pas d’une transaction multi-onglets de type serveur. Aucune autre clé n’est effacée ou réécrite.

SQLite reste en **version 7**, avec les mêmes tables `users`, `auth_accounts` et clés étrangères. Les secrets natifs restent dans le coffre sécurisé. Les anciennes sources SharedPreferences restent présentes. Aucun reset, effacement IndexedDB, suppression d’utilisateur ou modification des migrations n’a été effectué.

## 4. Fichiers concernés

- Nouveau `lib/features/auth/data/demo_recovery.dart` : option de développement, huit profils de référence et résultat de récupération.
- `lib/features/auth/repositories/local_auth_repository.dart` : récupération idempotente, protection des données présentes, garde debug, normalisation e-mail corrigée.
- `lib/features/auth/repositories/sqlite_auth_repository.dart` : transmission de l’option de récupération.
- `lib/features/auth/services/auth_backend_native.dart` et `auth_backend_web.dart` : activation explicite dans la composition de plateforme.
- `lib/features/auth/services/local_auth_storage.dart` : interface de consultation des profils pour rapprochement.
- `lib/features/auth/services/preferences_auth_web.dart` et `preferences_auth_native.dart` : transmission de la valeur attendue et refus Web d’une écriture obsolète ; même format de préférences.
- `lib/features/auth/services/sqlite_auth_storage.dart` : lecture des profils existants et vérification transactionnelle avant rattachement.
- Nouveau `test/demo_accounts_recovery_test.dart` : tests de récupération et de préservation.
- Nouveaux `tool/audit_demo_accounts.dart` et `tool/demo_recovery_web_probe.dart` : audit SQLite en lecture seule et validation Web isolée, hors application de production.
- `lib/features/auth/services/password_hasher.dart`, nouveaux `password_kdf.dart`, `password_kdf_native.dart`, `password_kdf_web.dart`, et `auth_environment_web.dart` : sélection sûre du même PBKDF2 en HTTP debug et diagnostics JS nullables.
- Nouveau `test/password_kdf_compatibility_test.dart` : compatibilité de l’empreinte Dart et maintien des paramètres de production.
- `README.md` : commande explicite de préparation, ajout de Mohamed validé et description actuelle de la persistance native/Web.

Les six modules métier, les six API, le modèle User et le logo officiel sont conservés. Empreinte SHA-256 du logo : `B5F45FACFFCC664D7BAD0A1552040ADB48C485F78F789D2A494528860A7D4A86`.

## 5. Validation

| Vérification | Résultat / preuve |
| --- | --- |
| Audit SQLite | Deux bases d’exemple ouvertes en lecture seule. `../../work/demo-recovery-db-audit.log` |
| Tests ciblés | **15 réussis**, 6 s. `../../work/demo-recovery-targeted.log` |
| `flutter pub get` | Réussi. `../../work/demo-recovery-pub-get.log` |
| `dart format .` | Réussi. `../../work/demo-recovery-format.log` |
| `flutter analyze` | **No issues found!**. `../../work/demo-recovery-analyze-clean.log` |
| `flutter test --reporter expanded` | **387 réussis**, 0 échec, 1 min 26 s. Les 370 tests précédents sont conservés. `../../work/demo-recovery-tests.log` |
| `flutter build web` final | **Réussi**, 75,9 s, `Built build/web`. `../../work/demo-recovery-build.log` |
| Chrome debug localhost, flag actif | **17 contrôles réussis**, WebCrypto disponible. `../../work/demo-recovery-chrome-localhost-fixed.log` |
| Chrome debug IP HTTP, flag actif | **17 contrôles réussis**, contexte non sécurisé et WebCrypto absent ; PBKDF2 Dart avec les paramètres de production. `../../work/demo-recovery-chrome-ip-fixed.log` |
| Chrome release, flag demandé | **4 contrôles réussis** : option refusée, aucune écriture de compte, demande directe également refusée, aucun administrateur démo. `../../work/demo-recovery-chrome-release.log`. Sonde release compilée en 46,6 s (`../../work/demo-recovery-probe-release-build.log`). |
| Android / iOS natif | Android SDK toujours introuvable (`../../work/demo-recovery-doctor.log`), aucune compilation APK ni exécution native. |
| Safari iPhone | Pas d’exécution réelle disponible ici ; procédure manuelle ci-dessous. |

Les tests couvrent les huit connexions/profils/statuts, les restrictions pending/blocked et administrateur, l’idempotence, la préservation des sels/empreintes/session, les comptes personnels existants, un mot de passe démo différent conservé, un e-mail historique avec espaces/casse, les collisions d’ID, le rollback et le réessai. En SQLite réel via FFI, un profil ayant un autre ID et un signalement existant conserve ses attributs et sa clé étrangère après récupération ; un échec SQL annule toutes les nouvelles lignes. Le coffre natif est simulé en mémoire dans ces tests, sans prétendre valider Keychain/Keystore sur téléphone.

Les essais Chrome utilisent le vrai adaptateur SharedPreferences et un build debug de la sonde avec `ANIMORA_DEMO_SEED=true`. Chacun ouvre un profil temporaire isolé ; aucune origine ni donnée personnelle `:8080` n’est automatisée. Les 17 contrôles vérifient les huit comptes, les deux restrictions, la répétition du seed, la conservation exacte du document et de la session, un nouveau backend et le refus d’écraser un compte ajouté depuis une autre copie. Ils sont distincts des 387 tests VM. Le runner Flutter Chrome défectueux de 10C n’est pas déclaré réparé : cette validation utilise une sonde Web compilée servie sur `:8097`.

La trace avant correction est `../../work/demo-recovery-chrome-ip.log` (`AUTH_KDF`, `_TypeError`). Le même parcours debug HTTP réussit après le choix explicite du PBKDF2 Dart. La sonde debug corrigée a été compilée en 45,2 s (`../../work/demo-recovery-probe-debug-build-final.log`). Le SDK et le package cryptography n’ont pas été modifiés.

Les 34 contrôles debug et les 4 contrôles release ne sont pas additionnés aux 387 tests VM. Ils confirment le fonctionnement du seed Web et son refus en production dans Chrome ; ils ne constituent pas un test Safari. Le serveur temporaire de la sonde a été arrêté après les essais.

## 6. Activation sur Chrome Windows

Depuis le projet Flutter, arrêter votre ancien serveur de développement et le relancer explicitement :

~~~powershell
flutter run -d web-server --debug --web-hostname 0.0.0.0 --web-port 8080 --dart-define=ANIMORA_DEMO_SEED=true
~~~

Ouvrir puis recharger la **même origine utilisée habituellement** dans Chrome. `http://localhost:8080` et `http://192.168.1.2:8080` ne partagent pas leurs comptes. Ne vider aucun stockage. L’initialisation ajoute uniquement les démos manquantes et affiche ses compteurs dans les journaux de développement.

Se connecter avec le compte souhaité et le mot de passe de démonstration ci-dessus. Vérifier les accès : pending et blocked doivent rester limités ; le compte administrateur doit accéder à ses écrans. Pour désactiver la préparation après usage, relancer le même serveur sans `--dart-define=ANIMORA_DEMO_SEED=true`. Les comptes créés restent stockés ; le retrait de l’option ne les supprime pas.

Si `password_mismatches` est non nul, un compte existe mais son mot de passe est différent : utiliser son mot de passe existant. Aucune réinitialisation de secret n’est autorisée automatiquement. Si `conflicts` est non nul, ne pas effacer les données : un rapprochement explicite reste nécessaire.

## 7. Activation sur Safari iPhone

1. Relancer le serveur debug avec l’option ci-dessus sur le PC, puis connecter PC et iPhone au même réseau.
2. Dans Safari normal, recharger `http://192.168.1.2:8080` pour charger ce nouveau build. **Ne pas supprimer les données du site.** Le seed doit s’exécuter séparément sur cet iPhone, car il ne partage pas SharedPreferences avec Chrome.
3. Se connecter au citoyen, à Mohamed puis aux profils de test nécessaires. Recharger la page, fermer et rouvrir Safari à la même URL pour vérifier la persistance. Les modes normal et privé ne constituent pas le même stockage ; le privé ne garantit pas une conservation durable.
4. En cas d’échec, relever uniquement le code `AUTH_...`, les indicateurs de capacités et la version iOS. Une erreur cryptographique interrompt la création sans mot de passe en clair ni algorithme faible. Réessayer après correction du contexte ; ne pas effacer les comptes.

La primitive `crypto.getRandomValues` peut fonctionner sur HTTP ; le correctif sélectionne maintenant explicitement PBKDF2 Dart lorsque `crypto.subtle` n’est pas disponible, avec des getters JS nullables adaptés au debug. Cela ne garantit pas le comportement de toutes les versions Safari. Si les primitives nécessaires sont réellement indisponibles, utiliser HTTPS de confiance. La procédure locale avec certificat couvrant l’IP et les options Flutter `--web-tls-cert-path` / `--web-tls-cert-key-path` est décrite dans `AUTH_WEB_REGISTRATION_REPORT.md`, avec les liens officiels mkcert et Apple. Aucun certificat ni outil n’a été installé pendant cette récupération.

Passer à HTTPS crée **une autre origine** : il faut y préparer séparément les données fictives ; l’absence d’un compte HTTP à l’URL HTTPS n’indique pas sa suppression. Aucune copie automatique inter-navigateurs, inter-appareils ou inter-origines n’est implémentée.

## 8. Limites et arrêt

- Les comptes ont été retrouvés dans les sources et profils d’exemple, puis recréés uniquement dans les environnements de test isolés pour validation. Aucun contenu Safari de l’iPhone n’a été lu ou modifié depuis Windows. La restauration sur votre navigateur réel se fait à l’activation explicite ci-dessus.
- Les secrets des comptes existants ne sont jamais remplacés. Un coffre natif indisponible ou une source corrompue reste bloquant et nécessite un diagnostic, pas un nouveau seed destructif.
- Un build de production ne crée pas de comptes démo, mais les comptes déjà créés dans le même stockage ne sont pas supprimés lors d’un changement de build. Ne pas réutiliser une base de développement contenant des identifiants publics pour une distribution réelle.
- Aucun SDK Android installé ; aucun test réel Android/iOS ou Safari revendiqué.
- Aucune autre étape ni modification UI/UX engagée. Attente de validation utilisateur après cette récupération.
