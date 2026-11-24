# Animora — Étape 5 : Vétérinaire et pet-sitting

## Reprise et périmètre

Les modifications commencées avant l’interruption ont été conservées. Le blocage observé provenait du test d’interface : des futures créées dans la boucle asynchrone réelle restaient en attente pendant que `pumpAndSettle` faisait uniquement avancer le temps simulé. Les helpers de test font désormais avancer les frames dans `runAsync`, puis attendent la stabilisation. Aucun test n’a été désactivé ou supprimé.

Les sélecteurs ont aussi été précisés lorsque le titre et le bouton d’une boîte de dialogue portaient le même texte. Le retour de la dernière action remplace les anciens messages pour que les erreurs importantes restent immédiatement visibles.

## Gestion vétérinaire

- Annuaire des utilisateurs VETERINARIAN ACTIVE : nom, avatar/photo compatible avec le modèle existant, ville, disponibilités, profil et réservation. Recherche par nom, filtres par ville et date disponible. Aucune spécialité inventée.
- Disponibilités : ajout, modification et suppression par le vétérinaire concerné, dates futures, fin supérieure au début, absence de chevauchement et affichage des créneaux réservés / archivés.
- Rendez-vous : choix d’un animal sous responsabilité, motif, confirmation explicite et statut initial PENDING. Le créneau est bloqué dès la demande ; une écriture sérialisée empêche une double réservation.
- Espace professionnel : demandes en attente, confirmations, rendez-vous du jour, historique, décision, annulation autorisée, notes privées et clôture d’une consultation confirmée à partir de son heure prévue.
- Santé : vaccinations, prochaine dose, soins réalisés, coût facultatif et historique. Le vétérinaire auteur peut modifier ses vaccinations. Il doit avoir un rendez-vous confirmé ou terminé avec l’animal pour enregistrer des actes.
- Rappels : une prochaine dose génère automatiquement un rappel interne. Sa modification remplace le rappel associé ; son retrait le supprime. Le responsable ou le vétérinaire traitant peut aussi planifier un soin / rappel. Les dates à venir et dépassées sont distinguées. `isSent` reste faux : aucun envoi de notification n’est simulé.

## Pet-sitting

- Annuaire des PET_SITTER ACTIVE : nom, avatar, ville, tarif configuré, disponibilité sur la période choisie, avis existants et moyenne calculée.
- Configuration professionnelle liée à l’identifiant User : acceptation de nouvelles demandes, tarif et période proposée ; capacité fixée à une garde à la fois. Sans configuration, aucun tarif ni disponibilité n’est inventé.
- Demande de garde : animal sous responsabilité, dates et heures, instructions privées, devis et confirmation explicite. Les dates doivent être futures, la fin supérieure au début et la période couverte par la configuration.
- Prix : chaque tranche de 24 heures entamée est comptée ; le total est arrondi à deux décimales et figé au dépôt de la demande. Un changement ultérieur de tarif ne modifie pas une demande existante. Montants affichés en TND ; aucun paiement.
- Tableau de bord : demandes reçues, acceptées, en cours et historique. Les chevauchements sont revérifiés à l’acceptation pour le pet-sitter et pour l’animal.
- Démarrage pendant la période réservée, puis clôture à partir de la fin prévue. Une autre garde encore IN_PROGRESS empêche de démarrer la suivante, même si sa fin théorique est dépassée.
- Une demande PENDING ou ACCEPTED non démarrée peut être annulée par un participant, y compris si sa période a expiré ; une garde rejetée ou annulée ne peut pas être démarrée.
- Suivi privé : messages et photos pendant une garde IN_PROGRESS, chronologie accessible uniquement aux participants et à ADMIN.
- Avis : seulement après COMPLETED, par le responsable concerné, note de 1 à 5, un avis par garde. Note et commentaire deviennent publics dans l’annuaire local.

## Identité, responsabilité et accès

Les modèles **User** et **Animal** n’ont pas été modifiés ni dupliqués. Les références utilisateur restent des `String`, comme dans l’authentification existante ; les identifiants des nouvelles entités sont des `int`.

Animal ne possède pas de champ propriétaire. La responsabilité est donc déduite des relations déjà persistées : adoption ACCEPTED avec contrat signé et date d’adoption, ou hébergement ACTIVE commencé et non terminé. Consulter un animal dans le catalogue ne donne aucun droit de réservation ou de lecture du carnet.

