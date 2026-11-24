# Animora — inscription Web / Safari iOS

## Diagnostic et résultat

Le chargement initial est désormais fonctionnel selon le retour utilisateur. Le nouvel échec survient après soumission du formulaire. Aucun journal du téléphone ni code d’exception n’est disponible ici : **la cause exacte sur l’iPhone reste à confirmer**, et aucune corruption de base n’est supposée.

Le message « Une erreur est survenue. Veuillez réessayer. » provient du repli `authErrorMessage` lorsqu’une exception autre que `AuthFailure` arrive à `AuthForm._submit`. Le parcours est `RegisterScreen` → `AuthForm` → `AuthSession.register/_perform` → `LocalAuthRepository.register` → `PasswordHasher` → `PreferencesAuthStorage`. Il n’existe pas de classe AuthService distincte : AuthSession assure la coordination.

Défaut confirmé dans le code précédent : **`Random.secure()` pour l’identifiant utilisateur était exécuté hors de la gestion d’erreurs cryptographiques**, avant le hachage et l’écriture. Une erreur à cet endroit atteignait directement le message générique. Cette panne est maintenant reproduite par injection en test, classifiée et vérifiée sans écriture ; un réessai réussi utilise toujours un générateur cryptographique. Cela ne prouve pas qu’elle s’est produite sur l’iPhone.

La validation du formulaire et celle du repository, l’unicité e-mail, les statuts/profils autorisés, la confirmation de mot de passe et l’absence de connexion automatique à l’inscription sont conservés. Aucun compte fictif ajouté.

## Cryptographie / HTTP

`PasswordHasher` est inchangé : PBKDF2-HMAC-SHA256, **120 000 itérations**, sel aléatoire 16 octets, empreinte 32 octets. Les empreintes existantes restent compatibles. Les tests métier utilisent parfois 10 000 itérations pour leur durée ; la sonde Chrome utilise les paramètres de production.

