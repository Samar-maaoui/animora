# Animora — Gestion utilisateurs : sécurité, profil et connexion (après l'étape 11)

Intégré sur la version du groupe (SQLite v7, coffre sécurisé, API REST Countries,
navigation étape 11). Aucune base supplémentaire : tout passe par **animora.db**.

## Architecture conservée
La logique reste dans `LocalAuthRepository` (instantané des comptes), donc chaque
fonctionnalité marche **sur Android/iOS (SQLite + coffre)** et **sur le Web
(SharedPreferences)**. Nouvelle dépendance injectée : `AuthSecurityStore`.

| Plateforme | Comptes (existant) | Journal + réglages (nouveau) |
|---|---|---|
| Android / iOS | `SqliteAuthStorage` (users, auth_accounts, coffre) | `SqliteAuthSecurityStore` : table `auth_events`, réglages dans `database_metadata` |
| Web | `PreferencesAuthStorage` | `PreferencesAuthSecurityStore` (500 derniers événements) |
| Tests | `MemoryAuthStorage` | `MemoryAuthSecurityStore` (par défaut) |

## Schéma v8 (migration additive, v1 à v7 inchangées)
`auth_events(id INTEGER PK AUTOINCREMENT, type, email, userId, actorId, details, createdAt)`
+ index `(email, createdAt)` et `(createdAt)`. Pas de clé étrangère sur `userId` :
un échec de connexion peut viser un e-mail inconnu. Aucun mot de passe, empreinte
ni identifiant de session n'y est écrit.

## Fonctionnalités
- **Verrouillage anti-force brute** : 5 échecs en 15 min verrouillent l'e-mail
  15 min (même avec le bon mot de passe). Un succès remet le compteur à zéro.
  Avertissement quand il reste 2 tentatives.
- **Changement de mot de passe** (`/profile/password`) : vérifie l'ancien, refuse
  un mot de passe identique ; nouveau sel + empreinte (nouvelle entrée de coffre).
- **Journal de sécurité** (`/admin/security`, icône bouclier dans Gestion
  utilisateurs) : inscriptions, connexions, échecs, verrouillages, profil, photo,
  mot de passe, biométrie, décisions admin (auteur + transition).
- **Photo de profil** : caméra / galerie (`image_picker`), 512 px, data URI validée
  (`ProfilePhotoRules`) dans `users.photo`.
- **Ville par GPS** : bouton 📍 (inscription et modification du profil), réutilise
  `GeocodingApi` (Nominatim) et `ApiClient` du groupe.
- **Connexion biométrique** (`local_auth`, Android/iOS) : activation depuis le
  profil après vérification du téléphone ; bouton empreinte sur la connexion.
  Configuration : `FlutterFragmentActivity`, `USE_BIOMETRIC`, `NSFaceIDUsageDescription`.
- **Design connexion / inscription** : en-tête chien et chat, sélecteur
  Connexion | Inscription, champs avec icônes. Logo officiel, sélecteur de pays
  et diagnostics conservés.

## Tests
`test/user_security_features_test.dart` (verrouillage, mot de passe, photo,
biométrie simulée, journal, SQLite v8 réel via FFI). `sqlite_auth_test.dart` :
version attendue passée de 7 à 8.
