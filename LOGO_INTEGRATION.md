# Intégration du logo officiel — 9 novembre 2026

Le fichier original n’est pas encore présent dans le projet et aucune image
officielle n’était jointe à cette demande.

## Fichier attendu

`assets/images/animora_logo.png`

Déposer le PNG original à cet emplacement, sans le modifier. Le dossier
`assets/images/` est déclaré dans pubspec.yaml et inclura automatiquement
ce fichier après un redémarrage complet de l’application.

## Intégration réalisée

- AnimoraLogo utilise directement Image.asset et BoxFit.contain.
- Aucune recoloration, découpe, opacité, transformation ou image générée.
- Le header partagé réserve 184 pixels en hauteur, avec une zone image de 168
  pixels. La largeur est contrainte par l’écran ; les proportions sont conservées.
- Splash utilise une zone de 280 pixels en hauteur et reste défilable.
- Accueil, connexion, inscription et écrans de statut utilisent le même asset.
- Les anciennes pattes de marque et les titres de marque remplacés sont retirés.
- Les icônes fonctionnelles des animaux et de la navigation sont conservées.
- Aucun modèle, repository ou traitement d’authentification n’est modifié.

En l’absence du fichier, un message « Logo officiel à ajouter » occupe sa zone.
Aucun substitut graphique n’a été créé.

## Vérifications exécutées

- flutter pub get : réussi.
- flutter analyze : aucun problème détecté.
- flutter test : 36 tests réussis, sans overflow signalé.
- Le helper des tests laisse maintenant les champs se stabiliser avant de
  défiler vers un bouton dans le header plus haut ; la logique applicative
  d’authentification est inchangée.

Ces résultats portent sur l’intégration et le layout sans l’image manquante.

## À vérifier après ajout de l’original

Relancer :
```powershell
flutter pub get
flutter run -d chrome --no-web-resources-cdn
```

Contrôler sur écran étroit et large : chien, chat, nom, cœurs, décorations et
sous-titre entièrement visibles. La lisibilité et l’identité visuelle exacte
ne peuvent pas être confirmées avant de disposer de l’image originale.
