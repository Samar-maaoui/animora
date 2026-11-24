# Étape 11 — audit initial avant modification

| Groupe | État initial | Intervention |
|---|---|---|
| Authentification / splash / statuts | Hors shell ; logo header 184 px | Header adaptatif, sans barre |
| Accueil / animaux / favoris / profil | Shell avec 5 destinations | Cinq branches persistantes, Notifications conservée |
| Autres sous-pages des six modules | Hors shell, barre absente | Intégration au shell |
| AppBar secondaires | Retour implicite seulement si pile présente | Retour et repli profond explicites |
| Formulaires | Défilants majoritairement, abandon non protégé | Protection commune des sorties |

**Référence officielle conservée : Accueil — Animaux — Favoris — Notifications — Profil.**

Notifications conserve son écran ModuleScreen préexistant, sans nouvelle fonctionnalité. La proposition initiale à quatre destinations a été corrigée à la reprise, conformément à la nouvelle consigne.

## Inventaire initial des chemins

- `/`
- `/splash`
- `/login`
- `/pending-approval`
- `/blocked`
- `/register`
- `/home`
- `/animals`
- `:id`
- `adoption`
- `/profile`
- `/profile/edit`
- `/access-denied`
- `/favorites`
- `/notifications`
- `/veterinary/my-appointments`
- `/veterinary/dashboard`
- `/veterinary/availability`
- `/veterinary/book/:id`
- `/veterinary/:id`
- `/health`
- `/animals/:id/health`
- `/animals/:id/vaccinations`
- `/animals/:id/reminders`
- `/pet-sitting/my-requests`
- `/pet-sitting/dashboard`
- `/pet-sitting/settings`
- `/pet-sitting/request/:id`
- `/pet-sitting/requests/:id/tracking`
- `/pet-sitting/requests/:id/review`
- `/pet-sitting/:id`
- `/admin/services`
- `/adoptions`
- `/adoptions/new/:animalId`
- `/adoptions/my`
- `/adoptions/:id`
- `/adoptions/:id/contract`
- `/adoptions/:id/follow-up`
- `/foster-family`
- `/foster-family/:id`
- `/admin/adoptions`
- `/admin/foster-placements`
- `/reports/new`
- `/reports/:id`
- `/lost-found`
- `/lost-found/new`
- `/lost-found/:id`
- `/lost-found/:id/edit`
- `/lost-found/:id/testimonies`
- `/lost-found/:id/zone`
- `/matches`
- `/matches/:id`
- `/claims`
- `/claims/new/:announcementId`
- `/reunion-stories`
- `/reunion-stories/new/:id`
- `/admin/reports`
- `/reports`
- `/veterinary`
- `/pet-sitting`
- `/donations/my`
- `/donations/recurring`
- `/donations/campaigns/:id`
- `/donations/financial/:campaignId`
- `/donations/material/:campaignId`
- `/donations/receipts/:id`
- `/donations/details/:id`
- `/admin/donations`
- `/admin/donations/campaigns`
- `/admin/donations/campaigns/new`
- `/admin/donations/campaigns/:id/edit`
- `/admin/donations/campaigns/:id/needs`
- `/admin/donations/campaigns/:id/contributions`
- `/admin/donations/material`
- `/admin/donations/reports`
- `/donations`
- `/events/my`
- `/events/volunteer`
- `/events/tickets/:id`
- `/events/:id/register`
- `/events/:id/report`
- `/events/:id`
- `/admin/events`
- `/admin/events/list`
- `/admin/events/new`
- `/admin/events/:id/edit`
- `/admin/events/:id/registrations`
- `/admin/events/:id/activities`
- `/admin/events/:id/volunteers`
- `/admin/events/:id/report`
- `/events`
- `/admin`
- `/admin/animals`
- `/admin/animals/new`
- `/admin/animals/:id/edit`
- `/admin/users`
- `/veterinary/space`
- `/pet-sitting/space`
- `/foster/space`

## Architecture finale

