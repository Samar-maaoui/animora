# Animora — Étape 6 : Dons et campagnes

## Périmètre réalisé

Le module réutilise User, AuthSession, go_router, Provider, Poppins et le stockage Sembast existant. Aucun acteur Association, backend, prestataire de paiement ou donnée bancaire n’a été ajouté.

La base de l’étape 5 a été vérifiée avant modification : analyse propre et 162 tests réussis. Les autres modules métier sont conservés et le module Événements n’a pas été commencé.

## Fonctionnalités

- Catalogue des campagnes avec recherche par titre, filtres de statut, image facultative, objectif, contributions simulées confirmées, progression et dates.
- Détails d’une campagne avec besoins matériels, rapports publiés et accès aux deux types de contribution lorsque la campagne est ACTIVE et dans sa période.
- Don financier ponctuel : montants prédéfinis ou personnalisés en TND, récapitulatif et confirmation explicite d’une simulation. Aucun champ bancaire ni paiement réel.
- Proposition de matériel : type, quantité entière, description et besoin lié facultatif ; statut initial PENDING.
- Historique privé des dons, détails, références de démonstration et reçu après confirmation.
- Programmes récurrents simulés : hebdomadaires ou mensuels, suspension, reprise et annulation par le donateur. Aucune contribution créée automatiquement par une échéance.
- Reçus de démonstration consultables et exportables en PDF, avec logo original, Poppins et mention « Reçu de démonstration — aucun paiement réel effectué ». Aucun reçu fiscal officiel.
- Administration : indicateurs, création / modification / publication / clôture / annulation des campagnes, contributions, besoins, réception / rejet du matériel et rapports de transparence.
- Couleur violette #8B5CF6, cartes arrondies, barres de progression, confirmations et rendu mobile à 360 px.

## Modèles et interfaces

Les sept modèles sont dans `lib/features/donations/models/` : DonationCampaign, Donation, MaterialDonation, RecurringDonation, DonationReceipt, MaterialNeed et TransparencyReport. Les huit énumérations correspondent aux statuts et types demandés.

Les identifiants d’entités sont des `int`. Les références utilisateur restent des `String`, conformément au modèle User déjà utilisé ; User n’est pas dupliqué ni modifié.

Champs complémentaires :

- MaterialNeed.itemType et MaterialDonation.materialNeedId permettent d’affecter une réception à un besoin précis du même type et de la même campagne.
- Les noms / titres figés sur les dons et reçus rendent l’historique lisible même après modification d’une campagne.
- Une clé de demande protège les tentatives répétées d’un même formulaire, tout en autorisant plusieurs dons intentionnels.
- La date planifiée d’une occurrence et son programme d’origine évitent les doublons de récurrence.
- Un rapport conserve un instantané des chiffres calculés à sa publication.

Les sept interfaces demandées sont implémentées par LocalDonationRepository : DonationCampaignRepository, DonationRepository, MaterialDonationRepository, RecurringDonationRepository, DonationReceiptRepository, MaterialNeedRepository et TransparencyReportRepository. L’UI les utilise via DonationsStore ; une implémentation REST pourra remplacer l’adaptateur local.

## Règles de comptabilisation

Les calculs utilisent des **millimes entiers**, puis les exposent dans les champs double du diagramme. Les montants doivent être finis, strictement positifs, compris entre 0,001 et 1 000 000 000 TND, avec trois décimales maximum.

Le montant collecté est recalculé à partir des seuls dons FINANCIAL / CONFIRMED. Les champs collectedAmount fournis à une sauvegarde de campagne sont ignorés. Les dons en attente, annulés et matériels ne gonflent jamais le total financier. Un dépassement d’objectif reste affiché avec son pourcentage réel ; seule la barre visuelle est plafonnée à 100 %.

Les quantités reçues d’un besoin sont recalculées depuis les dons MATERIAL / CONFIRMED dont le détail est RECEIVED et explicitement lié à ce besoin. Une proposition libre réceptionnée reste suivie séparément tant qu’aucun besoin compatible n’est affecté au moment de la réception. Une quantité supérieure à l’objectif est conservée exactement, avec le statut FULFILLED.

