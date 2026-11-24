# Animora — étape 3A
Catalogue, fiches, filtres, favoris et administration des animaux.

## Réalisé
- Modèle Animal existant conservé et étendu : id int, âge int en années, poids double,
  attributs du diagramme, sérialisation JSON et copyWith.
- Enum AnimalStatus et libellés français conservés.
- Huit animaux fictifs initialisés une seule fois, avec photos embarquées.
- Recherche par nom sans distinction de casse et filtres combinables : espèce,
  race, groupe d’âge, ville et statut. Réinitialisation complète et état vide.
- Fiches détaillées avec photo, toutes les caractéristiques, date d’arrivée
  et numéro de puce.
- Favoris avec userId, animalId et addedAt ; pas de doublon. État synchronisé
  entre accueil, catalogue, fiche et liste des favoris.
- Favorites strictement associés à la session active, y compris si le compte
  change pendant une opération en attente.
- Administration : consultation, ajout avec photo, modification et changement
  de statut. Suppression confirmée, avec nettoyage des favoris associés.
- Accueil alimenté par le repository et limité aux trois premiers animaux disponibles.
- Layout de cartes adaptatif ; catalogue et fiche testés à 320 pixels.
- Logo original conservé byte pour byte. Aucun traitement d’authentification modifié.

Le bouton Demander une adoption n’apparaît que pour AVAILABLE et ouvre
un placeholder étape 3B. Aucun questionnaire, demande persistée, contrat ni
workflow d’adoption n’a été développé.

## Architecture
Les nouvelles classes restent dans features/adoption et features/admin.

AnimalRepository propose getAllAnimals, getAnimalById, searchAnimals,
addAnimal, updateAnimal et deleteAnimal. FavoriteRepository propose les opérations
du compte connecté, sans identifiant arbitraire fourni par l’UI.

Les implémentations locales partagent LocalCatalogDatabase :
un seul snapshot JSON permet une suppression atomique d’un animal et de ses
favoris. Les écritures sont sérialisées. Une erreur de sauvegarde laisse les
données précédentes intactes ; une base invalide n’est pas réinitialisée silencieusement.

AdoptionScope crée les repositories et AdoptionStore une seule fois dans
l’arbre de l’application. Le store observe la session existante via provider ;
l’authentification n’a pas été remplacée. Les écrans ne lisent plus directement
DemoData. Cette classe sert uniquement de données initiales au repository local.

## Routes
- /animals
- /animals/:id
- /animals/:id/adoption : placeholder 3B
- /favorites
- /admin/animals
- /admin/animals/new
- /admin/animals/:id/edit

Les routes admin utilisent le garde existant de go_router. Les mutations sont
aussi contrôlées dans le repository : compte administrateur actif requis.
Les lectures et favoris nécessitent un compte actif.

## Persistance locale et photos
SharedPreferencesAsync existant conserve la clé animora.adoption.v1,
distincte de la base des utilisateurs. La navigation ne recrée pas les données.

Les photos initiales sont des assets locaux. Les photos choisies sont lues
comme octets via image_picker, vérifiées par le décodeur Flutter puis conservées
dans animalPhoto sous forme data:image/...;base64. Aucun XFile.path, chemin Windows,
chemin Android ou URL blob temporaire n’est persisté.

Formats : PNG, JPEG, GIF, WebP. Limite : 1 000 000 octets par photo choisie,
4096 pixels par dimension après lecture ; le sélecteur demande une réduction
à 1200 × 1200 et une qualité de 80 lorsque la plateforme le permet.
La limite de taille reste appliquée si le navigateur ne réduit pas l’image.

La base complète est limitée à 3 500 000 octets de JSON pour cette démonstration.
Une photo en base64 prend davantage de place que le fichier d’origine.
En cas de quota dépassé, l’UI indique de réduire les photos ou supprimer un animal.
Une base vide est un état valide : supprimer tous les animaux ne réinjecte pas les fixtures.

Ce stockage est temporaire, propre à un appareil/profil navigateur et à son origine.
Il n’est pas synchronisé entre appareils ni entre instances déjà ouvertes.
Sur Web, conserver le même hôte, port et profil de navigateur. Flutter peut ouvrir
Chrome avec un profil de test temporaire. Effacer les données de l’application ou
du site supprime cette base locale.

Sans backend, les contrôles locaux ne sont pas une barrière de sécurité de
production. Les futurs repositories REST devront appliquer les autorisations
côté serveur et externaliser les photos vers un stockage adapté.
Les identifiants locaux sont des entiers croissants, limités à la précision
entière JSON sûre sur Web (moins de 2^53). Ils ne sont pas réutilisés après suppression.

## Dépendance ajoutée
image_picker: ^1.2.4 (Android et Web, ainsi que les autres plateformes prises
en charge par le plugin). Provider, shared_preferences et go_router existaient déjà.

Seule la galerie est utilisée, pas la caméra.
La description d’accès à la photothèque est déclarée dans ios/Runner/Info.plist.
La sélection sur appareil Android/iOS reste à vérifier ; le formulaire n’est pas
restauré si le système détruit l’application pendant le choix d’image.

## Lancer
Depuis le dossier animora :
```powershell
flutter pub get
flutter run -d chrome --release --no-web-resources-cdn --web-port=8765
```

Pour tester avec le profil habituel d’un navigateur :
```powershell
flutter run -d web-server --no-web-resources-cdn --web-port=8765
```

Utiliser les comptes de développement existants :
citizen@animora.test et admin@animora.test, mot de passe Animora2026!.

## Scénario de test manuel
1. Se connecter comme citoyen, ouvrir Animaux et rechercher Luna.
2. Combiner Chat + Européen + 2 à 7 ans + Tunis + À adopter.
   Changer un filtre pour obtenir l’état vide, puis réinitialiser.
3. Ouvrir une fiche, contrôler ses informations et ajouter le favori.
   Vérifier le cœur dans le catalogue et la présence dans Favoris.
4. Recharger la page dans le même navigateur : le favori doit subsister.
   Le retirer et vérifier les autres écrans.
5. Se déconnecter et ouvrir un autre compte : ses favoris doivent être distincts.
6. Ouvrir directement /admin/animals, /admin/animals/new et /admin/animals/1/edit
   comme citoyen : accès refusé.
7. Se connecter comme administrateur, Accueil → Administration → Gestion des animaux.
8. Ajouter un animal avec une petite photo locale ; remplir les champs,
   enregistrer, puis retrouver sa fiche par recherche.
9. Modifier sa ville, son état de santé et son statut ; vérifier le catalogue.
10. Supprimer l’animal : annuler une première fois, puis confirmer.
    Ses favoris doivent disparaître ; son ancienne URL affiche Animal introuvable.
11. Sur une fiche AVAILABLE, ouvrir Demander une adoption : seul le placeholder
    3B apparaît. Pour un autre statut, le bouton est absent.

## Validation
Voir VALIDATION_3A.md et FILES_3A.md.

Le contrôle navigateur a ajouté Pixel — test 3A avec une photo locale, puis
l’a mis en favori sur le compte admin de développement. Cet enregistrement
reste dans le profil de navigateur utilisé pour la vérification ; il ne fait
pas partie des huit fixtures initiales.

