# Animora — Étape 7 : Événements et bénévolat

## Périmètre livré

Le dernier module métier remplace le placeholder Événements. Aucun backend, acteur Association, nouveau modèle utilisateur, paiement ou notification externe n’est ajouté. L’accès Événements de HomeScreen était déjà présent et ouvre maintenant le catalogue complet. L’administration possède un nouvel accès dédié.

Le catalogue contient recherche par titre, type, ville, date (calendrier) et statut, avec sections à venir et passées. Les brouillons sont exclus du catalogue, y compris pour ADMIN ; ils restent accessibles dans l’administration. Les détails présentent l’image, les horaires, l’adresse, les places, le programme, les actions d’inscription et le bilan publié. Les coordonnées facultatives affichent une carte OpenStreetMap à la demande ; son fond nécessite Internet.

Les utilisateurs actifs peuvent s’inscrire comme participant ou bénévole, consulter leurs inscriptions et leur billet gratuit, puis annuler avant le début de l’événement. Un événement complet propose explicitement la liste d’attente. L’espace bénévole présente les tâches attribuées et permet les transitions « commencée » puis « terminée ». Les utilisateurs sans inscription bénévole active ou historique de présence bénévole n’accèdent pas à cet espace ; les bénévoles en attente voient leur statut mais aucune tâche ne peut leur être attribuée.

ADMIN dispose d’un tableau de bord, des formulaires de création et modification, des actions de publication, annulation et clôture, des listes d’inscriptions filtrables, du pointage par code de billet, du programme d’activités, de l’affectation des tâches et des bilans avec photos.

## Modèles et compatibilité

Six modèles immuables avec sérialisation JSON : Event, EventRegistration, EventTicket, EventActivity, VolunteerTask et EventReport. Cinq enums reprennent les valeurs demandées, avec libellés français.

Les identifiants des nouvelles entités sont des int. Les liens vers User restent des String, conformément au modèle existant : organizerUserId, userId et assignedUserId. Aucune classe utilisateur n’est recréée. EventRegistration conserve un nom d’affichage pour l’historique. EventReport ajoute published et photos afin de distinguer brouillon et bilan public.

## Règles et transitions

