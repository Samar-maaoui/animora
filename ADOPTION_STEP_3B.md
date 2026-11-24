# Animora — étape 3B : adoptions et familles d’accueil

## Périmètre
Demandes d’adoption, questionnaire, score explicable, décision administrateur,
contrat avec signature simulée, suivi post-adoption, hébergements et conversion
d’un hébergement vers une demande d’adoption.

Aucun backend, IA, prestataire de signature ni module Signalements ajouté.
Le catalogue, les favoris, les modèles User/Animal, l’authentification et le logo
officiel sont conservés.

## Modèles et identifiants
Les classes demandées sont présentes :
Adoption, QuestionnaireAdoptant, ContratAdoption, SuiviAdoption, Hebergement.
Les noms français spécifiés pour ces classes métier ont été conservés ; les
méthodes et variables sont en anglais. Aucune classe AdoptionApplication ni
profil utilisateur spécialisé n’a été créé.

AdoptionStatus : PENDING, ACCEPTED, REJECTED, CANCELLED.
HebergementStatus : ACTIVE, COMPLETED, CANCELLED.
Les libellés d’interface sont en français.

Les identifiants des nouvelles entités et des animaux sont int. Les références
userId et fosterFamilyUserId restent String, car User.id existant utilise des UUID
et des identifiants de démonstration tels que demo-citizen. Les convertir en Long
casserait les comptes, sessions et favoris existants. Le futur mapping REST devra
aligner ce point avec le contrat d’identifiants du backend.

Un instantané du modèle User sans identifiants secrets est enregistré lors de la
demande : il sert aux informations historiques de l’adoptant affichées dans la
demande et le contrat. Ces informations ne sont pas automatiquement réécrites
après une modification ultérieure du profil.

## Architecture et persistance
Les abstractions suivantes sont disponibles :
- AdoptionRepository
- QuestionnaireRepository
- AdoptionContractRepository
- AdoptionFollowUpRepository
- FosterPlacementRepository
- AdoptionCompatibilityService

LocalAdoptionWorkflowRepository implémente ces contrats. Les écrans passent par
AdoptionWorkflowStore et les abstractions ; un futur repository REST pourra les
remplacer.

Les workflows sont intégrés au snapshot existant de LocalCatalogDatabase.
Une transaction locale contient donc à la fois les objets métier et le nouveau
statut de l’animal. Les mutations sont sérialisées et ne sont publiées qu’après
une sauvegarde réussie. Une erreur d’écriture ne laisse pas de contrat ou statut
d’animal partiellement appliqué.

Les anciens snapshots 3A sans clé workflow sont lus sans supprimer les animaux
ni les favoris. Aucune réinitialisation n’a lieu à la navigation.

## Demandes et questionnaire
Conditions : compte connecté actif, animal AVAILABLE et absence d’une demande
PENDING ou ACCEPTED en double pour le même compte et animal.

Le questionnaire comporte trois étapes :
1. Réponses obligatoires : logement, enfants, autres animaux, expérience et temps.
2. Score expliqué et motivation d’au moins 20 caractères.
3. Récapitulatif et confirmation explicite de la demande.

Les réponses et le score recalculé dans le repository sont enregistrés avec
l’Adoption PENDING en une seule transaction. Le client ne fournit pas un score
arbitraire au repository. Le bouton de la fiche indique si une demande du compte
existe déjà ; le repository vérifie aussi les doublons et la disponibilité.

Les utilisateurs consultent leurs demandes, leurs questionnaires et leurs
contrats. Ils peuvent annuler uniquement leurs propres demandes PENDING.
Une annulation ou un refus ne crée aucun contrat.

## Score de démonstration
Les règles sont centralisées dans AdoptionCompatibilityService :
- Logement : 20 points.
- Enfants : 15 points.
- Autres animaux : 20 points.
- Expérience : 20 points.
- Temps : 25 points.

