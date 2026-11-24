# Animora — bilan de l’étape 10C

Diagnostic et validations du 10 novembre 2026. Cette étape conserve les modules métier, les API et les données existantes. Aucun SDK installé, aucune signature Apple modifiée, aucune étape UI/UX commencée.

## 1. État initial et reprise

Avant 10C, `LocalAuthRepository` conservait un document JSON version 1 dans SharedPreferences, clé `animora.local_auth.v1` : profils, empreintes des mots de passe et identifiant de session. La table SQLite `users` existait déjà comme source de relations métier, alimentée par les anciens profils. Le schéma était en version 6. La référence avant modification comptait **339 tests réussis** (`../../work/step10c-baseline-tests.log`).

La reprise a conservé les fichiers déjà implémentés : stockage SQLite d’authentification, migration, coffre sécurisé, adaptateurs Web, diagnostics et tests. L’état Git contient aussi les travaux non commités des étapes précédentes ; aucune réinitialisation du dépôt n’a été effectuée. La sauvegarde de comparaison 10C est `../../work/step10c-before/`.

## 2. État final de la persistance native

Sur Android/iOS, la composition sélectionne `SqliteAuthRepository` dans la même base **`animora.db`, version 7** et partage le même `DatabaseHelper` avec les modules. Connexion, inscription, lecture de session, modification de profil et changement de statut utilisent cet adaptateur. La logique d’autorisation existante reste dans `LocalAuthRepository` et `AccountPolicy` ; elle n’est pas dupliquée dans le mapping SQL.

Sur Web, la composition conserve SharedPreferences pour les comptes et Sembast/IndexedDB pour les autres données. Elle n’appelle ni le coffre sécurisé natif ni SQFlite. Aucun SQLite WebAssembly ajouté. Windows conserve l’adaptateur de préférences antérieur ; les tests SQLite Windows utilisent explicitement FFI.

### Schéma et relations

| Élément | Rôle / contrainte |
| --- | --- |
| `users` existante | Même identifiant stable, prénom/nom, e-mail, téléphone/photo, ville, profil, statut et `createdAt`. Aucune seconde table de profils. |
| `idx_users_email_normalized` | Nouvel index UNIQUE sur `lower(trim(email))`. Une collision préexistante fait échouer la mise à jour plutôt que supprimer un compte. |
| `auth_accounts` nouvelle | `userId` PRIMARY KEY et FOREIGN KEY vers `users(id)` avec DELETE RESTRICT ; `credentialRef` UNIQUE non vide ; révision positive et `updatedAt` technique. |
| `database_metadata` existante | Marqueur `auth_preferences_v1` et état `auth_state_v1` : révision et référence opaque de session. |

Les migrations v1 à v6 sont conservées ; seule une branche additive v7 est ajoutée. Le modèle User n’avait pas de date de modification : aucune date métier fictive n’a été inventée. `updatedAt` concerne la ligne technique d’authentification.

Les références à `users` restent inchangées : favoris, adoptions, placements, signalements/réclamations, vétérinaires, clients, pet-sitters, donateurs, organisateurs/participants et bénévoles. Les profils restent `citizen`, `veterinarian`, `fosterFamily`, `petSitter`, `admin`, avec les statuts `pending`, `active`, `blocked`. Aucun rôle Association réintroduit.

### Migration des comptes

1. Vérifier le marqueur avant de lire l’ancienne source.
2. Initialiser l’import catalogue existant si nécessaire, sans le recommencer s’il est marqué.
3. Valider le document complet : version, identifiants, e-mails normalisés uniques, profils/statuts, dates et format des empreintes.
4. Préparer des entrées immuables dans le coffre natif et relire leur valeur pour confirmer l’écriture.
5. Dans une transaction SQLite, rapprocher les profils existants sans changer leurs identifiants, insérer les références d’authentification, vérifier profils/comptages et intégrité SQL.
6. Publier l’état puis le marqueur en dernier, dans la même transaction.