Une confirmation ou réception ne peut être répétée. Chaque don confirmé a au plus un reçu. Une proposition rejetée ou annulée ne compte pas et ne produit pas de reçu. Un don confirmé ne peut pas être annulé dans cette version : il n’existe aucun workflow de remboursement, réel ou fictif.

## Campagnes et récurrences

Une campagne est créée en DRAFT, puis publiée par ADMIN. Seules DRAFT et ACTIVE sont modifiables. Les dates doivent être cohérentes et la fin future lors d’une création / modification. La période est figée après une première contribution ou programmation ; titre, description, objectif et image restent modifiables tant que la campagne n’est pas terminée.

La clôture / annulation arrête les programmes récurrents et annule les contributions en attente dans le même snapshot. Les contributions confirmées et leurs reçus restent historiques. L’expiration d’une date n’exécute aucun paiement ni confirmation : ADMIN peut ensuite clôturer la campagne. Les contributions et réceptions doivent être traitées pendant sa période ouverte.

Un programme récurrent ne crée pas de don immédiat. Quand son échéance est atteinte :

1. Le donateur choisit « Préparer cette occurrence ».
2. Une seule contribution PENDING est créée pour cette échéance ; son montant n’est pas collecté.
3. Le donateur confirme séparément cette simulation depuis ses détails.
4. Le reçu est créé et la prochaine date est avancée.

Les échéances manquées ne sont pas recréées en série. Après confirmation, la date suivante est la première future selon la fréquence. Les mois courts sont gérés en conservant le jour d’ancrage (31 janvier → 28 février → 31 mars). Une date suivante dépassant la fin de campagne termine le programme avec un motif explicite.

Suspendre ou annuler un programme annule ses occurrences encore en attente. Reprendre un programme ne déclenche aucune contribution. Pour voir une échéance devenue disponible avec le temps, revenir sur la page ou la recharger.

## Transparence et confidentialité

ADMIN saisit la description et l’utilisation **déclarée** des ressources. Le module n’invente ni dépense, ni facture, ni justificatif. Les sommes et quantités du rapport sont calculées au moment de la publication ; les rapports précédents sont conservés avec leur date et leurs chiffres historiques, distincts du total courant.

Un utilisateur ordinaire ne peut lire que ses dons, propositions, programmes et reçus. ADMIN peut consulter les données nécessaires à l’administration et traiter les contributions ; il ne peut pas suspendre ou annuler le programme récurrent d’un autre donateur à sa place.

Les campagnes publiées, besoins et rapports sont consultables par les comptes ACTIVE ; les brouillons sont réservés à ADMIN. Les contrôles sont appliqués dans les repositories, en plus des routes et boutons. Les opérations en attente et lectures de médias vérifient l’identité de session.

## Stockage et export PDF

Le mécanisme Sembast déjà présent est réutilisé avec le namespace `donations` :

- Web : IndexedDB `animora_donations_v1`.
- Natif : `animora_donations.db` dans le répertoire de support applicatif.

Le snapshot sérialise les écritures et conserve les opérations liées ensemble : don / reçu, réception / statut et clôture / annulations. Un échec d’écriture conserve l’état mémoire précédent. Une base illisible n’est jamais effacée silencieusement.

Les médias de campagne utilisent le magasin distinct de l’adaptateur Sembast existant, sans gros fichiers dans SharedPreferences. Le sélecteur existant retire les métadonnées et limite l’image préparée à 2 Mo.

Le PDF est produit à la demande avec les polices et le logo embarqués, puis proposé au téléchargement / partage de la plateforme. Le champ filePath reste nul : aucune destination fictive n’est enregistrée. Les reçus sont non fiscaux, avec mention de démonstration et pied de page sur toutes les pages. Une nouvelle vérification d’autorisation précède l’export.

Dépendances directes ajoutées :

| Bibliothèque | Version résolue | Usage |
| --- | --- | --- |
| pdf | 3.13.1 | Génération du reçu |
| printing | 5.15.1 | Export / partage du PDF sur la plateforme |