- Création ADMIN forcée en DRAFT avec l’organisateur réel. Publication DRAFT → PUBLISHED uniquement avant le début. Fin strictement après début ; capacité entière de 1 à 1 000 000 ; coordonnées complètes et valides. Titre 5–150 caractères, description 20–10 000, adresse 3–300, ville 2–100.
- COMPLETED uniquement depuis PUBLISHED et à partir de la fin prévue. CANCELLED depuis DRAFT ou PUBLISHED. Aucun retour depuis un état terminal. Une clôture conserve l’historique et annule les inscriptions encore en attente.
- Inscription uniquement avant le début d’un événement PUBLISHED, avec compte actif. Une seule inscription non annulée par utilisateur et événement. Participants et bénévoles utilisent la même capacité. CONFIRMED et ATTENDED occupent une place.
- Si complet, acceptation explicite de WAITLISTED ; aucun billet n’est émis. L’ordre d’attente utilise registrationDate puis id en cas d’égalité. Une annulation ou une augmentation de capacité promeut les premiers comptes toujours actifs, sans dépasser la capacité. Les comptes devenus inactifs sont sautés. Une nouvelle inscription traite d’abord les demandes éligibles déjà en attente.
- Annulation personnelle ou ADMIN uniquement avant le début, sur CONFIRMED ou WAITLISTED. Le billet devient immédiatement inutilisable via le statut de l’inscription. Une nouvelle demande après annulation crée une nouvelle inscription et un nouveau billet, sans réactiver l’ancien.
- Annuler l’événement annule les inscriptions confirmées/en attente, invalide les billets et libère les tâches inachevées ; aucune promotion n’a lieu sur cet événement. Les présences déjà pointées restent dans l’historique.
- Les dates sont figées dès la première inscription, même annulée. La capacité peut augmenter ; elle ne peut pas descendre sous le nombre de places occupées. Les activités existantes doivent rester dans la période de l’événement.
- Billet unique par inscription confirmée, code aléatoire local unique. Le QR encode uniquement ce code, sans nom ni coordonnées personnelles. Billet lisible par son propriétaire ou ADMIN uniquement, tant que l’inscription est CONFIRMED, l’événement publié et sa fin non atteinte. Le pointage ADMIN exige le bon événement, les horaires [début, fin[, un compte participant actif et un code non utilisé ; il passe atomiquement le billet à used et l’inscription à ATTENDED.
- Les activités ont des horaires strictement ordonnés, inclus dans ceux de l’événement ; CRUD ADMIN.
- Une tâche n’est attribuable qu’à un bénévole confirmé et actif (ATTENDED conserve l’éligibilité issue de la confirmation). Une tâche commencée n’est plus réattribuable. Seul le bénévole affecté peut passer ASSIGNED → IN_PROGRESS → COMPLETED, tant que l’événement publié n’est pas terminé. Les statuts ne peuvent pas être forcés via le formulaire ADMIN.
- Bilan après clôture COMPLETED : nombres séparés des participants et bénévoles issus uniquement de ATTENDED. Brouillon privé ADMIN, publication explicite et ensuite figée. Six photos maximum, 2 Mo chacune. Aucun compteur manuel ni résultat fictif.

## Architecture et persistance

Six contrats : EventRepository, EventRegistrationRepository, EventTicketRepository, EventActivityRepository, VolunteerTaskRepository et EventReportRepository. Les écrans utilisent ces interfaces via EventsStore ; LocalEventRepository porte les règles. Une future implémentation REST peut remplacer ces contrats.

EventsScope réutilise SembastReportsStorage(namespace: 'events'), comme les modules précédents. Aucun nouveau moteur de stockage. Les photos utilisent le même magasin média Blob, séparé des métadonnées JSON. Le format événements est versionné. Les données corrompues ne sont pas effacées automatiquement.

EventsDatabase applique le mécanisme existant de file d’opérations, copie de travail et publication après écriture réussie. Inscription + billet, annulation + promotion + billet et pointage + présence sont enregistrés dans une seule mutation du document local ; une écriture échouée laisse l’état précédent disponible. Les opérations et lectures médias vérifient les changements d’identité pendant les attentes asynchrones.

L’authentification existante reçoit uniquement une lecture isUserActive(id), renvoyant un booléen sans exposer les coordonnées privées d’autres comptes. Elle sert à la promotion, à l’affectation et au pointage ; aucune règle de connexion ou de transition de compte ne change. Les préfixes ADMIN réutilisent la garde existante du routeur, doublée des vérifications du repository.

La charte utilise le corail #FF6B6B, Poppins, les cartes arrondies et les composants de formulaires, calendrier, confirmation et sélection de photo existants. Les boutons ont une teinte plus foncée pour le contraste. Le logo officiel reste inchangé.

## Routes

- /events
- /events/my
- /events/volunteer
- /events/tickets/:id
- /events/:id
- /events/:id/register (type=VOLUNTEER facultatif)
- /events/:id/report
- /admin/events : tableau de bord
- /admin/events/list : gestion complète
- /admin/events/new
- /admin/events/:id/edit
- /admin/events/:id/registrations
- /admin/events/:id/activities
- /admin/events/:id/volunteers
- /admin/events/:id/report

Les routes fixes précèdent les routes :id. Le bouton Actualiser recharge l’état local et les conditions horaires ; il ne contacte pas un serveur.

## Dépendances

qr ^3.0.3 est désormais une dépendance directe, déjà présente indirectement via pdf. Aucun nouveau paquet transitif ni mise à niveau des autres bibliothèques. Le QR est dessiné localement avec marge silencieuse de quatre modules ; aucun service de génération distant. flutter_map et latlong2 existaient déjà pour les cartes.

## Limites

Démonstration locale : aucun partage entre appareils, synchronisation, notification externe, scan caméra ou validation serveur. Le pointage se fait par saisie/copie du code ou consultation du billet ; le QR est disponible à l’écran. Toutes les places ne sont cohérentes que dans l’instance locale sérialisée, pas entre plusieurs instances d’application concurrentes sur le même stockage.

Sur Web, conserver navigateur, profil, hôte et port. Effacer les données du site, le mode privé ou les quotas peuvent perdre les données. Les données locales ne sont pas chiffrées ; les propriétaires de l’appareil peuvent les consulter. Les médias sauvegardés avant une écriture finale échouée peuvent rester orphelins : pas de nettoyage automatique.

Les dates suivent le fuseau local de l’appareil. Les changements horaires et la liste d’attente n’utilisent pas de service en tâche de fond ; l’application affiche l’état à l’ouverture/actualisation. Les mutations revérifient les règles même si une page est restée ouverte. La carte et ses tuiles nécessitent Internet, mais l’inscription et le billet local n’en dépendent pas. La validation sur appareils Android/iOS reste nécessaire ; les tests à 360 px ne la remplacent pas.

## Scénario manuel

Comptes fictifs existants : admin@animora.test, citizen@animora.test, foster@animora.test ; mot de passe de démonstration Animora2026!.

1. Comme ADMIN, créer un événement futur avec capacité 1, adresse, ville, horaires valides et éventuellement image/coordonnées. Vérifier le brouillon dans l’administration et son absence du catalogue citoyen.
2. Ajouter une activité incluse dans la période, tester une activité hors période, modifier puis supprimer une activité. Créer une tâche disponible.
3. Publier l’événement. Vérifier les filtres titre/type/ville/date/statut et le détail depuis l’accueil. Afficher la carte si des coordonnées sont fournies.
4. Comme citoyen, choisir Bénévole et confirmer. Vérifier CONFIRMED, une place occupée et un seul billet gratuit. Une deuxième inscription doit être refusée. Ouvrir le QR et noter uniquement son code.
5. Comme second utilisateur, choisir Participant sur l’événement complet. La confirmation exige « Rejoindre la liste d’attente ». Vérifier WAITLISTED et aucun billet.
6. Comme ADMIN, affecter la tâche au bénévole confirmé ; un participant ou bénévole en attente ne doit pas être proposé. Comme bénévole, commencer et terminer la tâche. Comme autre utilisateur, vérifier que cette tâche n’est pas visible ni modifiable.
7. Avant le début, annuler la première inscription. Vérifier l’ancien billet inutilisable et la promotion automatique de la première demande éligible avec un nouveau billet. Répéter l’annulation ne doit pas produire de promotion supplémentaire.
8. Tester l’augmentation de capacité avec plusieurs demandes en attente. Tenter une réduction sous les places occupées et un changement de dates après inscription : refus.
9. Pendant les horaires, comme ADMIN, saisir le code valide dans le pointage et confirmer. Vérifier ATTENDED et billet utilisé. Tester mauvais code, code d’un autre événement et seconde utilisation : refus. Aucun pointage avant le début ou à partir de la fin.
10. Après la fin, marquer l’événement terminé. Ouvrir le bilan : seuls les pointages réels sont comptés, séparément pour participants et bénévoles. Enregistrer un brouillon avec texte et photos, vérifier son absence côté citoyen, puis publier et consulter le bilan depuis l’événement passé.
11. Sur un second événement, annuler avec des inscriptions et une attente. Vérifier l’annulation des inscriptions, l’invalidité des billets et l’absence de promotion.
12. Recharger sur la même origine, vérifier les données et les droits ; tester une route ADMIN comme citoyen et un billet privé d’un autre compte. Vérifier les écrans à 360 px, puis les modules animaux, adoptions, signalements, vétérinaire, pet-sitting et dons.

Voir [les fichiers](FILES_7.md) et [les résultats de validation](VALIDATION_7.md). Aucune intégration backend n’est commencée.