La barre contient toujours **Accueil — Animaux — Favoris — Notifications — Profil**, dans cet ordre, avec les icônes et libellés d’origine. Un seul MainShell porte NavigationBar. StatefulShellRoute.indexedStack conserve les cinq navigateurs et les états de pages maintenus dans leurs branches ; les branches sont initialisées explicitement sur /home, /animals, /favorites, /notifications et /profile. Animaux comprend aussi adoptions, hébergements et santé animale. Les autres modules et l’administration relèvent du portail Accueil. Toucher une destination ouvre sa racine, comme dans la barre initiale : Accueil revient bien à /home et Animaux à /animals. Le retour aux racines peut retirer leurs sous-pages ; les recherches et positions des racines maintenues restent conservées. Notifications garde son ModuleScreen initial ; aucune nouvelle logique de notification.

Les 99 déclarations de chemins, sous-routes incluses, sont conservées. La fonction sessionRedirect reste identique à la sauvegarde avant cette étape. Le rafraîchissement du routeur est limité aux changements de disponibilité de session, identité, profil ou statut : un simple état occupé ou une modification du nom ne ferme plus un éditeur poussé. Les providers métier restent au-dessus des branches.

La barre est exclue du démarrage, de la connexion, de l’inscription et des écrans pending/blocked : ces derniers ne doivent pas ouvrir les modules protégés. Les dialogues restent modaux. Une URL inconnue conserve la page d’erreur avec un retour de repli. Les Scaffolds de page conservent leur AppBar ; seul le shell dessine la barre inférieure, sans duplication.

## Retour et formulaires

NavigationAppBar réutilise BackButton standard : pop lorsqu’une pile existe, sinon repli vers le module parent (profil, catalogue, signalements, dons, événements, etc.), puis Accueil en dernier recours. Les cinq racines n’ont pas de retour artificiel. BackButtonListener traite aussi le retour système d’un lien profond sans historique.

GuardedForm conserve les clés FormState existantes et propose Annuler / Quitter avant une sortie comportant des saisies non enregistrées. Les gardes onExit couvrent les navigations go_router, y compris les changements d’onglet et les retours gérés par le routeur. Les confirmations concurrentes sont dédupliquées ; les formulaires cachés ne bloquent pas l’onglet courant. Les saisies des étapes de questionnaire remontent au conteneur. Cases à cocher, interrupteurs, curseurs, photos et dates signalent aussi les modifications. Après une sauvegarde réussie, les métadonnées de brouillon sont acquittées ; un échec ne les acquitte pas. Les redirections de permissions restent prioritaires.

Les brouillons restent en mémoire, pas dans SQLite. Fermer l’onglet, recharger entièrement la page ou saisir une autre URL quittant l’application ne garantit pas leur conservation : les gardes Flutter ne remplacent pas un stockage de brouillons ni un gestionnaire natif beforeunload. Les états des onglets sont conservés dans la session de navigation, pas après redémarrage du processus.

## Responsive

Le header du logo réserve 128 px par défaut au lieu de 184. Sur connexion/inscription, il passe à 96 px sous 700 px de hauteur et à 64 px lorsque le clavier est ouvert. L’image originale reste affichée entière avec BoxFit.contain ; aucun filtre ni recadrage. Le sélecteur de profil utilise isExpanded pour éviter le débordement constaté à 320 px. Les formulaires gardent leur défilement, SafeArea et redimensionnement de Scaffold.

La barre à cinq destinations est masquée lorsque le clavier occupe le viewport afin de laisser la place au formulaire ; elle revient à sa fermeture. Aucun défilement horizontal n’est ajouté. Les touch targets Material et l’état sélectionné sont conservés.

## Écrans et composants modifiés

- app/routes/app_router.dart : cinq branches, gardes UI, écoute ciblée de la session.
- core/widgets/main_shell.dart, navigation_app_bar.dart, guarded_form.dart, animora_logo_app_bar.dart et module_screen.dart.
- Écrans directs : catalogue, fiche animal, favoris, adoptions, questionnaire, suivi d’adoption, hébergement, administration/animaux/utilisateurs, profil et édition du profil.
- Composants de pages communs : WorkflowPage, ReportsPage, ServicesPage, DonationsPage, EventsPage ; ils couvrent les sous-pages de leurs modules.
- Callbacks UI des formulaires de signalement, dons, événements, vétérinaire et pet-sitting : acquittement du brouillon après succès, sans changer les actions ni validations métier.
- AuthForm : uniquement dimensions du header et largeur du sélecteur ; aucun changement d’authentification, mot de passe, seed ou stockage.

