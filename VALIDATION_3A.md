# Validation — étape 3A
9 novembre 2026.

- flutter pub get : réussi.
- dart format . : réussi, 74 fichiers Dart traités.
- flutter analyze : aucun problème détecté.
- flutter test : 59 tests réussis.
- flutter run -d chrome --release --no-web-resources-cdn --web-port=8765 :
  compilation release réussie et application démarrée.

## Tests
Les 36 tests préexistants ont été conservés, avec adaptation de leur montage
au nouveau provider de catalogue et de l’attente de chargement après connexion.

12 tests repository supplémentaires :
sérialisation du modèle, recherche, combinaison de tous les filtres et bornes
des groupes d’âge, favoris/doublons/date/retrait, isolation et restauration,
changement de compte pendant une opération, permissions, ajout/modification/
suppression admin et identifiants, nettoyage des favoris en cascade,
validation des champs, échec d’écriture atomique, stockage invalide.

11 tests d’interface supplémentaires :
catalogue/photos/recherche/fiche, filtres combinés/réinitialisation/état vide,
synchronisation des favoris, changement de compte, placeholder adoption et
fiche introuvable, trois routes admin refusées au citoyen, validation du
formulaire, modification/suppression confirmée et annulation, rendu à 320 pixels.

## Contrôle dans le navigateur
Vérifié sur la version release :
- Accueil avec logo officiel.
- Sélection d’une photo locale depuis le sélecteur de fichiers.
- Ajout de Pixel — test 3A en administrateur.
- Recherche de la nouvelle fiche.
- Ajout aux favoris.
- Photo et favori retrouvés après rechargement.

Captures : docs/screenshots/catalog-3a.png et favorites-3a.png.
Les photos de démonstration ont été contrôlées visuellement.

## Logo et authentification
Empreinte SHA-256 du PNG avant/après identique :
B5F45FACFFCC664D7BAD0A1552040ADB48C485F78F789D2A494528860A7D4A86

Les fichiers features/auth et le modèle User n’ont pas été modifiés.
Aucun backend ou nouveau workflow d’authentification ajouté.

## Limites
Pas de recette sur appareil Android/iOS ni de compilation native mobile.
Les quotas locaux, les profils de navigateur et les limites des photos sont
décrits dans ADOPTION_STEP_3A.md.
Le tool Flutter émet une notice de dépréciation interne de --pwa-strategy ;
l’analyse du projet ne présente aucun warning.