Une erreur SQL annule les écritures SQL ; l’ancienne source reste intacte et un réessai est possible. Le marqueur validé évite une réimportation ultérieure. Les modifications suivantes utilisent une révision avec vérification avant et pendant la transaction pour refuser une écriture obsolète.

Si le même ID a un profil SQLite différent de SharedPreferences, sans date comparable, l’import s’arrête avec `AUTH_SQL_PROFILE_CONFLICT`. Il ne choisit pas arbitrairement une version. Une réconciliation explicite sera nécessaire dans ce cas. Après migration, la synchronisation métier ignore les anciens profils des utilisateurs authentifiés pour ne pas écraser leur état SQLite.

### Sécurité et limites

- PBKDF2-HMAC-SHA256 conservé : 120 000 itérations par défaut, sel de 16 octets, empreinte de 32 octets. Les empreintes existantes sont transférées sans recalcul ni conversion de mot de passe.
- Les nouvelles empreintes/sels et l’identité de session sont conservés via `flutter_secure_storage` : Keychain iOS, chiffrement natif Android. SQLite contient les profils et des références opaques, pas de mot de passe, de sel, d’empreinte ou d’identifiant de session en clair.
- **Le document SharedPreferences historique reste présent, avec ses anciennes empreintes et sa session**, conformément à la consigne de conservation. Cette copie n’est pas rendue sécurisée rétroactivement.
- Coffre et SQLite ne constituent pas une transaction commune : la préparation immuable précède la publication atomique des références SQL. Un échec peut laisser une entrée de coffre non référencée. Aucun nettoyage automatique n’est effectué pendant cette étape.
- Un secret de coffre manquant après migration provoque une erreur explicite ; aucune restauration silencieuse depuis une ancienne copie n’est tentée.
- Aucun nouveau compte administrateur ni mot de passe par défaut n’est créé au démarrage. Les comptes historiques, y compris les anciens comptes de démonstration s’ils existent, sont conservés. Les fixtures de tests demandent explicitement leur jeu de démonstration.
- Il s’agit toujours d’une authentification locale, pas d’une authentification serveur ni d’une protection contre un propriétaire qui modifie ses propres données locales.

## 3. Safari iOS : diagnostic séparé

Le message initial provenait de l’échec d’initialisation dans `AuthSession`, affiché par `SplashScreen`. Le chemin impliqué est : initialisation Flutter → repository → lecture SharedPreferences → décodage/validation JSON → restauration de session. Sur une installation sans comptes, l’ancien démarrage ajoutait aussi la génération des comptes de démonstration, le calcul PBKDF2 et une écriture.

**La cause exacte observée sur l’iPhone n’est pas confirmée** : ni le téléphone ni ses journaux Safari n’étaient accessibles. Les hypothèses restent une erreur de stockage/énumération, un document incompatible/corrompu ou une erreur dans l’ancien amorçage. HTTP LAN n’est pas à lui seul une cause démontrée : la bibliothèque cryptographique existante prévoit déjà un repli Dart lorsque WebCrypto n’est pas disponible.

Corrections ciblées et protections :

- `WidgetsFlutterBinding.ensureInitialized()` avant le lancement de l’application.
- Une source réellement absente mène normalement à connexion/inscription, sans génération d’administrateur, calcul cryptographique ni écriture au démarrage.
- Lecture SharedPreferencesAsync conservée ; si elle échoue, essai limité à la clé demandée dans localStorage avec le même encodage. Aucun balayage ni effacement des autres clés.
- Compatibilité avec l’ancienne clé `flutter.animora.local_auth.v1` lorsque la clé actuelle est absente ; les écritures restent dans l’emplacement sélectionné. Les deux documents ne sont pas fusionnés arbitrairement.
- JSON invalide ou refus d’accès propagé comme erreur, jamais transformé en liste vide. Validation de l’ancien document avant écriture pour éviter d’écraser une corruption détectée.
- Réessai relançant l’initialisation après une erreur temporaire ; document et session valides conservés sans réécriture au démarrage.
- Diagnostics affichés sur l’erreur du splash et des formulaires : étape `AUTH_READ`, `AUTH_DECODE_VALIDATE`, `AUTH_WRITE`, `AUTH_KDF`, ou code SQLite/coffre. Uniquement type d’exception et indicateurs de contexte sécurisé/WebCrypto/stockage ; aucun contenu de compte, e-mail, mot de passe, sel, empreinte ou session.