Les pondérations sont configurables et doivent totaliser 100.
Le calcul tient notamment compte de l’espèce, du poids et de mots décrivant le
caractère de l’animal. Les contributions sont détaillées et le score est borné
entre 0 et 100, arrondi à une décimale.

Il ne s’agit pas d’une évaluation scientifique ou vétérinaire. Aucun seuil ne
refuse ou n’accepte automatiquement une demande. La décision reste administrateur.

## Décision, contrat et adoption effective
L’administrateur consulte toutes les demandes, filtre leur statut et lit
l’animal, les coordonnées historiques du demandeur, sa motivation, son
questionnaire et son score.

Avant chaque décision, une confirmation explique ses conséquences.
Accepter une demande :
- Enregistre decisionDate et ACCEPTED.
- Crée un unique contrat non signé.
- Passe l’animal à PENDING_ADOPTION.
- Refuse les autres demandes encore PENDING pour cet animal, avec decisionDate.

Le refus automatique des demandes concurrentes est une règle de cohérence liée
à la réservation ; il ne dépend pas de leur score.
Deux décisions concurrentes dans la même instance ne peuvent accepter deux
demandes pour un même animal.

Le contrat affiche les parties, l’animal, la décision, les conditions et les
engagements. Seul le propriétaire de la demande peut cocher la confirmation et
valider la signature, avec une deuxième boîte de confirmation.
Cette signature est explicitement simulée et aucune valeur juridique n’est
revendiquée.

La signature enregistre signed, signatureDate, adoptionDate, passe l’animal à
ADOPTED et clôture son éventuel hébergement actif dans la même transaction.
Une nouvelle signature ou une signature par un autre utilisateur est refusée.
Un administrateur peut signer uniquement lorsqu’il est lui-même l’adoptant.

## Suivi post-adoption
Disponible uniquement après adoption effective et contrat signé.
L’adoptant consulte l’historique et ajoute des nouvelles d’au moins 10 caractères,
un type de suivi et éventuellement une photo. Les images utilisent le sélecteur
existant et des données image portables.

L’administrateur peut lire les suivis. Il ne peut pas publier au nom d’un autre
adoptant. Les autres utilisateurs ne peuvent pas consulter ces données, y compris
par URL directe.

## Familles d’accueil
Seul UserProfile.fosterFamily représente une famille.
La famille voit les animaux disponibles, ses hébergements et leurs détails.
Elle peut ajouter des remarques à un accueil actif et le terminer.

L’administrateur affecte un animal AVAILABLE à une famille active, avec une date
de début non future. Une famille inactive, un animal déjà réservé ou un second
hébergement actif pour le même animal sont refusés.

À la création : Hebergement ACTIVE et animal FOSTERED.
Les dates sont enregistrées en UTC et affichées en français.
Les remarques sont ajoutées à l’historique avec une date.

L’administrateur peut terminer ou annuler un accueil. Pour un accueil sans
réservation, il choisit la situation de sortie : AVAILABLE, LOST ou FOUND.
La famille qui termine son propre accueil utilise AVAILABLE.
Une réservation d’adoption reste PENDING_ADOPTION, même si l’accueil se termine ;
une adoption déjà effective reste ADOPTED. La signature clôture l’accueil actif
en COMPLETED.

convertToAdoption() est réservé à la famille responsable d’un accueil ACTIVE.
Il crée une demande PENDING avec questionnaire, sans rendre l’animal adopté.
La validation, le contrat et la signature restent obligatoires.

## Cohérence avec l’administration 3A
Le formulaire animal peut toujours modifier ses caractéristiques.
Le statut d’un animal lié à une adoption acceptée ou à un hébergement actif est
géré par le workflow : une modification manuelle contradictoire est refusée.
Un changement administratif vers un statut indisponible clôt les demandes
encore en attente par refus.
Un animal possédant un historique d’adoption ou d’hébergement ne peut plus être
supprimé : cela préserve les contrats et les références historiques.