Les comptes professionnels doivent être ACTIVE. Les espaces vétérinaire et pet-sitter sont strictement réservés au profil concerné ; ADMIN dispose d’une supervision séparée en lecture, sans usurper les décisions d’un professionnel.

Les contrôles de rôle, de responsabilité et de participation existent dans les repositories. Les opérations en attente et les lectures de photos privées vérifient le maintien de l’identité courante. Les écrans ne conservent pas l’ancien résultat pendant une recharge ou un changement de session.

L’annuaire utilise une méthode dédiée de l’AuthRepository existant, qui ne renvoie que les professionnels actifs et retire e-mail / téléphone. La gestion administrative des comptes reste protégée.

## Architecture et persistance

Architecture feature-first :

- `features/veterinary/` : modèles, six interfaces de repository et écrans vétérinaires / santé.
- `features/pet_sitting/` : modèles, trois interfaces de repository et écrans de garde.
- `features/animal_services/` : coordination des deux workflows, implémentation locale des interfaces, snapshot transactionnel, scope et widgets communs.

Les neuf abstractions demandées sont implémentées : VeterinaryRepository, AvailabilityRepository, VeterinaryAppointmentRepository, VaccinationRepository, CareRepository, ReminderRepository, PetSittingRepository, PetSittingUpdateRepository et ReviewRepository. Les écrans utilisent ces interfaces via ServicesStore.

Le mécanisme Sembast introduit à l’étape 4 est réutilisé avec un namespace configurable. Le namespace par défaut des signalements reste `reports`, avec les mêmes noms de base et les mêmes données. Le nouveau namespace `care_services` isole les métadonnées et médias privés des services :

- Web : IndexedDB `animora_care_services_v1`.
- Natif : `animora_care_services.db` dans le répertoire de support de l’application.

Les opérations liées — réservation et créneau, vaccination et rappel, acceptation et capacité — sont enregistrées dans un même snapshot après validation. En cas d’échec d’écriture, l’état mémoire précédent est conservé. Une base illisible n’est pas réinitialisée silencieusement.

Les photos réutilisent le sélecteur de l’étape 4 : source limitée à 8 Mo, réencodage PNG sans métadonnées, largeur maximale 1200 px sans agrandissement, résultat limité à 2 Mo. Les fichiers sont stockés comme médias Sembast distincts ; aucun gros fichier image de ce module n’est ajouté à SharedPreferences.

Le `Time` conceptuel des disponibilités est représenté par un entier de minutes depuis minuit (0–1439), avec une fin strictement postérieure au début sur la même journée. Les dates / heures utilisent le fuseau local de l’appareil. Une API de production devra définir un fuseau explicite et faire respecter ces invariants côté serveur.

## Navigation

Routes vétérinaires :

- `/veterinary`, `/veterinary/:id`, `/veterinary/book/:id`
- `/veterinary/my-appointments`
- `/veterinary/dashboard`, `/veterinary/availability`
- `/health` : animaux dont le carnet est accessible
- `/animals/:id/health`, `/animals/:id/vaccinations`, `/animals/:id/reminders`

Routes pet-sitting :

- `/pet-sitting`, `/pet-sitting/:id`, `/pet-sitting/request/:id`
- `/pet-sitting/my-requests`
- `/pet-sitting/dashboard`, `/pet-sitting/settings`
- `/pet-sitting/requests/:id/tracking`, `/pet-sitting/requests/:id/review`

Supervision : `/admin/services`.

Les anciens liens `/veterinary/space` et `/pet-sitting/space` redirigent vers les nouveaux tableaux de bord. L’accueil propose les annuaires, demandes personnelles et carnets. Les fiches animales donnent accès au carnet sous contrôle d’autorisation.

## Dépendances et présentation

**Aucune nouvelle dépendance.** Sembast, Provider, go_router et image_picker étaient déjà présents. Le fichier pubspec.yaml reste inchangé.

Logo officiel conservé à l’identique, police Poppins héritée du thème existant, cartes arrondies, badges, formulaires français, turquoise #06B6D4 et vert #22C55E. Les parcours ont été testés à 360 px.

## Limites