Les diagnostics permettent maintenant de distinguer les causes sur l’appareil. Ils ne prouvent pas que le défaut initial Safari est résolu ; l’essai réel ci-dessous reste nécessaire.

## 4. Blocage Chrome / HTTP 404

Suite concernée : `test/browser/auth_web_browser_test.dart` (6 cas). Le runner compile et ouvre son iframe mais reste à `+0`, avant les assertions.

Reproduction indépendante : `test/browser/runner_smoke_test.dart`, sans import Animora, plugin, stockage ni appel réseau applicatif, avec seulement `expect(1 + 1, 2)`. Même blocage. L’option `--timeout 20s` ne débloque pas cette phase de chargement ; l’exécution a été interrompue après collecte du diagnostic, sans supprimer le test.

Ressources en erreur sur le serveur de cette reproduction :

- `http://localhost:64096/canvaskit/chromium/canvaskit.js` → **404**.
- `http://localhost:64096/canvaskit/chromium/canvaskit.wasm` → **404**.

Les fichiers correspondants existent dans `C:/flutter/bin/cache/flutter_web_sdk/canvaskit/chromium/`. Le serveur interne `C:/flutter/packages/flutter_tools/lib/src/test/flutter_web_platform.dart`, méthode `_localCanvasKitHandler`, convertit `request.url` avec `path.fromUri`, puis vérifie `startsWith('canvaskit/')`. Le contrôle isolé Windows produit `canvaskit\chromium\canvaskit.js` et le test de préfixe retourne **false**. Cela explique le rejet des ressources sous ce SDK Windows (Flutter 3.47.5 / Dart 3.13.4).

Le problème reproduit relève du runner SDK, pas du repository d’authentification. **Aucun fichier interne du SDK n’a été modifié.** Une tentative antérieure de fourniture temporaire des ressources au navigateur de test n’a pas établi de réussite ; elle n’est pas une correction du projet. Aucun test ni assertion désactivé.

Preuves :

- `../../work/step10c-browser-verbose.log` : suite d’authentification initiale.
- `../../work/step10c-chrome-minimal.log` : reproduction minimale.
- `../../work/step10c-chrome-minimal-resources.log` : ressources 404 de l’iframe, collectées dans le seul Chrome headless de test.
- `../../work/step10c-chrome-path-proof.log` : conversion Windows / préfixe false.
- `../../work/step10c-path-check.dart` : reproduction de la conversion.

Commandes de reproduction (terminal dans le projet) :

~~~powershell
flutter test --platform chrome --verbose --timeout 20s test/browser/runner_smoke_test.dart
flutter test --platform chrome --verbose --timeout 60s test/browser/auth_web_browser_test.dart
~~~

Alternative sans modifier le SDK : valider l’application Web compilée selon la procédure manuelle suivante. Pour automatiser ces 7 cas navigateur, les relancer sur un environnement Flutter dont le runner sert correctement CanvasKit, par exemple un hôte non Windows disponible ultérieurement. Aucune installation ni mise à jour de SDK n’est réalisée ici.

## 5. Tests et résultats

Les 339 tests de référence sont conservés. Ajouts VM : 16 tests SQLite, 7 tests de démarrage et 1 test d’interface intégrant authentification et modules sur la même base. Les tests SQLite couvrent installation neuve, inscription/lecture, connexion valide/invalide, profils/statuts/autorisations, unicité e-mail, clés étrangères, import répété, sources invalides, échec coffre, échec SQL et reprise, rollback de session/profil, conflit de profils, concurrence, mise à jour v6 et réouverture d’un vrai fichier.

