# Animora — Étape 4

## Fonctionnalités

- Signalements : création, photo facultative, type, description, urgence 1–3, date, statut, recherche et filtres cumulables par type, statut et urgence.
- Détails avec carte facultative et confirmations indépendantes, une seule par utilisateur, jamais sur son propre signalement. Les confirmations ne modifient pas automatiquement le statut.
- Annonces perdu / trouvé : publication, recherche, catégories et statut, filtre « Mes annonces », modification et clôture par l’auteur.
- Témoignages avec photo, date / heure d’observation et position facultatives, affichés chronologiquement.
- Zone de recherche pour une annonce LOST active : centre approximatif, rayon de 1 à 20 km, cercle interactif ; modification par l’auteur.
- Correspondances entre annonces LOST et FOUND actives et visibles : photos, informations, score et comparaison détaillée. Recherche déclenchée volontairement.
- Réclamations privées : preuves textuelles, état PENDING, vérification / rejet humains par ADMIN. Même ADMIN ne peut décider sa propre réclamation.
- Validation d’une réclamation : clôture atomique de l’annonce FOUND, rejet des demandes concurrentes en attente. Une annonce LOST est aussi clôturée uniquement si elle appartient au demandeur et si sa correspondance a été confirmée humainement.
- Histoires de retrouvailles : publication volontaire après réclamation VERIFIED et annonce CLOSED, une seule histoire par annonce.
- Administration des signalements, annonces masquées, réclamations et correspondances ; accès contrôlé dans les routes et les repositories.
- Raccourcis depuis l’accueil et le module. Interfaces françaises, accent orange #F59E0B. Aucun changement de l’image officielle du logo.

## Architecture et stockage

Les huit modèles et les cinq abstractions demandées sont dans `lib/features/reports/`. `LocalReportsRepository` implémente ces abstractions ; `ReportsDatabase` sérialise les écritures, prépare une copie et ne publie les changements qu’après une écriture réussie. Une erreur de lecture ne réinitialise jamais silencieusement les données. `ReportsScope` conserve cette instance pendant la vie de l’application et utilise la session existante.

Les identifiants des entités sont des `int`. Les références utilisateur restent des `String`, conformément à l’unique modèle User déjà utilisé par l’authentification et les étapes 3A / 3B. Aucun second modèle User ni migration d’authentification n’a été créé.

Sembast conserve les métadonnées et les médias dans deux magasins distincts. Sur le Web, la base `animora_reports_v1` repose sur IndexedDB. Sur les plateformes natives, le fichier `animora_reports.db` se trouve dans le répertoire de support de l’application. Les photos de ce module ne passent pas par SharedPreferences.

Le sélecteur accepte une source jusqu’à 8 Mo, réencode en PNG sans métadonnées et sans agrandissement (largeur maximale 1200 px), puis limite le résultat à 2 Mo. Les fiches ne contiennent qu’une référence opaque au média. Une photo préparée mais non publiée peut rester orpheline dans cette version locale ; aucun nettoyage automatique destructif n’est exécuté.

## Confidentialité et règles

Le GPS n’est demandé qu’au clic. Refus, GPS désactivé et erreurs laissent les formulaires utilisables sans coordonnées. Une saisie manuelle ou une sélection sur la carte restent possibles.

Les positions publiées nécessitent un consentement explicite et sont arrondies à 0,01 degré, soit un ordre de grandeur d’un kilomètre (variable selon la latitude). La position précise n’est pas persistée par le module. Les fonds de carte ne chargent qu’après un second choix explicite informant de la transmission de la zone au fournisseur de tuiles.

Les preuves et l’éventuel code de réclamation restent accessibles uniquement au demandeur et à ADMIN. Le code facultatif n’est pas généré dans cette version : il ne constituerait pas une preuve réelle. Les listes publiques n’affichent ni preuves, ni contacts privés. Les écrans masquent leur ancien résultat pendant une recharge ou un changement de session.

Les contenus rejetés / masqués ne sont visibles que par leur auteur et ADMIN. L’auteur ne peut pas annuler un masquage en modifiant son annonce. Une annonce clôturée n’est plus modifiable et n’accepte plus de témoignage ni de nouvelle réclamation.

## Calcul des correspondances

Pondérations initiales : espèce 30, race 15, couleur 20, proximité 20, signes distinctifs 15. Elles sont injectables dans `AnimalMatchingService` ; les clés doivent être complètes, les valeurs finies et positives ou nulles, et leur somme égale à 100.

L’espèce est comparée après normalisation ; race, couleur et signes utilisent le recouvrement des mots. La proximité utilise une distance de Haversine et décroît linéairement jusqu’à zéro à 20 km. Une information absente apporte zéro. Le score est arrondi au dixième, entre 0 et 100 ; les nouveaux candidats apparaissent à partir de 40. Aucun traitement d’image ni IA.

Une décision REJECTED est conservée lors des recalculs. Une modification d’annonce annule une confirmation humaine antérieure de correspondance. Les annonces masquées ou clôturées sont exclues des correspondances affichées. Un score ou une correspondance confirmée ne valide aucune propriété.