## Routes
- /adoptions : accès au catalogue et aux demandes.
- /adoptions/new/:animalId
- /adoptions/my
- /adoptions/:id
- /adoptions/:id/contract
- /adoptions/:id/follow-up
- /foster-family
- /foster-family/:id
- /admin/adoptions
- /admin/foster-placements

L’ancien /animals/:id/adoption redirige vers le questionnaire.
L’espace /foster/space existant ouvre désormais Mes hébergements.

Les gardes existants gèrent session, compte et rôle. Les repositories vérifient
en plus l’identité propriétaire pour les lectures et les mutations. Une opération
en attente est refusée si l’identité de session a changé.

## Dépendances
Ajout direct de flutter_localizations fourni par le SDK Flutter pour les
composants et dates en français. Aucun nouveau paquet tiers.
provider, shared_preferences, image_picker et go_router existants sont réutilisés.

## Limites locales
- Une seule instance active de développement est supposée ; les transactions
  ne constituent pas une synchronisation entre plusieurs onglets/appareils.
- Base JSON locale limitée à 3,5 Mo, images choisies limitées à 1 Mo, règles 3A
  inchangées. Les photos de suivi consomment ce même quota.
- Effacer les données du site ou de l’application efface les workflows locaux.
- Le futur backend devra assurer les autorisations, la concurrence multi-clients,
  les identifiants et le stockage des images.
- Les conditions et la signature sont des démonstrations ; aucune intégration
  de signature réelle ni contrat téléchargeable n’est fourni.
- Pas de notifications ni de planification automatique des visites.
- Pas de recette sur appareil Android/iOS.

## Lancer
Depuis le dossier animora :
```powershell
flutter pub get
flutter run -d chrome --release --no-web-resources-cdn --web-port=8765
```

Les comptes existants sont conservés. Pour les scénarios :
citizen@animora.test, veterinarian@animora.test, admin@animora.test,
foster@animora.test. Mot de passe de développement : Animora2026!.

## Scénario de test manuel
1. Comme citoyen, choisir un animal disponible, ouvrir Demander une adoption.
   Soumettre le questionnaire vide puis compléter les réponses.
2. Vérifier le score et ses explications ; compléter la motivation, lire le
   récapitulatif et confirmer. La demande doit être En attente.
3. Consulter Mes demandes. Vérifier le refus d’un doublon ; annuler une demande
   en attente pour vérifier ce cas.
4. Sur un autre animal disponible, créer deux demandes avec deux comptes actifs.
   Comme administrateur, ouvrir Administration → Demandes d’adoption, filtrer
   les demandes, consulter la motivation et le questionnaire.
5. Accepter une demande après confirmation. Vérifier le contrat non signé,
   PENDING_ADOPTION et le refus des demandes concurrentes.
6. Revenir sur le compte de l’adoptant. Lire le contrat, cocher la confirmation,
   signer en démonstration puis confirmer. Vérifier la date et ADOPTED.
7. Ouvrir Suivi post-adoption, publier des nouvelles et une photo facultative.
   Recharger la page : l’historique doit être conservé.
8. Avec un autre compte, ouvrir directement les URLs de demande, contrat et suivi :
   aucune information privée ne doit apparaître. L’administrateur peut les lire.
9. Comme administrateur, affecter un autre animal disponible à une famille active.
   Vérifier FOSTERED et l’impossibilité d’un second accueil actif.
10. Comme famille, ouvrir Mes hébergements, consulter la fiche et ajouter une
    remarque. Tester la fin d’un accueil.
11. Sur un accueil actif, demander l’adoption définitive : questionnaire,
    demande PENDING, validation admin, contrat puis signature. L’accueil doit
    se terminer automatiquement lors de l’adoption effective.

Le contrôle Web a réalisé une adoption de démonstration de Max par le compte
admin de développement, puis un suivi. Ces données restent dans le profil de
navigateur de vérification et ne sont pas réinjectées comme fixtures.