Les migrations, SQLite v7, les modèles, repositories métier, comptes de démonstration et six services API ne sont pas modifiés par cette étape. Les modifications non commitées des étapes précédentes ont été conservées. SHA-256 du logo inchangé : B5F45FACFFCC664D7BAD0A1552040ADB48C485F78F789D2A494528860A7D4A86.

## Tests et validation

17 tests ajoutés dans test/navigation_step11_test.dart : cinq destinations et ordre, notifications, recherche conservée, barre unique dans sept sous-pages métier, retour profond, retour système simulé, retour avec historique poussé, annulation/confirmation d’abandon, petits viewports et clavier. Viewports : 320×568, 390×844, 768×1024. Les tests existants de permissions et des six modules sont conservés, sans modification d’assertions.

### Résultats finaux

| Commande / contrôle | Résultat | Journal |
|---|---|---|
| flutter pub get | Réussi, sans mise à niveau des dépendances | ../../work/step11-pub-get.log |
| dart format . | 322 fichiers, 0 modification au dernier contrôle | ../../work/step11-format-final.log |
| flutter analyze | No issues found!, 15,4 s | ../../work/step11-analysis-final.log |
| flutter test --reporter expanded | 404 réussis, 0 échec, 1 min 17 s | ../../work/step11-tests-passed.log |
| Tests navigation ciblés finaux | 17 réussis, 9 s, inclus dans les 404 et non additionnés | ../../work/step11-targeted-final.log |
| flutter build web | Réussi, Built build/web, 84,4 s | ../../work/step11-web-passed.log |
| Android SDK | Introuvable ; aucun APK compilé | ../../work/step11-doctor.log |

Les journaux intermédiaires comportent les régressions identifiées puis corrigées ; ils ne sont pas présentés comme des réussites. Les corrections concernent les gardes sur les routes de redirection, la sortie synchrone en l’absence de brouillon (importante pour les attentes FFI des tests), l’acquittement après sauvegarde et l’écoute ciblée de session pour ne pas fermer prématurément un éditeur poussé. Les racines des cinq branches sont explicites pour éviter une ouverture d’Adoptions à la place du catalogue. Les assertions des tests préexistants n’ont pas été modifiées pour masquer ces problèmes.

Le retour système est simulé par handlePopRoute dans les tests Flutter ; cela ne constitue pas un essai sur Android physique. Le retour navigateur et les gestes iOS restent à contrôler sur appareil. Les dialogues asynchrones Flutter ne protègent pas un rechargement complet ou une fermeture de fenêtre. La limitation Safari d’authentification n’a pas été traitée dans cette étape.

## Vérification manuelle Android / Web / iPhone

Sur un environnement Android déjà préparé par le collaborateur : flutter pub get, flutter analyze, flutter test, puis flutter run -d <identifiant-appareil>. Se connecter avec un compte de développement déjà préparé, parcourir les cinq onglets et chaque module, ouvrir un détail puis utiliser la flèche, le bouton système et un lien profond sans historique. Vérifier chaque profil et les restrictions pending/blocked.

Modifier un formulaire sans enregistrer, tenter un autre onglet puis Annuler ; contrôler que les champs restent présents. Confirmer Quitter dans un second essai. Tester ensuite l’enregistrement réussi et l’échec de validation. Vérifier le clavier, rotation, encoche et barre système, puis une fenêtre Web réduite et le retour navigateur. Après navigation vers un autre onglet, vérifier recherche et scroll au retour.

Sur iPhone, les écrans de connexion/inscription peuvent être contrôlés visuellement sans authentification réussie. La limitation Safari d’authentification préexistante reste hors périmètre. Les parcours connectés demandent une session fonctionnelle. Aucun appareil Android/iOS ni Safari réel n’a été exécuté dans cet environnement Windows ; les gestes natifs et le comportement du navigateur réel restent à vérifier. Aucun SDK n’a été installé.

Aucune autre étape n’a été engagée.
