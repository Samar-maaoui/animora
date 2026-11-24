# Validation — étape 3B
9 novembre 2026.

| Vérification | Résultat |
| --- | --- |
| flutter pub get | Réussi |
| dart format . | Réussi, 103 fichiers Dart |
| flutter analyze | Aucun problème détecté |
| flutter test | 87 tests réussis |
| Compilation Web release | Réussie |
| Démarrage sur Chrome | Vérifié |

## Couverture
59 tests des étapes précédentes conservés, avec mise à jour des assertions qui
attendaient encore des placeholders et des attentes asynchrones de vues imbriquées.

19 nouveaux tests métier : création/questionnaire/motivation, score pondéré et
absence de décision automatique, doublons/annulation, isolation propriétaire,
refus, acceptation et concurrence, signature du seul adoptant, suivi privé,
rollback d’écriture, affectation et interdiction de chevauchement, accès famille,
annulation avec situation de sortie, conversion, réservation préservée à la fin
d’un accueil, protection du CRUD animal, relecture persistée, migration 3A et
changement d’identité pendant une opération en attente.

9 nouveaux tests d’interface : questionnaire complet, confirmation de décision,
contrat, suivi, URLs privées, affectation et conversion côté famille, quatre
routes interdites au citoyen, affichage étroit à 320 pixels.

Les données de tests sont isolées en mémoire ; les données utilisateur existantes
ne sont pas réinitialisées.

## Vérification réelle sur Web
Le parcours de démonstration a été exécuté dans le navigateur :
questionnaire pour Max, score expliqué 70,3 %, récapitulatif, création PENDING,
confirmation administrateur, contrat non signé, confirmation et signature
simulée, adoption effective puis publication de nouvelles.
Les nouvelles ont été retrouvées après rechargement.

Captures :
- docs/screenshots/compatibility-3b.png
- docs/screenshots/follow-up-3b.png

## Logo et non-régression
SHA-256 du PNG original inchangé avant/après :
B5F45FACFFCC664D7BAD0A1552040ADB48C485F78F789D2A494528860A7D4A86

Le module auth, le modèle User, le thème central et le logo n’ont pas été modifiés.
La composition ajoute les repositories de workflow et la localisation française.
Les tests de connexion, de catalogue et de favoris passent.

## Limites
Pas de compilation ni recette sur appareil Android/iOS.
La concurrence testée est celle de la même instance locale.
Les limites de persistance et les règles retenues sont dans ADOPTION_STEP_3B.md.
La notice de dépréciation --pwa-strategy provient de l’outil Flutter ;
aucun warning d’analyse du projet n’est présent.

