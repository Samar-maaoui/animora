# Animora — Validation de l’étape 6

## Vérifications automatisées

- Avant intervention : flutter analyze sans erreur, 162 tests réussis.
- flutter pub get : réussi après ajout des dépendances PDF.
- dart format . : exécuté.
- flutter analyze : No issues found.
- flutter test : 206 tests réussis, aucun désactivé ni supprimé.
- Nouveaux tests : 29 tests de repository, 13 tests d’interface, 2 tests PDF (44 au total).
- flutter build web --no-web-resources-cdn : réussi.

Les 162 tests existants restent réussis. La couverture nouvelle vérifie les campagnes, montants exacts en millimes, statuts, dons matériels et besoins calculés, doubles confirmations, droits et isolation des utilisateurs, plans récurrents manuels, reçus privés, rapports figés, rechargement, rollback après erreur d’écriture et routes ADMIN. Les tests d’interface couvrent aussi les formulaires et une largeur de 360 px.

## Parcours Web réellement exécuté

Sur localhost:8765 avec un compte ADMIN fictif : création d’un brouillon, publication après confirmation, consultation, contribution simulée de 20,125 TND, historique et reçu. Le bouton PDF a réellement téléchargé DEMO-RECU-000003.pdf. Après rechargement de la même origine, l’historique a conservé le don et le catalogue a affiché exactement 20,125 TND sur un objectif de 100 TND.

Une anomalie d’accessibilité Web fusionnait les boutons des cartes avec la barre de progression. Les cartes du module et la sémantique des progressions ont été corrigées ; les boutons sont désormais accessibles séparément. La suite complète et le build ont été relancés après correction.

Capture : [campagne de démonstration](docs/screenshots/step6-donations.jpg).

## PDF

L’exemple financier A4 d’une page et un reçu matériel long de six pages ont été rendus avec Poppler. Toutes les pages ont été inspectées : logo complet, caractères français lisibles, contenu sans découpe et mentions de démonstration / non-fiscalité. L’extraction normalisée du texte confirme la mention et le montant, ainsi que la mention sur les six pages du document long. Les polices et le logo proviennent des assets locaux.

## Préservation et limites

Le logo officiel est inchangé (SHA-256 B5F45FACFFCC664D7BAD0A1552040ADB48C485F78F789D2A494528860A7D4A86). Les fichiers des modèles User, Animal et de la logique d’authentification ne sont pas modifiés. Le stockage Sembast existant est réutilisé dans un espace dons distinct.

Les données restent locales : même navigateur, profil et origine nécessaires sur Web ; pas de synchronisation ni d’autorisation serveur, stockage non chiffré et données effaçables par le navigateur. Les dons et récurrences sont simulés, sans paiement réel ni tâche de fond. Le partage natif et le cycle de vie Android/iOS nécessitent encore une validation sur appareil ; la réussite des tests à 360 px ne remplace pas cette vérification.

Le module Événements n’a pas été commencé. Le scénario manuel complet et les règles figurent dans [DONATIONS_STEP_6.md](DONATIONS_STEP_6.md).