La dépendance verrouillée `cryptography` 2.9.0 teste la présence de `crypto.subtle` et le contexte sécurisé avant de sélectionner WebCrypto ; sinon elle sélectionne son implémentation Dart du même PBKDF2. Le SDK Dart utilise `crypto.getRandomValues` pour Random.secure sur Web. Cette API peut fonctionner sur HTTP, contrairement à SubtleCrypto. Voir les documentations [getRandomValues](https://developer.mozilla.org/en-US/docs/Web/API/Crypto/getRandomValues) et [SubtleCrypto](https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto).

**Confirmation réelle Chrome sur IP HTTP :** `secure_context=false`, `webcrypto=false`, `secure_random=true`, stockage lisible, inscription et connexion réussies. L’absence de HTTPS n’est donc pas une cause universelle du défaut. Aucune désactivation du hachage, aucun remplacement par Random(), aucun mot de passe en clair et aucune diminution du coût cryptographique.

Si le navigateur ne fournit réellement plus de source aléatoire cryptographique ou échoue pendant PBKDF2, l’opération est refusée avec un diagnostic. Aucun repli faible n’est introduit.

## Corrections et fichiers

| Fichier | Changement |
| --- | --- |
| `lib/features/auth/repositories/local_auth_repository.dart` | Génération d’ID protégée et testable ; erreurs inconnues encadrées ; encodage JSON séparé de l’écriture ; codes validation, doublon, identifiants et cryptographie. |
| `lib/features/auth/models/auth_requests.dart` | Catégories cryptographie indisponible, hachage, sérialisation et erreur inconnue. |
| `lib/features/auth/services/auth_diagnostics.dart` | Nouveau constructeur de diagnostics sans données sensibles ; une erreur du diagnostic lui-même ne masque pas l’échec initial. |
| `lib/features/auth/services/auth_environment_web.dart` | Lecture protégée de chaque indicateur ; ajout de la disponibilité du générateur sécurisé. |
| `lib/features/auth/services/local_auth_storage.dart` | Différenciation lecture préférences, enveloppe JSON, validation avant écriture et écriture préférences. Données invalides conservées. |
| `lib/features/auth/widgets/auth_form.dart` | Diagnostic même pour exception inattendue ; effacement du diagnostic périmé lors d’un nouvel essai ou changement de profil. |
| `test/auth_registration_failures_test.dart` | 7 nouveaux tests et scénarios d’échec/réessai. |
| `tool/auth_registration_web_probe.dart` | Sonde séparée, non importée par l’application, pour essais réels Chrome sans le runner Flutter défectueux. Refuse une origine contenant déjà des comptes. |

Le stockage Web reste SharedPreferences, avec l’adaptateur de l’étape 10C. Aucun effacement de SharedPreferences/IndexedDB, aucune modification de SQLite v7, des six modules, des six API ou du logo. SHA-256 du logo inchangé : `B5F45FACFFCC664D7BAD0A1552040ADB48C485F78F789D2A494528860A7D4A86`.

## Codes à relever sur l’iPhone

| Code | Étape / signification |
| --- | --- |
| `AUTH_VALIDATION` | Champ rejeté ; correction indiquée dans le formulaire. |
| `AUTH_DUPLICATE_EMAIL` | E-mail déjà utilisé ; aucune écriture. |
| `AUTH_CREDENTIALS` | Identifiants de connexion non reconnus ; ne révèle pas l’existence d’un e-mail. |
| `AUTH_RANDOM_UNAVAILABLE` | Génération cryptographique de l’ID impossible, avant hachage/écriture. |
| `AUTH_CRYPTO_UNAVAILABLE` | Primitive cryptographique déclarée non prise en charge pendant le hachage/vérification. |
| `AUTH_KDF` | Autre erreur pendant le hachage ou la vérification. |
| `AUTH_PREFERENCES_READ` / `AUTH_PREFERENCES_WRITE` | Lecture ou écriture refusée/indisponible. |
| `AUTH_JSON_ENVELOPE` / `AUTH_JSON_VALIDATE_WRITE` / `AUTH_JSON_ENCODE` | Enveloppe, validation du document ou préparation JSON. |
| `AUTH_DECODE_VALIDATE` | Document chargé incompatible ; source conservée. |
| `AUTH_UNKNOWN` | Exception non classifiée, type technique et indicateurs sûrs seulement. |

Les diagnostics contiennent uniquement le code, le type d’exception et des indicateurs booléens de capacités. Aucun message brut d’exception, mot de passe, e-mail, empreinte, sel, contenu JSON ou jeton/session n’est journalisé. Le bouton de soumission est réactivé après échec grâce au `finally` existant dans AuthSession.

## Validation réellement exécutée

| Vérification | Résultat |
| --- | --- |
| `flutter analyze` final | **No issues found!**, 6,2 s — `../../work/registration-analyze-final.log`. |
| `flutter test --reporter expanded` | **370 réussis, aucun échec**, 1 min 18 s — `../../work/registration-tests.log`. Les 363 tests précédents sont conservés. |
| Nouveaux cas | Inscription valide ; réouverture du repository/session et connexion ; doublon normalisé ; champs invalides ; générateur sécurisé indisponible et réessai ; échec de hachage et réessai ; primitive indisponible et réessai ; erreur d’écriture préservant un compte existant et réessai du même e-mail. Répartis sur 7 tests. |
| `flutter build web` | **Réussi**, 87,1 s — `../../work/registration-build.log`. |
| Build sonde séparée | **Réussi**, 41 s — `../../work/registration-probe-build-final.log`. Une erreur de constructeur DOM dans la première version de la sonde a été corrigée ; elle n’est pas un échec de l’application. |
| Chrome `http://localhost:8097` | **8 contrôles réussis**, `secure_context=true`, `webcrypto=true`. `../../work/registration-chrome-localhost.log`. |
| Chrome `http://192.168.1.2:8097` | **8 contrôles réussis**, `secure_context=false`, `webcrypto=false`, PBKDF2 Dart. `../../work/registration-chrome-http-ip.log`. |
| Safari iOS HTTP / HTTPS | **Non exécuté ici** ; nécessite l’iPhone. |

Les 8 contrôles de chaque essai Chrome couvrent : démarrage neuf, ID cryptographique, absence de connexion automatique, absence de mot de passe en clair dans le document, doublon rejeté, document préservé après doublon, restauration avec un nouveau repository puis connexion, mauvais mot de passe rejeté. Les 16 contrôles navigateur sont distincts des 370 tests VM et ne sont pas présentés comme une exécution de la suite Flutter Chrome bloquée à l’étape 10C. Une fermeture/réouverture réelle du navigateur et les interactions du formulaire iPhone restent à vérifier manuellement.

Ces essais utilisent Chrome headless avec deux profils temporaires isolés, créés uniquement pour la sonde, et le vrai stockage navigateur. Aucun profil personnel ni origine `:8080` n’a été automatisé. Le serveur temporaire de la sonde est arrêté après les essais. Scripts reproductibles dans `../../work/registration-chrome-probe.ps1` et `registration-static-server.cjs`.

## Test sur votre iPhone

1. Redémarrer votre serveur de développement pour charger le nouveau code, sans supprimer les données du site :

   ~~~powershell
   flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
   ~~~

2. Sur le même réseau, ouvrir et recharger **`http://192.168.1.2:8080`**, en Safari normal. Ne pas effacer les données Safari. Essayer l’inscription Citoyen avec un e-mail de test inédit et un mot de passe conforme.
3. Si elle réussit : vérifier le retour à connexion, se connecter, recharger, puis fermer/rouvrir Safari à la même adresse. Vérifier la session et le compte. Tester ensuite un mauvais mot de passe et l’inscription avec le même e-mail : les deux doivent être rejetés clairement.
4. Si elle échoue : transmettre seulement le code `AUTH_...`, le type d’exception, les indicateurs affichés, la version iOS et le mode normal/privé. Ne transmettre aucun mot de passe ni contenu du stockage. Le code permettra de distinguer le générateur, PBKDF2, le stockage et un défaut inconnu.
5. Pour l’ancien compte de démonstration : sa présence sur le PC ne garantit pas sa présence dans Safari. Vérifier la même origine, le même mode et le bon mot de passe. Les comptes de démonstration ne sont plus créés automatiquement sur une installation neuve depuis 10C. Aucun compte absent n’est recréé pour masquer le problème.

## HTTPS local, si nécessaire

HTTPS est recommandé pour tester un contexte sécurisé et protéger le code et les données en transit. Il ne faut pas déduire du succès Chrome HTTP que tous les Safari se comportent identiquement. Aucune installation de certificat ou d’outil n’a été faite ici.

Procédure possible avec [mkcert officiel](https://github.com/FiloSottile/mkcert), à réaliser volontairement sur le PC de développement : installer mkcert selon sa documentation, puis créer une autorité locale et un certificat couvrant exactement l’IP LAN utilisée. Conserver les clés privées hors du dépôt.

~~~powershell
mkcert -install
mkcert -cert-file C:/AnimoraTLS/animora.pem -key-file C:/AnimoraTLS/animora-key.pem 192.168.1.2 localhost 127.0.0.1
mkcert -CAROOT
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8443 --web-tls-cert-path C:/AnimoraTLS/animora.pem --web-tls-cert-key-path C:/AnimoraTLS/animora-key.pem
~~~

Créer le dossier privé `C:/AnimoraTLS` au préalable. Les deux options TLS sont vérifiées dans le SDK Flutter installé. Sur l’iPhone, installer uniquement le certificat public `rootCA.pem` de votre propre autorité, puis activer sa confiance SSL dans Réglages → Général → Informations → Réglages des certificats, selon la [procédure Apple](https://support.apple.com/en-us/102390). Ne jamais transférer `rootCA-key.pem` ou une clé privée. Ouvrir ensuite `https://192.168.1.2:8443` sans ignorer d’avertissement de certificat. Si l’IP change, générer un certificat approprié.

**Cette URL HTTPS est une autre origine** : ses comptes sont distincts de ceux de `http://192.168.1.2:8080`. Utiliser un nouveau compte de test HTTPS ; l’absence de l’ancien compte HTTP à cette adresse n’est pas une suppression. Aucune migration inter-origines ou réinitialisation automatique n’est effectuée.

## Limite restante

Le défaut de traitement d’exception est corrigé et l’inscription complète est validée dans deux contextes Chrome réels. La panne spécifique Safari ne peut pas être déclarée corrigée sans le nouveau diagnostic ou un essai réussi sur le téléphone. Aucune installation Android SDK ni modification UI/UX hors messages d’erreur n’a été engagée.