Documentation des packages : [pdf](https://pub.dev/packages/pdf), [printing](https://pub.dev/packages/printing). Aucune passerelle de paiement.

## Navigation

Routes publiques authentifiées : `/donations`, `/donations/campaigns/:id`, `/donations/financial/:campaignId`, `/donations/material/:campaignId`, `/donations/my`, `/donations/details/:id`, `/donations/receipts/:id`, `/donations/recurring`.

Routes ADMIN : `/admin/donations`, `/admin/donations/campaigns`, `/admin/donations/campaigns/new`, `/admin/donations/campaigns/:id/edit`, `/admin/donations/campaigns/:id/needs`, `/admin/donations/campaigns/:id/contributions`, `/admin/donations/material`, `/admin/donations/reports`.

Le raccourci Dons existant de HomeScreen ouvre désormais le catalogue fonctionnel. Le menu administratif propose « Dons et campagnes ».

## Limites

Version locale de démonstration : aucun partage entre appareils, paiement, prélèvement automatique, reçu fiscal officiel, envoi distant ou contrôle réel d’organisme collecteur.

La persistance Web dépend du même profil, hôte et port. Effacement du site, mode privé et quotas peuvent supprimer les données. Le stockage local n’est pas chiffré ; un propriétaire de l’appareil ou ses outils développeur peuvent lire les données. Une version de production exigera des contrôles serveur, des autorisations et une vraie stratégie de stockage.

Il n’existe pas de tâche de fond, de quota global ni de nettoyage automatique des médias orphelins si une publication échoue après préparation de l’image. Les dates utilisent le fuseau local de l’appareil.

Le téléchargement Web et le rendu PDF font partie de la validation. Les comportements natifs de partage et le cycle de vie Android / iOS restent à vérifier sur appareil.

## Scénario manuel

Comptes fictifs existants : `admin@animora.test`, `citizen@animora.test` et un second compte actif. Mot de passe de démonstration : `Animora2026!`.

1. Comme ADMIN, créer un brouillon avec objectif de 100 TND, description et dates couvrant maintenant. Vérifier qu’un autre compte ne voit pas le brouillon, puis publier la campagne.
2. Ajouter un besoin FOOD, par exemple « 10 sacs de croquettes ». Vérifier qu’aucun montant collecté ni quantité reçue n’est modifiable manuellement.
3. Comme citoyen, ouvrir le catalogue, rechercher le titre et filtrer les statuts. Faire une contribution financière simulée de 20,125 TND après récapitulatif et confirmation. Vérifier le total de 20,125 TND.
4. Ouvrir « Mes dons », ses détails et le reçu. Exporter le PDF et vérifier la référence, le donateur, la campagne, le montant et les mentions de démonstration / non-fiscalité.
5. Proposer 3 sacs de nourriture liés au besoin. Vérifier le statut En attente et une quantité reçue de zéro. Comme ADMIN, confirmer la réception : quantité 3 / 10, total financier toujours 20,125 TND, reçu matériel disponible. Une seconde confirmation doit être impossible.
6. Tester une proposition rejetée et une proposition libre réceptionnée sans besoin : aucune augmentation injustifiée du besoin lié à la première proposition.
7. Comme citoyen, créer un programme récurrent simulé avec une première date future proche. Vérifier qu’aucun don immédiat n’apparaît. Après l’échéance, revenir sur la page, préparer l’occurrence puis vérifier PENDING et l’absence de collecte avant confirmation explicite.
8. Suspendre puis reprendre le programme, et tester l’annulation. Vérifier l’absence de débit automatique et l’annulation des occurrences encore en attente.
9. Comme ADMIN, publier un rapport avec une utilisation uniquement déclarée. Vérifier les chiffres calculés et leur date ; une contribution ultérieure doit modifier le total courant, sans réécrire le rapport historique.
10. Comme autre utilisateur, vérifier l’absence des dons et reçus du premier compte ; tenter une route ADMIN doit conduire à Accès refusé.
11. Clôturer la campagne : contributions en attente et programmes arrêtés, contributions confirmées conservées, nouveaux dons indisponibles.
12. Recharger le navigateur sur la même origine pour vérifier la persistance, puis contrôler l’interface à 360 px et les modules des étapes précédentes.

Voir [les fichiers](FILES_6.md) et [la validation](VALIDATION_6.md).