Le test d’interface utilise FFI et des attentes coopératives avec l’horloge de test ; aucune contrainte SQL ni autorisation supprimée. Le coffre natif y est remplacé par un double mémoire : cela ne valide pas Keychain/Keystore sur appareil.

Les 6 cas Web ajoutés couvrent démarrage neuf, comptes/session existants avec nouveaux adaptateurs, repli de lecture ciblée, ancienne clé préfixée, corruption préservée et PBKDF2 Dart. Le test minimal du runner est un 7e cas Web. Ces fichiers sont explicitement destinés au navigateur ; ils ne sont pas exécutés sur VM et restent bloqués avant assertions dans le runner Windows actuel.

| Validation | Résultat / preuve |
| --- | --- |
| `flutter pub get` | Réussi ; versions verrouillées conservées, avertissement de nouvelles versions disponibles sans mise à niveau. `../../work/step10c-pub-get-final.log` |
| `dart format .` | Réussi ; dernier passage : 308 fichiers, 0 modification. `../../work/step10c-format-final.log` |
| `flutter analyze` | **No issues found!**, 51,5 s. Deux informations de lint introduites dans les nouveaux tests ont été corrigées sans changer leurs assertions. `../../work/step10c-analyze-clean.log` |
| `flutter test --reporter expanded` | **363 réussis, 0 échec**, 1 min 11 s. `../../work/step10c-tests-final.log` |
| Tests ciblés SQLite/auth/démarrage/interface | **37 réussis, 0 échec**, 3 s. `../../work/step10c-targeted-final.log`. Ils sont inclus dans les 363, pas additionnés. |
| Tests Chrome auth (6) + minimal (1) | **Bloqués par le runner avant assertions**, aucune réussite revendiquée. |
| `flutter build web` | **Réussi**, `Built build/web`, 94,5 s ; dry run Wasm réussi (aucune migration SQLite WebAssembly). `../../work/step10c-web-final.log` |
| Android | SDK introuvable selon `../../work/step10c-doctor-final.log` ; aucune compilation APK, aucun test natif Android. |
| iOS / Safari réel | Non exécutés : environnement Windows sans iPhone accessible ni Mac/Xcode. |

## 6. Fichiers de l’étape 10C

- Composition : `lib/main.dart`, `lib/app/app.dart`, `lib/features/adoption/widgets/adoption_scope.dart`. Réutilisation de `SqliteRuntimeScope` existant.
- SQLite : `lib/core/database/database_constants.dart`, `database_migrations.dart`, `lib/features/adoption/database/sqlite_catalog_dao.dart`.
- Repositories : `lib/features/auth/repositories/local_auth_repository.dart`, `sqlite_auth_repository.dart`.
- Stockage/services auth : `auth_snapshot.dart`, `sqlite_auth_storage.dart`, `auth_vault.dart`, `auth_vault_native.dart`, `local_auth_storage.dart`, `auth_backend*.dart`, `preferences_auth_*.dart`, `auth_environment*.dart` dans `lib/features/auth/services/`.
- Diagnostics : `lib/features/auth/models/auth_requests.dart`, `state/auth_session.dart`, `screens/splash_screen.dart`, `widgets/auth_form.dart`.
- Dépendances : `pubspec.yaml`, `pubspec.lock` (`flutter_secure_storage`, `web`, dépendance de test `shared_preferences_web`).
- Tests : `test/sqlite_auth_test.dart`, `sqlite_auth_widget_test.dart`, `auth_startup_test.dart`, `browser/auth_web_browser_test.dart`, `browser/runner_smoke_test.dart`, `support/auth_test_support.dart`.

Le logo officiel conserve le SHA-256 `B5F45FACFFCC664D7BAD0A1552040ADB48C485F78F789D2A494528860A7D4A86`. Aucun changement des six API ni de logique métier hors persistance/composition d’authentification.

L’inventaire comparé à la sauvegarde avant 10C est disponible dans `../../work/step10c-changed-files.log` ; les autres modifications Git préexistantes sont conservées.

## 7. Validation manuelle Chrome Windows et iPhone

