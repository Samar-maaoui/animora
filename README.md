# Animora
Application Flutter de protection, d’adoption et de bien-être des animaux.
Le projet conserve son architecture feature-first et sa charte Material 3 / Poppins.

Étape actuelle : [API REST externes — 9](API_INTEGRATIONS_REPORT.md).
Voir [les fichiers](FILES_9.md) et [la validation](VALIDATION_9.md). Les appels nécessitant des clés et les limites réseau sont explicités dans le rapport.
L’étape [SQFlite — 8B](SQLITE_STEP_8B.md) est conservée.
Voir [les fichiers de l’étape 8B](FILES_8B.md) et [sa validation](VALIDATION_8B.md).
L’infrastructure [SQFlite — 8A, Animaux et Adoptions](SQLITE_STEP_8A.md) est conservée.
Voir [les fichiers de l’étape 8A](FILES_8A.md) et [sa validation](VALIDATION_8A.md).
Les [événements et le bénévolat — 7](EVENTS_STEP_7.md) restent disponibles.
Voir [les fichiers de l’étape 7](FILES_7.md) et [sa validation](VALIDATION_7.md).
La [gestion des dons — 6](DONATIONS_STEP_6.md) reste disponible.
Voir [les fichiers de l’étape 6](FILES_6.md) et [sa validation](VALIDATION_6.md).
La [gestion vétérinaire et pet-sitting — 5](SERVICES_STEP_5.md) reste disponible.
Les [signalements et perdus / trouvés — 4](REPORTS_STEP_4.md) restent disponibles.
Les [adoptions et familles d’accueil — 3B](ADOPTION_STEP_3B.md) restent disponibles.
Voir [les fichiers de cette étape](FILES_3B.md) et [les vérifications](VALIDATION_3B.md).
Le catalogue et les favoris de [l’étape 3A](ADOPTION_STEP_3A.md) sont conservés.

## Lancer
Depuis ce dossier :
```powershell
flutter pub get
flutter run -d chrome --web-port=8765 --no-web-resources-cdn
```
Le port fixe facilite les tests de stockage Web. Le flag évite de charger le moteur
graphique Web depuis un CDN. Pour conserver les données entre des lancements Web,
utiliser le même profil de navigateur et la même origine (hôte et port) ;
Flutter peut lancer Chrome avec un profil temporaire. Un navigateur habituel peut
aussi ouvrir le serveur produit par :
```powershell
flutter run -d web-server --web-port=8765 --no-web-resources-cdn
```

Android : installer le SDK Android, démarrer un émulateur ou connecter un appareil,
puis exécuter `flutter run`. iOS : macOS et Xcode nécessaires.
L’identifiant de plateforme `com.example.animora` reste provisoire.

## Fonctionnalités actuelles
- Inscription validée, connexion et déconnexion.
- Session provider restaurée depuis le stockage local.
- Statuts Actif / En attente / Bloqué et contrôle des rôles.
- Consultation et modification du profil.
- Première gestion des utilisateurs réservée à l’administrateur.
- Catalogue avec photos, recherche, filtres et fiches détaillées.
- Favoris persistés et isolés par compte.
- Gestion des animaux réservée à ADMIN ; huit animaux de démonstration initiaux.
- Demandes, questionnaire, score explicable, décision et contrat simulé.
- Suivi post-adoption et hébergements en famille d’accueil.
- Signalements, confirmations, annonces perdu / trouvé et témoignages.
- Zones de recherche, correspondances explicables et réclamations privées.
- Modération humaine et histoires de retrouvailles.
- Annuaire vétérinaire, disponibilités, rendez-vous, soins, vaccinations et rappels internes.
- Pet-sitting : configuration, demandes, suivi privé avec photos et avis après une garde.
- Supervision administrative des rendez-vous et gardes.
- Dons : campagnes, contributions simulées, matériel, récurrences manuelles, reçus PDF non fiscaux et transparence.
- Événements : catalogue, inscriptions, attente, billets QR, bénévolat, pointage et bilans locaux.

## Architecture
- `lib/app/` : composition de l’application, go_router, thème centralisé.
- `lib/core/` : enums, constantes animales, validateurs et widgets partagés.
- `lib/features/auth/` : AuthRepository, implémentation locale, session,
  règles de compte, formulaires et comptes de développement.
- `lib/features/users/` : modèle unique User, affichage et édition du profil.
- `lib/features/admin/` : administration et liste filtrable des comptes.
- Autres features existantes conservées : home, adoption, reports, veterinary,
  pet_sitting, donations et events.

Depuis une feature : `context.watch<AuthSession>().currentUser` pour observer
le compte courant, ou `context.read<AuthSession>()` pour déclencher une action.
Les écrans passent par AuthSession ; seuls les repositories accèdent au stockage.
Le futur repository REST implémentera AuthRepository.