- Données locales à une installation / origine de navigateur ; aucune synchronisation entre appareils, API réelle, messagerie ni notification distante.
- Aucun paiement, ni validation officielle de l’identité professionnelle ou certification médicale à distance. Les saisies de santé restent des données de démonstration locale.
- Pas de chiffrement du stockage local : le propriétaire de l’appareil et ses outils développeur peuvent lire les fichiers / IndexedDB.
- Persistance Web liée au même profil, hôte et port ; effacement du site, mode privé et quotas du navigateur peuvent supprimer les données.
- Pas de quota global ni de nettoyage automatique des médias orphelins après une publication abandonnée ou une écriture échouée.
- Les changements du catalogue et les services sont dans des stockages distincts : ils ne constituent pas une transaction serveur distribuée. Les animaux et responsabilités sont revérifiés aux actions sensibles ; les données historiques conservent des noms figés pour rester lisibles après une modification.
- Les tableaux de bord disposent d’« Actualiser » pour les actions qui deviennent disponibles avec l’heure. Il n’y a pas de tâche de fond.
- Les permissions et le cycle de vie natifs ne sont pas validés sur appareil Android / iOS ici ; aucun de ces appareils n’est connecté.
- Le module Dons reste inchangé et l’étape 6 n’a pas été commencée.

Voir [VALIDATION_5.md](VALIDATION_5.md), [FILES_5.md](FILES_5.md) et le scénario manuel ci-dessous.

## Scénario manuel

Comptes fictifs existants : `citizen@animora.test`, `veterinarian@animora.test`, `pet-sitter@animora.test` et `admin@animora.test`. Mot de passe de démonstration commun : `Animora2026!`.

1. Préparer un animal sous responsabilité du citoyen via le parcours d’adoption existant : décision ADMIN puis signature du contrat par le citoyen. Un accueil actif existant convient également à son responsable. Ne pas attribuer arbitrairement tous les animaux du catalogue à l’utilisateur.
2. Comme vétérinaire, ouvrir « Mes disponibilités ». Créer deux créneaux futurs adjacents ; tenter un chevauchement, une date passée et une fin antérieure au début. Modifier puis supprimer un créneau libre.
3. Comme citoyen, rechercher le vétérinaire par nom / ville / date. Réserver un créneau pour l’animal autorisé avec un motif. Vérifier le statut En attente et l’indisponibilité du créneau pour une seconde réservation.
4. Comme vétérinaire, accepter la demande. Vérifier le patient et les notes de consultation. Sur un autre rendez-vous, tester le refus ou l’annulation avant la date et la libération du créneau. Une consultation peut être terminée à partir de son heure prévue.
5. Depuis le carnet autorisé du patient, enregistrer une vaccination avec prochaine dose. Contrôler le rappel interne, modifier la date, puis retirer la prochaine dose pour vérifier le retrait du rappel associé. Enregistrer un soin avec coût facultatif.
6. Comme citoyen responsable, consulter soins / vaccinations / rappels sans bouton d’enregistrement d’acte vétérinaire. Comme autre utilisateur, vérifier que l’accès direct au carnet est refusé. Vérifier l’absence de promesse d’envoi de notification.
7. Comme pet-sitter, configurer un tarif et une période couvrant les prochaines gardes, puis activer les demandes. Comme citoyen, rechercher ce profil, choisir son animal, les dates / heures et des instructions ; vérifier le devis et confirmer.
8. Comme pet-sitter, accepter la demande. Tenter d’accepter une autre demande chevauchante pour vérifier le refus. Annuler ou refuser une autre demande autorisée.
9. Pour tester sans attendre plusieurs jours, choisir au départ une garde de quelques minutes, avec un début et une fin futurs proches. À l’heure prévue, actualiser le tableau de bord, démarrer, publier un message et une photo fictive. Comme propriétaire, consulter le suivi ; comme tiers, vérifier le refus d’accès.
10. À partir de la fin prévue, terminer la garde. Comme propriétaire, publier une note et un commentaire. Vérifier la moyenne publique et le refus d’un second avis. Tester aussi une demande acceptée expirée mais jamais démarrée : elle doit pouvoir être annulée.
11. Comme ADMIN, ouvrir « Rendez-vous et gardes » pour la supervision. Vérifier l’impossibilité d’usurper les actions professionnelles et l’accès aux données administratives nécessaires.
12. Recharger / relancer sur la même origine et le même profil : créneaux, rendez-vous, santé, rappels, paramètres de garde, suivi et avis doivent être conservés. Refaire les parcours à 360 px, puis vérifier catalogue, favoris, adoption, accueil, signalements et annonces perdus / trouvés.