## Carte

`flutter_map` utilise les tuiles standard `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, une attribution visible et cliquable, l’identifiant applicatif sur les requêtes natives et le cache intégré au package (cache navigateur sur Web). Aucun téléchargement hors ligne ni préchargement en masse. Une indisponibilité du fond est signalée sans empêcher l’usage des formulaires.

Respecter la [politique des tuiles OpenStreetMap](https://operations.osmfoundation.org/policies/tiles/) et prévoir un fournisseur adapté avant un déploiement à grande échelle. Aucun niveau de service cartographique n’est garanti.

Android déclare INTERNET, ACCESS_COARSE_LOCATION et ACCESS_FINE_LOCATION ; iOS contient NSLocationWhenInUseUsageDescription. Aucune permission de localisation en arrière-plan.

## Dépendances directes ajoutées

| Dépendance | Version résolue | Usage |
| --- | --- | --- |
| geolocator | 14.1.2 | GPS et permissions |
| flutter_map | 8.3.2 | Carte interactive |
| latlong2 | 0.10.1 | Coordonnées cartographiques |
| sembast | 3.10.1 | Persistance native |
| sembast_web | 2.4.6+2 | Persistance IndexedDB |
| path_provider | 2.1.6 | Répertoire applicatif |
| path | 1.9.1 | Chemins natifs |
| url_launcher | 6.3.3 | Lien d’attribution |

`image_picker`, Provider et go_router étaient déjà présents.

## Limites

Cette version reste une démonstration locale sur une installation ou une origine de navigateur donnée. Les comptes de cette installation voient les annonces publiques locales ; il n’y a ni backend, ni partage entre appareils, ni messagerie, ni notification à des services de secours. Les décisions ADMIN sont simulées localement et ne constituent pas une vérification de propriété officielle.

Les contrôles de confidentialité applicatifs ne chiffrent pas le stockage local. Le propriétaire de l’appareil, les outils développeur et un administrateur local peuvent accéder aux fichiers / à IndexedDB. Une version de production nécessite un backend avec autorisations serveur et une gestion adaptée des données privées.

Conserver la même origine (hôte et port) et le même profil navigateur pour retrouver les données Web. L’effacement du stockage du site, le mode privé ou les politiques de quota peuvent les supprimer. Les médias sont limités individuellement ; il n’y a pas de quota global ni de synchronisation.

Android / iOS n’ont pas pu être exécutés ici : SDK Android absent, aucun appareil connecté et iOS exige macOS / Xcode. Windows ne dispose pas de tous les composants C++ requis. Les configurations ont été ajoutées ; les permissions réelles doivent être validées sur ces plateformes. Le refus GPS et les erreurs sont couverts par des tests injectés, sans acquérir la position réelle de l’utilisateur.

## Scénario manuel

Comptes locaux existants : `citizen@animora.test`, `veterinarian@animora.test` et `admin@animora.test`. Mot de passe de démonstration commun : `Animora2026!`. Utiliser le profil vétérinaire comme second utilisateur actif ne démarre aucun module vétérinaire.

1. Se connecter comme citoyen. Ouvrir « Signalements » et créer un signalement avec une description de plus de 10 caractères et une urgence de 1 à 3. Refuser le GPS ; publier sans coordonnées. Vérifier les filtres et les détails.
2. Se connecter avec le second compte, ouvrir le même signalement et le confirmer. Vérifier que la seconde confirmation est impossible et que le compteur vaut 1. L’auteur ne peut pas confirmer sa propre publication.
3. Comme citoyen, créer une annonce LOST avec espèce, couleur, description et date. Définir une zone : centre fictif 36.80 / 10.18, consentement, rayon 3 km. Charger la carte, déplacer / zoomer et modifier le rayon.
4. Avec le second compte, créer une annonce FOUND similaire et ajouter une photo locale. Lancer « Rechercher des correspondances ». Examiner les deux fiches et le score.
5. Comme citoyen, déposer une réclamation de l’animal FOUND avec des preuves textuelles privées de plus de 20 caractères. Le publieur FOUND ne doit pas voir ces preuves ; un autre compte ordinaire non plus.
6. Comme ADMIN, ouvrir « Signalements et réclamations ». Examiner les preuves et, si justifié pour ce test fictif, confirmer la correspondance puis vérifier la réclamation. Contrôler la clôture, le rejet des demandes concurrentes et l’impossibilité de vérifier sa propre réclamation.
7. Comme citoyen, depuis « Mes réclamations », publier volontairement une histoire. Vérifier sa présence dans « Retrouvailles » et l’interdiction d’un doublon.
8. Recharger / fermer et rouvrir le navigateur sur la même origine. Vérifier les annonces, témoignages, zone, preuves autorisées, histoire et photo. Refaire le parcours à 360 px de large et sans connexion pour les états d’erreur du fond cartographique.

Voir [la validation](VALIDATION_4.md) et [la liste des fichiers](FILES_4.md).

