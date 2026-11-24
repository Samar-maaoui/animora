# Animora — Étape 8B : extension de SQFlite

## État initial vérifié

L’étape 8A était opérationnelle : 291 tests réussis et analyse statique sans problème avant les modifications 8B. Le catalogue, les favoris, les adoptions, questionnaires, contrats, suivis et accueils utilisaient déjà SQLite sur Android/iOS. Les tests 8A de contraintes, transfert SharedPreferences, rollback, reprise et interface FFI ont été conservés. Une copie de l’état initial est conservée dans ../../work/step8b-before.

Les quatre autres modules utilisaient Sembast ; leurs modèles, algorithmes, écrans et interfaces de repository sont conservés. L’authentification reste distincte dans SharedPreferences.

## Architecture finale

Une seule base de production **animora.db**, un seul **DatabaseHelper**, schéma **v6**. SqliteRuntimeScope possède la connexion et la partage entre toutes les features ; aucune base SQLite propre à un module n’est créée. Les nouvelles classes SqliteReportsRepository, SqliteServicesRepository, SqliteDonationRepository et SqliteEventRepository réutilisent les règles de leurs repositories locaux, en remplaçant leur adaptateur par les tables relationnelles. Les transactions chargent des modèles de travail et écrivent uniquement les lignes modifiées ; aucun bloc JSON de module n’est stocké comme remplacement des tables.

Les modules sont initialisés dans l’ordre Signalements → Services → Dons → Événements, après le catalogue 8A. Chaque module conserve sa file d’opérations. La même transaction est réutilisée lors des lectures imbriquées du catalogue par les services ; elle ne tente pas d’ouvrir une seconde transaction SQLite.

Les profils métier User sont synchronisés depuis le stockage d’authentification avant les transactions, avec conservation des identifiants et des anciens profils référencés. Les clés étrangères refusent un identifiant absent. Les mots de passe, empreintes, sels et sessions ne sont pas copiés dans SQLite.

## Tables

**38 tables métier + database_metadata**, soit 39 tables. La table technique contient compteurs et marqueurs d’import.

| Module / migration | Tables |
| --- | --- |
| 8A — conservées | `users`, `animals`, `favorites`, `adoptions`, `adoption_questionnaires`, `adoption_contracts`, `adoption_followups`, `foster_placements` |
| Signalements — v3 | `reports`, `report_confirmations`, `announcements`, `testimonies`, `search_zones`, `matches`, `claims`, `reunion_stories` |
| Vétérinaire / pet-sitting — v4 | `veterinarian_availabilities`, `veterinary_appointments`, `vaccinations`, `animal_care`, `health_reminders`, `pet_sitter_settings`, `pet_sitting_requests`, `pet_sitting_updates`, `reviews` |
| Dons — v5 | `donation_campaigns`, `recurring_donations`, `material_needs`, `donations`, `material_donations`, `donation_receipts`, `transparency_reports` |
| Événements — v6 | `events`, `event_registrations`, `event_tickets`, `event_activities`, `volunteer_tasks`, `event_reports` |

pet_sitter_settings est nécessaire pour conserver la disponibilité et le tarif du modèle existant. WAITLISTED reste un statut de event_registrations, sans nouvelle table artificielle.

## Relations et contraintes

- Signalements : FK vers users ; confirmations uniques par signalement/utilisateur ; zones et histoires uniques par annonce ; paires de correspondances uniques et contrôlées LOST → FOUND ; réclamations actives et vérifiées protégées par indexes partiels. CHECK sur booléens, enums, urgence, scores et coordonnées.
- Services : FK utilisateurs/animaux, vaccinations/rappels et garde/suivis/avis ; index unique des rendez-vous occupant un créneau ; triggers contre chevauchements de disponibilités et gardes ACCEPTED/IN_PROGRESS ; avis unique, note 1–5, auteur propriétaire et garde COMPLETED. La confidentialité et les profils autorisés restent contrôlés par les règles existantes.
- Historique des rendez-vous : availabilityId garde l’identifiant historique. availabilityLinkId est une FK technique nullable ON DELETE SET NULL ; sa nullité est permise uniquement pour CANCELLED/REJECTED. Cela conserve les anciens rendez-vous dont le créneau a été supprimé légalement, sans inventer une disponibilité.
- Dons : FK campagne/donneur/programme/besoin/reçu ; montants monétaires de collecte stockés en **INTEGER millimes**, décodés dans les modèles existants ; contrôle de précision avant import ; quantités positives ; reçu unique par don et référence unique ; clés de requête et occurrence récurrente protégées. Triggers de recalcul du collecté et des quantités reçues, et contrôle du lien matériel/campagne/type. Paiements toujours simulés.
- Les champs collecté/quantité reçue/statut de besoin étaient calculés à la lecture dans l’ancien repository. L’import les recalcule à partir des dons confirmés et matériels reçus ; les valeurs métier sources restent intactes dans Sembast. Les rapports de transparence conservent leurs instantanés historiques.
- Événements : FK organisateur, inscription, billet, activité, tâche, bilan ; inscription active unique utilisateur/événement ; code et inscription du billet uniques ; capacité contrôlée par triggers, y compris réduction de capacité ; tâche assignée à un bénévole ; bilan unique par événement. Annulation et libération des places précèdent les promotions dans la même transaction.
- Les transitions, contrôles temporels, accès privés et règles de rôle restent dans les repositories métier. Les contraintes SQL les complètent ; elles ne constituent pas une authentification au niveau du moteur SQLite.