## Données de développement
Mot de passe commun : **Animora2026!**

| E-mail | Profil | Statut initial |
| --- | --- | --- |
| citizen@animora.test | Citoyen | Actif |
| veterinarian@animora.test | Vétérinaire | Actif |
| pet-sitter@animora.test | Pet-sitter | Actif |
| foster@animora.test | Famille d’accueil | Actif |
| pending@animora.test | Vétérinaire | En attente |
| admin@animora.test | Administrateur | Actif |
| blocked@animora.test | Citoyen | Bloqué |
| mohamed@animora.test | Citoyen | Actif (validé pour la récupération) |

Les sept fixtures historiques sont centralisées dans `features/auth/data/demo_accounts.dart`.
La récupération ajoute Mohamed selon le profil et le statut validés dans `demo_recovery.dart`.
Les comptes manquants sont préparés uniquement en debug avec une activation explicite :

```powershell
flutter run -d web-server --debug --web-hostname 0.0.0.0 --web-port 8080 --dart-define=ANIMORA_DEMO_SEED=true
```

Recharger chaque navigateur à son origine habituelle sans effacer ses données.
Les comptes, identifiants, mots de passe et statuts déjà présents sont conservés.
Les builds release/profile refusent le seed. Retirer l’option après préparation
ne supprime pas les comptes locaux. Voir `DEMO_ACCOUNTS_RECOVERY_REPORT.md`.

## Limites de cette étape
Aucun backend métier ni Firebase. Les enrichissements REST de l’étape 9 complètent les données locales ; ils ne remplacent pas les repositories métier. Les cartes utilisent les tuiles externes OpenStreetMap à la demande.
Le catalogue Animaux/Adoptions utilise SQFlite sur Android/iOS, avec conservation de SharedPreferences sur Web.
Les signalements, services, dons et événements utilisent la même base SQLite sur Android/iOS.
Sur Web, ces quatre gestions conservent Sembast/IndexedDB. Les anciennes sources natives restent conservées après import.
L’authentification Android/iOS utilise SQLite v7 (`users`, `auth_accounts`) et le stockage sécurisé natif pour les secrets/session.
Sur Web, l’authentification reste un document JSON SharedPreferences : utilisateurs, identifiant de session et
empreintes salées PBKDF2-HMAC-SHA256 (120 000 itérations, sel aléatoire de 16 octets).
Le modèle User ne contient aucun mot de passe ; les mots de passe saisis ne sont
pas persistés en clair. Le mot de passe des fixtures est public par conception.

Cette implémentation locale peut être altérée par le propriétaire de l’appareil
et ne constitue pas une authentification de production. Le futur serveur devra
assurer les autorisations et délivrer les sessions/tokens.
Les données locales ne sont pas synchronisées entre appareils ou instances ouvertes.
L’avatar utilisateur utilise les initiales et son édition photo reste à intégrer.
Le sélecteur d’image actuel concerne les animaux. Email et rôle ne sont pas
modifiables depuis le profil.

