# Validation — étape 2
Date : 23 octobre 2026.
Environnement : Windows, Flutter 3.47.5 stable, Dart 3.13.4.

| Vérification | Résultat |
| --- | --- |
| flutter pub get | Réussi |
| dart format . | Réussi, 49 fichiers Dart traités |
| flutter analyze | Aucun problème détecté |
| flutter test | 36 tests réussis |
| Compilation Web release | Réussie via flutter run -d chrome --release --no-web-resources-cdn |
| Démarrage Chrome | Réussi |
| Contrôle dans le navigateur | Connexion admin, liste utilisateurs et session restaurée après rechargement |

La compilation finale produit build/web. Le contrôle visuel utilise les
ressources graphiques Flutter locales avec --no-web-resources-cdn.
La capture est dans docs/screenshots/admin-users.png.
Le moteur Flutter émet une notice de dépréciation de --pwa-strategy depuis son
outil de lancement ; aucun warning d’analyse n’est présent dans le projet.

## Couverture des tests
12 tests de modèle/repository : sérialisation sans mot de passe, dérivation salée,
login valide/invalide, logout, règles de création, doublons et validations hors UI,
persistance/relecture, modifications de profil, transitions administratives,
permissions du repository, échec d’écriture sans perte d’état et reprise
d’initialisation après réparation d’un stockage invalide.

24 tests d’interface : redirections sans session, login actif/en attente/bloqué,
masquage du mot de passe, validation du formulaire, inscription et doublon,
accès admin refusé au citoyen, filtres combinés/consultation/confirmation,
édition et logout, trois espaces professionnels, et onze routes générales
conservées sur un écran de 360 pixels.

## Limites de validation
Aucun SDK Android installé : APK et appareil Android non vérifiés.
iOS nécessite macOS/Xcode : compilation iOS non exécutée.
Le contrôle navigateur complète les tests de widgets ; il ne remplace pas
une recette sur téléphone. Aucun backend ou service externe n’est connecté.