## Import Sembast et reprise

Pour chaque namespace reports, care_services, donations, events :

1. Lire la source une seule fois si le marqueur sembast_<namespace>_v1 est absent.
2. Refuser doublons d’identifiants, compteurs incohérents et formats invalides avant leur conversion en maps métier.
3. Copier les médias référencés vers les fichiers natifs ; vérifier un éventuel conflit sans écrasement.
4. Dans une transaction : synchroniser les profils, vérifier une destination vide sans marqueur, insérer parents puis enfants, contrôler tous les comptages et toutes les valeurs relues, foreign_key_check et integrity_check.
5. Écrire le marqueur en dernier, dans la même transaction.

Un échec annule lignes, compteurs et marqueur. Une nouvelle tentative reprend depuis la source conservée. Un marqueur valide empêche toute réimportation, même si l’ancienne source a changé. Une destination non vide sans marqueur est refusée pour éviter un écrasement ou une fusion risquée. Il n’y a aucune suppression automatique des anciennes bases Sembast.

Les migrations de schéma v3 à v6 sont additives. La mise à niveau d’une base v2 et la conservation de ses lignes sont testées.

## Médias

Sur Android/iOS, les nouveaux médias et les anciens médias copiés se trouvent dans le dossier privé de support de l’application : animora_media/<namespace>/<clé>.bin. Les tables stockent la référence media:<clé>, pas de BLOB. Les octets originaux sont conservés. Les photos de l’ancien catalogue 8A restent gérées par son adaptateur inchangé.

Une écriture de fichier précède le commit SQL : une erreur peut laisser un fichier non référencé. Il n’est pas supprimé automatiquement, afin de privilégier la conservation et la reprise ; aucun nettoyage destructif n’a été ajouté.

Le logo assets/images/animora_logo.png n’a pas été modifié. Empreinte SHA-256 vérifiée : B5F45FACFFCC664D7BAD0A1552040ADB48C485F78F789D2A494528860A7D4A86.

## Plateformes et limites

| Plateforme | Stockage |
| --- | --- |
| Android/iOS | Factory du package sqflite natif, même animora.db pour toutes les gestions |
| Web | Catalogue/adoptions SharedPreferences ; quatre autres gestions Sembast/IndexedDB ; authentification SharedPreferences |
| Desktop | Adaptateur précédent ; FFI est utilisé par les tests, pas activé comme nouvelle cible produit |

Les exports conditionnels excluent le stockage fichier natif du chemin Web. Le build Web est validé. Aucune migration native n’efface le stockage du navigateur. La persistance Web dépend toujours de la même origine et du même profil de navigateur.

SDK Android absent selon flutter doctor -v : compilation APK et exécution sur appareil non vérifiées. iOS non compilé depuis Windows. Les tests SQLite FFI exercent un vrai moteur SQLite et ses transactions, mais ne remplacent pas une validation du plugin sur appareil.

Les anciennes sources natives sont désormais des sauvegardes d’import, pas un miroir maintenu à jour. Un retour à une ancienne version de l’application après de nouvelles écritures SQL ne synchroniserait pas ces écritures vers Sembast.

Pas de backend, aucune nouvelle API externe, aucun paiement réel, aucune étape 9.

## Preuves et validation

Voir [VALIDATION_8B.md](VALIDATION_8B.md) pour les commandes et résultats exacts et [FILES_8B.md](FILES_8B.md) pour la liste des fichiers.

La base fictive [animora-8b-demo.db](output/database/animora-8b-demo.db), [son schéma](output/database/schema-8b.sql) et [la vérification indépendante](output/database/verification-8b.json) permettent d’examiner les 39 tables non vides. Il s’agit d’une fixture de tests, sans données réelles ni secrets d’authentification, et non de la base d’un appareil utilisateur.