## Vérifier
```powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

Voir [AUTH_STEP.md](AUTH_STEP.md) pour le parcours manuel et les règles,
[FILES.md](FILES.md) pour les fichiers créés/modifiés,
et [VALIDATION.md](VALIDATION.md) pour les résultats.


## Module utilisateur : nouveautés

| Fonction | Service | Où |
|---|---|---|
| Écran d’accueil « Trouvez votre compagnon idéal » | — | `/welcome` (premier écran sans session) |
| Mot de passe oublié (code à 6 chiffres par e-mail, 10 min, 5 essais) | EmailJS (REST, gratuit) | lien sur l’écran de connexion |
| Vérification de l’e-mail à l’inscription (le compte n’est créé qu’après le code) | EmailJS | Inscription → « Créer mon compte » |
| Détection de la ville : GPS, sinon position approximative via la connexion | Nominatim + GeoJS (sans clé) | bouton ◎ du champ Ville |
| Photo de profil : exactement un visage | Google ML Kit Face Detection (hors ligne, Android/iOS) | Profil → photo |
| Avatar illustré pour les comptes sans photo | DiceBear (sans clé) | profil, liste admin |
| Autocomplétion de la ville (« Sou… » → Sousse) | Photon / OpenStreetMap (sans clé) | inscription, modifier le profil |
| Lecture du n° de carte professionnelle | Google ML Kit Text Recognition (hors ligne) | inscription vétérinaire, visible par l’admin |

### Configurer l’envoi d’e-mails (EmailJS)

1. Créez un compte sur https://www.emailjs.com, ajoutez un *Email Service* (Gmail…).
2. Créez un *Email Template* avec : destinataire `{{to_email}}`, objet `{{subject}}`, texte
   « Bonjour {{to_name}}, {{message}} Votre code : {{code}} (valable {{expires_minutes}} min). »
   Le même modèle sert à la **vérification de l’e-mail à l’inscription** et au **mot de passe oublié**
   (option : `EMAILJS_VERIFY_TEMPLATE_ID` pour un modèle dédié à l’inscription).
3. Dans *Account → Security*, activez « Allow EmailJS API for non-browser applications »
   et notez la clé privée.
4. Dans l’onglet *Settings* du template, champ **To Email** = `{{to_email}}`
   (sinon l’e-mail part vers votre propre adresse et l’utilisateur ne reçoit rien).
5. Remplissez `config/api-keys.json` (créé à partir de l’exemple, ignoré par git) :
   `EMAILJS_SERVICE_ID`, `EMAILJS_TEMPLATE_ID`, `EMAILJS_PUBLIC_KEY`, `EMAILJS_PRIVATE_KEY`.
6. Lancez depuis VS Code (configuration « Animora (clés config/api-keys.json) », déjà prête
   dans `.vscode/launch.json`) ou en ligne de commande :

```bash
flutter run --dart-define-from-file=config/api-keys.json
```

Sans ces clés, **aucun e-mail n’est envoyé** : en mode debug le code s’affiche dans l’application.

ML Kit ne fonctionne que sur Android/iOS (iOS ≥ 15.5) ; sur Web, la vérification
du visage est ignorée et le numéro de carte se saisit manuellement.
L’écran d’accueil utilise `assets/images/welcome_cat.png` (PNG détouré) s’il existe,
sinon la photo du chat embarquée.

### Pays et indicatif téléphonique (inscription)

REST Countries a fermé son API gratuite (v3.1) : la v5 exige une clé.
Sans `REST_COUNTRIES_KEY`, l’application utilise automatiquement **CountriesNow**
(`https://countriesnow.space/api/v0.1/countries/codes`, gratuit, sans clé).
Le drapeau est calculé à partir du code ISO. Avec une clé, REST Countries v5 reste utilisé.

## Administration et profil (dernières nouveautés)

- **Mot de passe** : 8 caractères minimum, au moins une majuscule, un chiffre et un symbole
  (critères cochés en direct à l’inscription, à la réinitialisation et au changement).
- **Confettis** 🎉 (package `confetti`, local) quand le compte est créé après la vérification de l’e-mail.
- **Carte de membre** (Profil → Ma carte de membre) : photo/avatar, nom, profil, date d’inscription,
  n° membre et QR code (QR Server `api.qrserver.com`, repli local hors ligne). Le QR ne contient ni e-mail ni téléphone.
- **Gestion utilisateurs** : statistiques cliquables (Total / Actif / En attente / Bloqué), recherche,
  filtres par profil, comptes en attente en tête, actions colorées Valider / Bloquer / Réactiver.
- **Journal de sécurité** (icône bouclier) : du plus récent au plus ancien, groupé par jour, heure à la seconde,
  nom de l’admin auteur et transition (`pending → active`). Filtres : Tout, Connexions, Alertes,
  Comptes & e-mails, Administration. Le verrouillage est journalisé dès le 5ᵉ échec.

## Carte de membre scannable, EmailJS vérifié, carte OSM (dernière étape)

### Carte de membre → page Web
- Le QR contient `MEMBER_CARD_BASE_URL#<données en base64url>` (page statique du dossier `web_card/`,
  à publier sur Netlify ou GitHub Pages : voir `web_card/README.md`).
- Données publiques uniquement : prénom, nom, profil, statut, n° membre, date d’inscription, ville,
  URL de l’avatar DiceBear. Jamais d’e-mail, de téléphone, d’identifiant interne, de photo ni de jeton.
- Le n° membre (`ANI-XXXXXXXX`) est une empreinte à sens unique de l’identifiant (FNV-1a).
- Avec URL configurée, le QR est dessiné **localement** (QR Server recevrait sinon les données).
  Sans URL, comportement précédent : QR Server + `ANIMORA|MEMBRE|ANI-…`.
- Profil → **Scanner une carte** (Android/iOS, `mobile_scanner`) affiche la même carte dans l’app.

### EmailJS
- Diagnostic sans envoyer d’e-mail : `dart run tool/check_emailjs.dart`.
- En debug, la console affiche `EMAILJS configuré : oui/NON` puis `EMAILJS HTTP <code> : <message>`
  (jamais les clés ni le code).

### Lancer sur un téléphone
```bash
flutter run -d SBXDU19428019842 --dart-define-from-file=config/api-keys.json --dart-define=ANIMORA_DEMO_SEED=true
```
"# animora" 