1. Garder les données navigateur et l’ancienne origine. Sur le PC, arrêter le serveur de développement existant puis le relancer depuis le projet avec la version actuelle :

   ~~~powershell
   flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
   ~~~

2. PC et iPhone sur le même réseau ; ouvrir **la même origine** `http://192.168.1.2:8080` dans Safari normal. Recharger la page pour charger le nouveau code. Ne pas effacer les données de sites. Si l’adresse IP a changé, les données de l’ancienne adresse ne sont pas automatiquement transférées.
3. Avec les comptes existants : vérifier que le splash se termine, que la session valide est restaurée, puis tester déconnexion, mot de passe incorrect rejeté, connexion correcte et lecture du profil. Ne pas publier de capture contenant des informations personnelles.
4. Recharger la page, puis fermer et rouvrir Safari à la même URL : vérifier les comptes, la session et des données existantes des modules (favori, demandes, signalements, services, dons, événements selon le rôle).
5. Pour une installation neuve, utiliser un profil navigateur de test isolé ou une origine de test séparée ; ne pas effacer l’origine réelle. Vérifier l’écran de connexion/inscription, sans administrateur automatique, puis inscription et connexion.
6. Reproduire les étapes dans Chrome Windows, sur la même origine de test choisie. Pour vérifier séparément le build de production, servir `build/web` avec un serveur HTTP statique local disponible. Si le port/protocole change, le stockage est distinct ; ne pas interpréter cela comme une perte.
7. Tester un onglet privé séparément avec uniquement des comptes de test : la persistance après fermeture n’est pas garantie. Un refus réel de stockage doit donner une erreur explicite, pas un catalogue de comptes vide présenté comme une lecture réussie. Ne pas corrompre volontairement les données réelles pour tester ce cas.
8. Si l’erreur persiste, copier le diagnostic `AUTH_...` affiché et les indicateurs non sensibles, la version iOS, le mode normal/privé et l’étape concernée. Appuyer sur Réessayer après résolution d’un refus temporaire. Sans Mac, ce texte affiché suffit pour poursuivre le diagnostic ; ne pas copier les valeurs de localStorage/IndexedDB.
9. Avec un Mac disponible : activer l’Inspecteur Web dans Réglages → Safari (ou Apps → Safari selon iOS) → Avancé, connecter et approuver l’iPhone, puis sélectionner sa page dans le menu Développement de Safari Mac. Relever uniquement codes/étapes non sensibles et éventuels statuts réseau. [Procédure officielle WebKit](https://webkit.org/web-inspector/enabling-web-inspector/).

HTTP, HTTPS, localhost et des ports différents sont des origines distinctes. Passer à HTTPS ne transfère pas les comptes de l’origine HTTP. Revenir à l’origine originale permet de retrouver son espace de stockage ; aucune migration inter-origines n’est implémentée ici. Les limites d’origine et de navigation privée sont décrites dans la [documentation localStorage](https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage). HTTPS reste requis pour certaines fonctions navigateur telles que la géolocalisation ; leur disponibilité n’est pas une preuve du bon chargement des comptes.

## 8. Points encore ouverts

- Cause réelle Safari à confirmer avec le diagnostic sur l’iPhone ; le problème du runner Chrome est indépendant.
- Exécution automatisée des 7 cas navigateur sur un runner fonctionnel ; fermeture/réouverture réelle de Chrome et Safari à vérifier manuellement.
- Validation Android/iOS sur appareil ou émulateur, incluant le coffre natif. Le plugin verrouillé demande Android API 23 minimum ; sauvegarde/restauration Android et configuration Keychain/provisionnement iOS doivent être examinées lors de la future étape native. Aucune configuration Apple spéculative effectuée.
- Copie SharedPreferences historique volontairement conservée ; entrées de coffre orphelines possibles après échec ; conflits de profils ou d’e-mails à réconcilier explicitement s’ils sont rencontrés.

L’étape s’arrête ici pour validation utilisateur ; aucune étape suivante n’est engagée.
